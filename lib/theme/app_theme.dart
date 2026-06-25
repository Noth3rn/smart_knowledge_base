import 'package:flutter/widgets.dart';

/// AppTheme 门面类，聚合所有主题常量。
///
/// 颜色通过 ForUI 的 [FColors] 体系管理（通过 `context.theme.colors` 访问），
/// 此处仅管理项目专属的间距、圆角、边距等常量。
class AppTheme {
  const AppTheme._();

  static const spacing = AppSpacing();
  static const radius = AppRadius();
  static const edgeInsets = AppEdgeInsets();
  static const constants = AppConstants();
  static const frost = AppFrost();
}

/// 统一间距常量。
class AppSpacing {
  const AppSpacing();

  double get xs => 4;
  double get sm => 8;
  double get md => 12;
  double get lg => 16;
  double get xl => 24;
  double get xxl => 32;
}

/// 统一圆角常量。
class AppRadius {
  const AppRadius();

  double get sm => 6;
  double get md => 10;
  double get lg => 14;
  double get full => 9999;
}

/// 预设 EdgeInsets 常量。
class AppEdgeInsets {
  const AppEdgeInsets();

  EdgeInsets get allXs => const EdgeInsets.all(4);
  EdgeInsets get allSm => const EdgeInsets.all(8);
  EdgeInsets get allMd => const EdgeInsets.all(12);
  EdgeInsets get allLg => const EdgeInsets.all(16);
  EdgeInsets get allXl => const EdgeInsets.all(24);

  EdgeInsets get pageH => const EdgeInsets.symmetric(horizontal: 16);
  EdgeInsets get card => const EdgeInsets.all(12);

  EdgeInsets get sectionHeader =>
      const EdgeInsets.fromLTRB(16, 20, 16, 8);
  EdgeInsets get fieldPadding =>
      const EdgeInsets.symmetric(horizontal: 16, vertical: 4);
  EdgeInsets get editorPadding =>
      const EdgeInsets.fromLTRB(16, 12, 16, 0);
  EdgeInsets get editorTagPadding =>
      const EdgeInsets.fromLTRB(16, 8, 16, 0);
}

/// 通用 UI 常量。
class AppConstants {
  const AppConstants();

  /// 语义搜索相似度阈值。
  double get similarityThreshold => 0.2;

  /// 语义搜索返回结果上限。
  int get topK => 20;

  /// 笔记列表内容预览最大字符数。
  int get summaryMaxChars => 100;

  /// 搜索输入防抖延迟（毫秒）。
  int get debounceMs => 300;
}

/// 毛玻璃浮动胶囊样式常量。
class AppFrost {
  const AppFrost();

  /// BackdropFilter 背景模糊半径。
  double get blurSigma => 10.0;

  /// 浮动导航条半透明背景 alpha（较透明）。
  double get barAlpha => 0.55;

  /// 独立圆形按钮半透明背景 alpha（略不透明）。
  double get btnAlpha => 0.60;

  /// 毛玻璃边框宽度。
  double get borderWidth => 0.5;

  /// 浮动条距屏幕左右边距。
  double get barHorizontalMargin => 12.0;

  /// 浮动顶栏距 SafeArea 顶部偏移。
  double get barTopMargin => 8.0;

  /// 浮动底栏距屏幕底部偏移。
  double get barBottomMargin => 16.0;
}
