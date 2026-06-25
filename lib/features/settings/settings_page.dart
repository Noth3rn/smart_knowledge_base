import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart' hide ContextExtensionss;

import '../../core/enum/embedding_backend.dart';
import '../../theme/app_theme.dart';
import 'settings_controller.dart';

/// 设置页。
///
/// 管理 LLM API 配置、嵌入后端选择、自动标签开关。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());
    final theme = context.theme;

    return FScaffold(
      header: FHeader.nested(
        title: const Text('设置'),
        prefixes: [
          FHeaderAction.back(onPress: () => Get.back()),
        ],
      ),
      child: Obx(() {
        if (controller.isLoading) {
          return const Center(child: FCircularProgress());
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(theme, 'LLM API'),
              _buildApiKeyField(controller),
              _buildBaseUrlField(controller),
              _buildModelNameField(controller),
              const FDivider(),
              _buildSectionHeader(theme, '嵌入方案'),
              _buildEmbeddingSelector(controller, theme),
              const FDivider(),
              _buildSectionHeader(theme, '标签'),
              _buildAutoTagSwitch(controller, theme),
              const FDivider(),
              _buildSectionHeader(theme, '关于'),
              _buildAboutTile(theme),
              SizedBox(height: AppTheme.spacing.xxl),
            ],
          ),
        );
      }),
    );
  }

  /// 区块标题。
  Widget _buildSectionHeader(FThemeData theme, String title) {
    return Padding(
      padding: AppTheme.edgeInsets.sectionHeader,
      child: Text(
        title,
        style: theme.typography.md.copyWith(
          color: theme.colors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// API Key 输入框。
  Widget _buildApiKeyField(SettingsController controller) {
    return Padding(
      padding: AppTheme.edgeInsets.fieldPadding,
      child: FTextField(
        control: .managed(
          controller: controller.apiKeyController,
          onChange: (v) => controller.saveApiKey(v.text),
        ),
        label: const Text('API Key'),
        hint: 'sk-xxxxxxxxxxxx',
        description: const Text('用于 LLM 自动打标签和 API 嵌入降级'),
        obscureText: true,
        keyboardType: TextInputType.visiblePassword,
        size: .md,
      ),
    );
  }

  /// API Base URL 输入框。
  Widget _buildBaseUrlField(SettingsController controller) {
    return Padding(
      padding: AppTheme.edgeInsets.fieldPadding,
      child: FTextField(
        control: .managed(
          controller: controller.baseUrlController,
          onChange: (v) => controller.saveBaseUrl(v.text),
        ),
        label: const Text('API Base URL'),
        hint: 'https://api.deepseek.com/v1',
        keyboardType: TextInputType.url,
        size: .md,
      ),
    );
  }

  /// 模型名称输入框。
  Widget _buildModelNameField(SettingsController controller) {
    return Padding(
      padding: AppTheme.edgeInsets.fieldPadding,
      child: FTextField(
        control: .managed(
          controller: controller.modelNameController,
          onChange: (v) => controller.saveModelName(v.text),
        ),
        label: const Text('模型名称'),
        hint: 'deepseek-chat',
        size: .md,
      ),
    );
  }

  /// 嵌入后端选择器（使用 FTabs 替代 SegmentedButton）。
  Widget _buildEmbeddingSelector(
    SettingsController controller,
    FThemeData theme,
  ) {
    final backends = EmbeddingBackend.values;
    final currentBackend = _backendFromString(controller.embeddingBackend);
    final initialIndex = backends.indexOf(currentBackend);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FTabs(
            control: .managed(initial: initialIndex.clamp(0, backends.length - 1)),
            children: backends
                .map((b) => FTabEntry(
                      label: Text(b.displayName),
                      child: const SizedBox.shrink(),
                    ))
                .toList(),
            onPress: (index) {
              controller.changeEmbeddingBackend(backends[index].value);
            },
          ),
          SizedBox(height: AppTheme.spacing.sm),
          Text(
            currentBackend.description,
            style: theme.typography.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  /// 自动标签开关。
  Widget _buildAutoTagSwitch(
    SettingsController controller,
    FThemeData theme,
  ) {
    return Padding(
      padding: AppTheme.edgeInsets.fieldPadding,
      child: Obx(
        () => FSwitch(
          label: const Text('保存时自动生成标签'),
          description: const Text('调用 LLM API 分析笔记内容并生成标签'),
          value: controller.autoTag,
          onChange: controller.toggleAutoTag,
        ),
      ),
    );
  }

  /// 关于信息。
  Widget _buildAboutTile(FThemeData theme) {
    return Padding(
      padding: AppTheme.edgeInsets.card,
      child: Row(
        children: [
          const Icon(FLucideIcons.info),
          SizedBox(width: AppTheme.spacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SmartKnowledgeBase'),
              Text(
                'v1.0.0 — 个人知识管理工具',
                style: theme.typography.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 字符串后端名 → 枚举。
  EmbeddingBackend _backendFromString(String backend) {
    return switch (backend) {
      'litert' => EmbeddingBackend.litert,
      'api' => EmbeddingBackend.api,
      _ => EmbeddingBackend.auto,
    };
  }
}
