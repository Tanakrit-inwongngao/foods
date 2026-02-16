import 'dart:collection';

/// Simple in-memory history store for the app session.
///
/// If you want history to persist after closing the app,
/// tell me and I'll switch this to SharedPreferences or local storage.
class HistoryStore {
  HistoryStore._();

  static final List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  /// Returns an unmodifiable view of the history (newest first).
  static UnmodifiableListView<Map<String, dynamic>> get items =>
      UnmodifiableListView(_items.reversed);

  static void add(Map<String, dynamic> item) {
    _items.add(item);
  }

  static void clear() {
    _items.clear();
  }
}
