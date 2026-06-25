import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'app.dart';
import 'core/database/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  // Phase 1 — 初始化数据库
  Get.put(AppDatabase());

  // TODO: Phase 3 — 嵌入方案决策
  // await _initServices();
  // TODO: Phase 5 — LLM 标签服务
  // Get.lazyPut(() => TagGenerationService());

  runApp(const App());
}
