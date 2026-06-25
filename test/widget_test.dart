import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:drift/native.dart';

import 'package:smart_knowledge_base/app.dart';
import 'package:smart_knowledge_base/core/database/app_database.dart';

void main() {
  setUp(() {
    // 使用内存数据库进行测试，避免文件系统依赖
    Get.put<AppDatabase>(
      AppDatabase.forTesting(NativeDatabase.memory()),
      permanent: true,
    );
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('App renders note list page with ForUI theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    // 验证首页显示应用标题
    expect(find.text('SmartKnowledgeBase'), findsOneWidget);
    // 验证空状态提示存在
    expect(find.text('还没有笔记，点击右上角 + 创建'), findsOneWidget);
  });
}
