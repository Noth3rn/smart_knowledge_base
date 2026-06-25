import 'package:get/get.dart' hide Value;
import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

class NoteEditorController extends GetxController {
  final titleController = ''.obs;
  final contentController = ''.obs;
  final _isSaving = false.obs;
  final _noteId = Rxn<int>();
  final _tags = <String>[].obs;
  final newTagText = ''.obs;
  final _isPreview = false.obs;

  bool get isSaving => _isSaving.value;
  int? get noteId => _noteId.value;
  bool get isEditing => _noteId.value != null;
  List<String> get tags => _tags;
  bool get isPreview => _isPreview.value;

  AppDatabase get _db => Get.find<AppDatabase>();

  /// 切换编辑/预览模式
  void togglePreview() => _isPreview.toggle();

  /// 如果是编辑模式，加载已有笔记及其标签
  Future<void> loadNote(int id) async {
    _noteId.value = id;
    final note = await _db.getNoteById(id);
    if (note != null) {
      titleController.value = note.title;
      contentController.value = note.content;
      final existingTags = await _db.getTagsByNoteId(id);
      _tags.value = existingTags.map((t) => t.name).toList();
    }
  }

  /// 添加标签
  void addTag(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _tags.contains(trimmed)) return;
    if (_tags.length >= 10) {
      Get.snackbar('提示', '最多添加 10 个标签');
      return;
    }
    _tags.add(trimmed);
    newTagText.value = '';
  }

  /// 移除标签
  void removeTag(String name) {
    _tags.remove(name);
  }

  /// 保存笔记（新建或更新）
  Future<void> save() async {
    final title = titleController.value.trim();
    final content = contentController.value.trim();

    if (title.isEmpty) {
      Get.snackbar('错误', '标题不能为空');
      return;
    }

    _isSaving.value = true;
    try {
      final entry = NotesCompanion(
        title: Value(title),
        content: Value(content),
        updatedAt: Value(DateTime.now()),
      );

      int noteId;
      if (_noteId.value != null) {
        await _db.updateNote(_noteId.value!, entry);
        noteId = _noteId.value!;
        // 更新标签：先删后加
        await _db.removeTagsByNoteId(noteId);
      } else {
        noteId = await _db.insertNote(entry);
      }

      // 保存手动标签
      if (_tags.isNotEmpty) {
        await _db.addTags(noteId, _tags, source: 'manual');
      }

      Get.back(result: true);
    } finally {
      _isSaving.value = false;
    }
  }
}
