import 'package:get/get.dart';

import '../../core/database/app_database.dart';
import '../../theme/app_theme.dart';

/// 笔记列表页控制器。
class NoteListController extends GetxController {
  final _notes = <Note>[].obs;
  final _isLoading = false.obs;

  List<Note> get notes => _notes;
  bool get isLoading => _isLoading.value;

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
