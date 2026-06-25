import 'package:drift/drift.dart';

import 'notes_table.dart';

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get noteId => integer().references(Notes, #id)();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get source => text().withDefault(const Constant('manual'))();
}
