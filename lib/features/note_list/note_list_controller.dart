import 'package:get/get.dart';

import '../../core/database/app_database.dart';

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

  Future<void> loadNotes() async {
    _isLoading.value = true;
    try {
      _notes.value = await _db.getAllNotes();
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> deleteNote(int id) async {
    await _db.deleteNote(id);
    _notes.removeWhere((n) => n.id == id);
    Get.snackbar('提示', '笔记已删除');
  }
}
