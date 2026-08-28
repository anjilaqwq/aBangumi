import 'package:shared_preferences/shared_preferences.dart';

/// 搜索历史本地存储：去重、最多 [maxItems] 条、支持清空与单条删除。
class SearchHistoryStore {
  static const String _key = 'bgm_search_history';

  /// 历史上限条数。
  static const int maxItems = 10;

  /// 读取全部历史（新 → 旧）。
  Future<List<String>> load() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getStringList(_key) ?? const [];
  }

  /// 记录一次搜索：去重后置顶，超出上限则裁剪。返回更新后的列表。
  Future<List<String>> add(String keyword) async {
    final kw = keyword.trim();
    final sp = await SharedPreferences.getInstance();
    final list = List<String>.from(sp.getStringList(_key) ?? const <String>[]);
    if (kw.isEmpty) return List.unmodifiable(list);
    list.remove(kw);
    list.insert(0, kw);
    if (list.length > maxItems) {
      list.removeRange(maxItems, list.length);
    }
    await sp.setStringList(_key, list);
    return List.unmodifiable(list);
  }

  /// 删除单条历史。返回更新后的列表。
  Future<List<String>> remove(String keyword) async {
    final sp = await SharedPreferences.getInstance();
    final list = List<String>.from(sp.getStringList(_key) ?? const <String>[]);
    list.remove(keyword);
    await sp.setStringList(_key, list);
    return List.unmodifiable(list);
  }

  /// 清空全部历史。
  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
  }
}
