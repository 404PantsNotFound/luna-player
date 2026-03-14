import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

class SearchHistoryService extends ChangeNotifier {
  static const int _maxHistory = 5;

  final List<String> _history = [];

  List<String> get history => List.unmodifiable(_history);

  Future<void> init() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'search_history',
        orderBy: 'searchedAt DESC',
        limit: _maxHistory,
      );
      _history.clear();
      _history.addAll(rows.map((r) => r['query'] as String));
      notifyListeners();
      debugPrint('[SearchHistory] Loaded ${_history.length} items');
    } catch (e) {
      debugPrint('[SearchHistory] Failed to load: $e');
    }
  }

  Future<void> addSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    try {
      final db = await DatabaseHelper.instance.database;

      await db.insert(
        'search_history',
        {
          'query': trimmed,
          'searchedAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Keep only latest 5
      await db.execute('''
        DELETE FROM search_history
        WHERE query NOT IN (
          SELECT query FROM search_history
          ORDER BY searchedAt DESC
          LIMIT $_maxHistory
        )
      ''');

      // Update in-memory list
      _history.remove(trimmed);
      _history.insert(0, trimmed);
      if (_history.length > _maxHistory) {
        _history.removeLast();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[SearchHistory] Failed to save: $e');
    }
  }

  Future<void> removeSearch(String query) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'search_history',
        where: 'query = ?',
        whereArgs: [query],
      );
      _history.remove(query);
      notifyListeners();
    } catch (e) {
      debugPrint('[SearchHistory] Failed to remove: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('search_history');
      _history.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('[SearchHistory] Failed to clear: $e');
    }
  }

  // Filter history that matches current input
  List<String> suggestions(String input) {
    if (input.trim().isEmpty) return _history;
    return _history
        .where((q) => q.toLowerCase().contains(input.toLowerCase()))
        .toList();
  }
}