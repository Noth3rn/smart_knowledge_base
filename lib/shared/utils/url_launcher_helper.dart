import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:url_launcher/url_launcher.dart';

/// 弹出确认对话框后跳转外部链接。
///
/// 显示"正在跳转到 {url}"的确认弹窗，用户确认后调用 [launchUrl] 打开浏览器。
Future<void> openUrlWithConfirm(BuildContext context, String url) async {
  final theme = context.theme;

  final confirmed = await showFDialog<bool>(
    context: context,
    builder: (ctx, style, animation) => FTheme(
      data: theme,
      child: FDialog(
        style: style,
        animation: animation,
        title: const Text('打开外部链接'),
        body: Text(
          '正在跳转到\n$url',
          style: theme.typography.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
        actions: [
          FButton(
            variant: .outline,
            size: .sm,
            child: const Text('取消'),
            onPress: () => Navigator.of(ctx).pop(false),
          ),
          FButton(
            variant: .primary,
            size: .sm,
            child: const Text('确定'),
            onPress: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    ),
  );

  if (confirmed == true) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
