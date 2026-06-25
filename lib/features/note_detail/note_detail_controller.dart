import 'package:get/get.dart';

import '../../core/database/app_database.dart';
import '../note_list/note_list_controller.dart';

/// 笔记详情页控制器——加载笔记及其标签，支持删除操作。
class NoteDetailController extends GetxController {
  final _note = Rxn<Note>();
  final _tags = <Tag>[].obs;

  Note? get note => _note.value;
  List<Tag> get tags => _tags;

  AppDatabase get _db => Get.find<AppDatabase>();

  /// 根据 ID 加载笔记及其关联标签。
  Future<void> loadNote(int id) async {
    final note = await _db.getNoteById(id);
    _note.value = note;
    if (note != null) {
      _tags.value = await _db.getTagsByNoteId(note.id);
    }
  }

  /// 删除当前笔记，刷新列表页后返回。
  Future<void> deleteNote() async {
    final id = _note.value?.id;
    if (id == null) return;

    await _db.deleteNote(id);
    // 刷新列表页
    if (Get.isRegistered<NoteListController>()) {
      Get.find<NoteListController>().loadNotes();
    }
    Get.back();
  }
}
