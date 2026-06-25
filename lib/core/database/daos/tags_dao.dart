part of '../app_database.dart';

extension TagsDao on AppDatabase {
  /// 获取某条笔记的所有标签
  Future<List<Tag>> getTagsByNoteId(int noteId) {
    return (select(tags)..where((t) => t.noteId.equals(noteId))).get();
  }

  /// 添加标签
  Future<int> addTag(TagsCompanion entry) {
    return into(tags).insert(entry);
  }

  /// 删除标签
  Future<int> removeTag(int tagId) {
    return (delete(tags)..where((t) => t.id.equals(tagId))).go();
  }

  /// 删除某条笔记的所有标签
  Future<int> removeTagsByNoteId(int noteId) {
    return (delete(tags)..where((t) => t.noteId.equals(noteId))).go();
  }

  /// 批量添加标签
  Future<void> addTags(int noteId, List<String> tagNames,
      {String source = 'manual'}) async {
    for (final name in tagNames) {
      await addTag(TagsCompanion(
        noteId: Value(noteId),
        name: Value(name.trim()),
        source: Value(source),
      ));
    }
  }
}
