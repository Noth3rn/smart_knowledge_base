import 'package:get/get.dart';

import '../features/note_list/note_list_page.dart';
import '../features/note_editor/note_editor_page.dart';
import '../features/note_detail/note_detail_page.dart';
import '../features/search/search_page.dart';
import '../features/settings/settings_page.dart';

abstract class Routes {
  static const noteList = '/';
  static const noteEditor = '/editor';
  static const noteDetail = '/detail';
  static const search = '/search';
  static const settings = '/settings';
}

final appPages = [
  GetPage(name: Routes.noteList, page: () => const NoteListPage()),
  GetPage(name: Routes.noteEditor, page: () => const NoteEditorPage()),
  GetPage(name: Routes.noteDetail, page: () => const NoteDetailPage()),
  GetPage(name: Routes.search, page: () => const SearchPage()),
  GetPage(name: Routes.settings, page: () => const SettingsPage()),
];
