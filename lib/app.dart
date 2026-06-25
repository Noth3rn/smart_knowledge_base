import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';

import 'routes/app_routes.dart';

/// 应用根组件。
///
/// 使用 [GetMaterialApp] 提供 GetX 路由/导航支持，
/// 内部通过 ForUI [FTheme] 提供统一的 UI 风格。
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FThemes.neutral.dark.touch;

    return GetMaterialApp(
      title: 'SmartKnowledgeBase',
      theme: theme.toApproximateMaterialTheme(),
      localizationsDelegates: FLocalizations.localizationsDelegates,
      supportedLocales: FLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      builder: (_, child) => FTheme(
        data: theme,
        child: FToaster(child: FTooltipGroup(child: child!)),
      ),
      initialRoute: Routes.noteList,
      getPages: appPages,
    );
  }
}
