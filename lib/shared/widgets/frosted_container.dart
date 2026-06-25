import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';

/// 毛玻璃浮动容器——半透明背景 + 背景模糊 + 圆角 + 细边框 + 微阴影。
///
/// 用于浮动工具栏、胶囊按钮、顶部/底部导航栏等"浮动胶囊"风格的 UI 元素。
/// 封装了 [BackdropFilter] + [ClipRRect] 的标准组合，避免各页面重复实现。
///
/// ```dart
/// FrostedContainer(
///   borderRadius: BorderRadius.circular(AppTheme.radius.full),
///   backgroundColor: theme.colors.background.withValues(alpha: 0.55),
///   border: Border.all(color: theme.colors.border.withValues(alpha: 0.35)),
///   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
///   child: Row(...),
/// )
/// ```
class FrostedContainer extends StatelessWidget {
  const FrostedContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.blurSigma = 10.0,
    this.backgroundColor,
    this.borderRadius,
    this.border,
    this.padding,
    this.shape = BoxShape.rectangle,
    this.alignment,
  });

  /// 容器内容。
  final Widget child;

  /// 固定宽度（可选）。
  final double? width;

  /// 固定高度（可选）。
  final double? height;

  /// 背景模糊强度，默认 10.0。
  final double blurSigma;

  /// 半透明背景色。通常传入 `theme.colors.background.withValues(alpha: 0.55)`。
  final Color? backgroundColor;

  /// 圆角。圆形按钮时无需设置（配合 [shape] = [BoxShape.circle]）。
  final BorderRadius? borderRadius;

  /// 边框，通常使用 0.5px 主题边框色。
  final BoxBorder? border;

  /// 内容内边距。
  final EdgeInsetsGeometry? padding;

  /// 形状：圆形用于 FAB/图标按钮，矩形+圆角用于胶囊条。
  final BoxShape shape;

  /// 内容对齐方式。
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius =
        shape == BoxShape.circle
            ? BorderRadius.circular(AppTheme.radius.full)
            : borderRadius;

    return ClipRRect(
      borderRadius: effectiveRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          height: height,
          alignment: alignment,
          padding: padding,
          decoration: BoxDecoration(
            shape: shape,
            borderRadius: shape == BoxShape.circle ? null : effectiveRadius,
            color: backgroundColor,
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}
