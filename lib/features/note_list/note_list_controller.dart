import 'package:get/get.dart';

import '../../core/database/app_database.dart';
import '../../theme/app_theme.dart';

typedef NoteGroup = ({String title, List<Note> notes});

/// 笔记列表页控制器。
class NoteListController extends GetxController {
  final _notes = <Note>[].obs;
  final _isLoading = false.obs;

  static const List<String> _kGroupOrder = ['今天', '昨天', '本周', '本月', '更早'];

  List<Note> get notes => _notes;
  bool get isLoading => _isLoading.value;

  /// 将笔记按更新时间分组（今天/昨天/本周/本月/更早）。
  List<NoteGroup> get noteGroups {
    if (_notes.isEmpty) return const [];

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final rawGroups = <String, List<Note>>{};

    for (final note in _notes) {
      final noteDay = DateTime(
        note.updatedAt.year,
        note.updatedAt.month,
        note.updatedAt.day,
      );

      final String group;
      if (!noteDay.isBefore(todayStart)) {
        group = '今天';
      } else if (!noteDay.isBefore(yesterdayStart)) {
        group = '昨天';
      } else if (!noteDay.isBefore(weekStart)) {
        group = '本周';
      } else if (!noteDay.isBefore(monthStart)) {
        group = '本月';
      } else {
        group = '更早';
      }

      rawGroups.putIfAbsent(group, () => []).add(note);
    }

    return _kGroupOrder
        .where((g) => rawGroups.containsKey(g))
        .map((g) => (title: g, notes: rawGroups[g]!))
        .toList();
  }

  AppDatabase get _db => Get.find<AppDatabase>();

  @override
  void onInit() {
    super.onInit();
    loadNotes();
  }

  /// 加载所有笔记。
  Future<void> loadNotes() async {
    _isLoading.value = true;
    try {
      _notes.value = await _db.getAllNotes();
    } finally {
      _isLoading.value = false;
    }
  }

  /// 删除笔记并刷新列表。
  Future<void> deleteNote(int id) async {
    await _db.deleteNote(id);
    _notes.removeWhere((n) => n.id == id);
    Get.snackbar('提示', '笔记已删除');
  }

  /// 生成笔记内容的预览文字。
  ///
  /// 替换换行为空格，超出 [AppConstants.summaryMaxChars] 则截断并追加省略号。
  String notePreview(Note note) {
    if (note.content.isEmpty) {
      return '无内容';
    }
    final singleLine = note.content.replaceAll('\n', ' ');
    if (singleLine.length <= AppTheme.constants.summaryMaxChars) {
      return singleLine;
    }
    return '${singleLine.substring(0, AppTheme.constants.summaryMaxChars)}...';
  }
}
