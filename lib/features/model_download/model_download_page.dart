import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart' hide ContextExtensionss;

import '../../theme/app_theme.dart';
import 'model_download_controller.dart';

/// 模型下载页面——首次运行时引导用户下载设备端嵌入模型。
///
/// 用户需要提供模型文件 (.tflite) 和分词器 (.model) 的下载 URL。
/// 可从 HuggingFace、Google Edge AI 等模型托管平台获取。
class ModelDownloadPage extends StatelessWidget {
  const ModelDownloadPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ModelDownloadController());

    return PopScope(
      canPop: !controller.isDownloading,
      child: FScaffold(
        header: FHeader(
          title: const Text('下载嵌入模型'),
          suffixes: [
            if (!controller.isDownloading)
              FHeaderAction.x(onPress: () => Navigator.of(context).pop()),
          ],
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Obx(() => _buildBody(context, controller)),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ModelDownloadController controller,
  ) {
    return switch (controller.status) {
      DownloadStatus.idle => _buildIdle(context, controller),
      DownloadStatus.downloadingModel ||
      DownloadStatus.downloadingTokenizer =>
        _buildDownloading(context, controller),
      DownloadStatus.completed => _buildCompleted(context, controller),
      DownloadStatus.failed => _buildFailed(context, controller),
    };
  }

  /// 初始状态：说明 + URL 输入框 + 下载/跳过按钮。
  Widget _buildIdle(BuildContext context, ModelDownloadController controller) {
    final theme = context.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 图标和说明
        Icon(
          FLucideIcons.download,
          size: 64,
          color: theme.colors.primary,
        ),
        SizedBox(height: AppTheme.spacing.xl),
        Text(
          '设备端语义搜索',
          style: theme.typography.xl2.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppTheme.spacing.md),
        Text(
          '需要下载嵌入模型（.tflite）和分词器（.model）两个文件。\n'
          '请从 HuggingFace 等平台获取文件 URL 后填入下方。',
          textAlign: TextAlign.center,
          style: theme.typography.md.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
        SizedBox(height: AppTheme.spacing.sm),
        Text(
          '可随时跳过，之后在设置页面重新下载。',
          textAlign: TextAlign.center,
          style: theme.typography.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),

        SizedBox(height: AppTheme.spacing.lg),

        // 模型 URL 输入
        FTextField(
          control: .managed(controller: controller.modelUrlController),
          label: const Text('模型文件 URL (.tflite)'),
          hint: 'https://huggingface.co/.../embedding_model.tflite',
          keyboardType: TextInputType.url,
          enabled: !controller.isDownloading,
          size: .md,
        ),

        SizedBox(height: AppTheme.spacing.lg),

        // 分词器 URL 输入
        FTextField(
          control: .managed(controller: controller.tokenizerUrlController),
          label: const Text('分词器 URL (.model / .json)'),
          hint: 'https://huggingface.co/.../tokenizer.model',
          keyboardType: TextInputType.url,
          enabled: !controller.isDownloading,
          size: .md,
        ),

        SizedBox(height: AppTheme.spacing.lg),

        // HuggingFace Token 输入
        FTextField(
          control: .managed(controller: controller.hfTokenController),
          label: const Text('HuggingFace Token（可选，gated 模型需要）'),
          hint: 'hf_xxxxxxxxxxxx',
          description:
              const Text('在 huggingface.co/settings/tokens 创建'),
          obscureText: true,
          enabled: !controller.isDownloading,
          size: .md,
        ),

        SizedBox(height: AppTheme.spacing.xl),

        // 操作按钮
        FButton(
          onPress: controller.canStartDownload
              ? () => controller.startDownload()
              : null,
          prefix: const Icon(FLucideIcons.download),
          size: .lg,
          child: const Text('下载模型'),
        ),
        SizedBox(height: AppTheme.spacing.md),
        FButton(
          variant: .ghost,
          size: .lg,
          child: const Text('跳过'),
          onPress: () => _handleSkip(controller),
        ),
      ],
    );
  }

  /// 下载中：进度条 + 状态文字 + 取消按钮。
  Widget _buildDownloading(
    BuildContext context,
    ModelDownloadController controller,
  ) {
    final theme = context.theme;
    final overallProgress =
        (controller.modelProgress + controller.tokenizerProgress) / 200.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          FLucideIcons.cloudDownload,
          size: 72,
          color: theme.colors.primary,
        ),
        SizedBox(height: AppTheme.spacing.xl),
        Text(
          controller.statusMessage,
          textAlign: TextAlign.center,
          style: theme.typography.lg.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: AppTheme.spacing.xxl),
        FDeterminateProgress(
          value: overallProgress.isNaN ? 0 : overallProgress,
        ),
        SizedBox(height: AppTheme.spacing.md),
        Text(
          '${(overallProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
          style: theme.typography.lg,
        ),
        SizedBox(height: AppTheme.spacing.sm),
        Text(
          '模型: ${controller.modelProgress}%  |  分词器: ${controller.tokenizerProgress}%',
          style: theme.typography.sm,
        ),
        SizedBox(height: AppTheme.spacing.xxl),
        FButton(
          variant: .outline,
          prefix: const Icon(FLucideIcons.circleX),
          child: const Text('取消下载'),
          onPress: () => controller.cancel(),
        ),
      ],
    );
  }

  /// 下载完成。
  Widget _buildCompleted(
    BuildContext context,
    ModelDownloadController controller,
  ) {
    final theme = context.theme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          FLucideIcons.circleCheck,
          size: 72,
          color: theme.colors.primary,
        ),
        SizedBox(height: AppTheme.spacing.xl),
        Text(
          '下载完成！',
          style: theme.typography.xl2.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppTheme.spacing.lg),
        Text(
          controller.statusMessage,
          textAlign: TextAlign.center,
          style: theme.typography.lg,
        ),
        SizedBox(height: AppTheme.spacing.xxl),
        FButton(
          prefix: const Icon(FLucideIcons.arrowRight),
          size: .lg,
          onPress: () async {
            await controller.continueWithModel();
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('继续'),
        ),
      ],
    );
  }

  /// 下载失败：错误详情 + 重试/跳过。
  Widget _buildFailed(
    BuildContext context,
    ModelDownloadController controller,
  ) {
    final theme = context.theme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          FLucideIcons.alertTriangle,
          size: 72,
          color: theme.colors.destructive,
        ),
        SizedBox(height: AppTheme.spacing.xl),
        Text(
          '下载失败',
          style: theme.typography.xl2.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppTheme.spacing.lg),
        Container(
          width: double.infinity,
          padding: AppTheme.edgeInsets.allMd,
          decoration: BoxDecoration(
            color: theme.colors.destructive.withAlpha(30),
            borderRadius: BorderRadius.circular(AppTheme.radius.md),
          ),
          child: Text(
            controller.statusMessage,
            style: theme.typography.sm.copyWith(
              color: theme.colors.destructive,
            ),
          ),
        ),
        SizedBox(height: AppTheme.spacing.xxl),
        FButton(
          prefix: const Icon(FLucideIcons.refreshCw),
          size: .lg,
          onPress: () => controller.retry(),
          child: const Text('重试'),
        ),
        SizedBox(height: AppTheme.spacing.md),
        FButton(
          variant: .ghost,
          size: .lg,
          child: const Text('跳过'),
          onPress: () => _handleSkip(controller),
        ),
      ],
    );
  }

  Future<void> _handleSkip(ModelDownloadController controller) async {
    await controller.skip();
    if (Get.context != null) {
      Navigator.of(Get.context!).pop();
    }
  }
}
