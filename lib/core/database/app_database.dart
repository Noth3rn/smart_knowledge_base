import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/notes_table.dart';
import 'tables/tags_table.dart';

part 'app_database.g.dart';
part 'daos/notes_dao.dart';
part 'daos/tags_dao.dart';

@DriftDatabase(tables: [Notes, Tags])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 测试用构造函数，接受外部 QueryExecutor
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'smart_knowledge_base.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
