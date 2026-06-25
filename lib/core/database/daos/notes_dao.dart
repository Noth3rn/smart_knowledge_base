part of '../app_database.dart';

extension NotesDao on AppDatabase {
  /// 获取所有笔记，按更新时间倒序排列
  Future<List<Note>> getAllNotes() {
    return (select(notes)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// 根据 ID 获取单条笔记
  Future<Note?> getNoteById(int id) {
    return (select(notes)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 插入新笔记，返回自增 ID
  Future<int> insertNote(NotesCompanion entry) {
    return into(notes).insert(entry);
  }

  /// 更新笔记，返回受影响行数
  Future<int> updateNote(int id, NotesCompanion entry) {
    return (update(notes)..where((t) => t.id.equals(id))).write(entry);
  }

  /// 删除笔记（同时删除关联的标签）
  Future<int> deleteNote(int id) async {
    await (delete(tags)..where((t) => t.noteId.equals(id))).go();
    return (delete(notes)..where((t) => t.id.equals(id))).go();
  }

  /// 全文搜索（关键词降级方案）
  Future<List<Note>> searchByKeyword(String keyword) {
    final query = '%$keyword%';
    return (select(notes)
          ..where((t) => t.title.like(query) | t.content.like(query))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }
}
