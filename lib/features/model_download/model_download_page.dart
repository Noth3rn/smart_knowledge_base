import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'model_download_controller.dart';

/// 模型下载页面——首次运行时引导用户下载设备端嵌入模型。
///
/// 用户需要提供模型文件 (.tflite) 和分词器 (.model/.json) 的下载 URL。
/// 可从 HuggingFace、Google Edge AI 等模型托管平台获取。
class ModelDownloadPage extends StatelessWidget {
  const ModelDownloadPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ModelDownloadController());

    return PopScope(
      canPop: !controller.isDownloading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('下载嵌入模型'),
          centerTitle: true,
          automaticallyImplyLeading: !controller.isDownloading,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Obx(() => _buildBody(context, controller)),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ModelDownloadController controller) {
    switch (controller.status) {
      case DownloadStatus.idle:
        return _buildIdle(context, controller);
      case DownloadStatus.downloadingModel:
      case DownloadStatus.downloadingTokenizer:
        return _buildDownloading(context, controller);
      case DownloadStatus.completed:
        return _buildCompleted(context, controller);
      case DownloadStatus.failed:
        return _buildFailed(context, controller);
    }
  }

  /// 初始状态：说明 + URL 输入框 + 下载/跳过按钮。
  Widget _buildIdle(BuildContext context, ModelDownloadController controller) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 图标和说明
        Icon(
          Icons.download_for_offline_outlined,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          '设备端语义搜索',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          '需要下载嵌入模型（.tflite）和分词器（.model）两个文件。\n'
          '请从 HuggingFace 等平台获取文件 URL 后填入下方。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '可随时跳过，之后在设置页面重新下载。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 28),

        // 模型 URL 输入
        TextField(
          controller: controller.modelUrlController,
          decoration: InputDecoration(
            labelText: '模型文件 URL (.tflite)',
            hintText: 'https://huggingface.co/.../embedding_model.tflite',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.link),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => controller.modelUrlController.clear(),
            ),
          ),
          keyboardType: TextInputType.url,
          enabled: !controller.isDownloading,
          onChanged: (_) {
            // 触发 Obx 更新按钮状态
          },
        ),

        const SizedBox(height: 16),

        // 分词器 URL 输入
        TextField(
          controller: controller.tokenizerUrlController,
          decoration: InputDecoration(
            labelText: '分词器 URL (.model / .json)',
            hintText: 'https://huggingface.co/.../tokenizer.model',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.link),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => controller.tokenizerUrlController.clear(),
            ),
          ),
          keyboardType: TextInputType.url,
          enabled: !controller.isDownloading,
          onChanged: (_) {},
        ),

        const SizedBox(height: 16),

        // HuggingFace Token 输入
        TextField(
          controller: controller.hfTokenController,
          decoration: InputDecoration(
            labelText: 'HuggingFace Token（可选，gated 模型需要）',
            hintText: 'hf_xxxxxxxxxxxx',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.key),
            helperText: '在 huggingface.co/settings/tokens 创建',
            helperMaxLines: 1,
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => controller.hfTokenController.clear(),
            ),
          ),
          obscureText: true,
          enabled: !controller.isDownloading,
          onChanged: (_) {},
        ),

        const SizedBox(height: 32),

        // 操作按钮
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: controller.canStartDownload
                ? () => controller.startDownload()
                : null,
            icon: const Icon(Icons.download),
            label: const Text('下载模型'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: TextButton(
            onPressed: () => _handleSkip(controller),
            child: const Text('跳过'),
          ),
        ),
      ],
    );
  }

  /// 下载中：进度条 + 状态文字 + 取消按钮。
  Widget _buildDownloading(
      BuildContext context, ModelDownloadController controller) {
    final overallProgress =
        (controller.modelProgress + controller.tokenizerProgress) / 200.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_download_outlined,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          controller.statusMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 32),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: overallProgress.isNaN ? null : overallProgress,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${(overallProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(
          '模型: ${controller.modelProgress}%  |  分词器: ${controller.tokenizerProgress}%',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 48),
        OutlinedButton.icon(
          onPressed: () => controller.cancel(),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('取消下载'),
        ),
      ],
    );
  }

  /// 下载完成。
  Widget _buildCompleted(
      BuildContext context, ModelDownloadController controller) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          '下载完成！',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          controller.statusMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 48),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: () async {
              await controller.continueWithModel();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.arrow_forward),
            label: const Text('继续'),
          ),
        ),
      ],
    );
  }

  /// 下载失败：错误详情 + 重试/跳过。
  Widget _buildFailed(BuildContext context, ModelDownloadController controller) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          size: 72,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 24),
        Text(
          '下载失败',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withAlpha(80),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            controller.statusMessage,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: () => controller.retry(),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: TextButton(
            onPressed: () => _handleSkip(controller),
            child: const Text('跳过'),
          ),
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
