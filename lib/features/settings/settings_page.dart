import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'settings_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Obx(() {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          children: [
            _buildSectionHeader(context, 'LLM API'),
            _buildApiKeyField(controller, theme),
            _buildBaseUrlField(controller, theme),
            _buildModelNameField(controller, theme),
            const Divider(),
            _buildSectionHeader(context, '嵌入方案'),
            _buildEmbeddingSelector(controller, theme),
            const Divider(),
            _buildSectionHeader(context, '标签'),
            _buildAutoTagSwitch(controller, theme),
            const Divider(),
            _buildSectionHeader(context, '关于'),
            _buildAboutTile(theme),
            const SizedBox(height: 32),
          ],
        );
      }),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildApiKeyField(SettingsController controller, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller.apiKeyController,
        obscureText: true,
        decoration: InputDecoration(
          labelText: 'API Key',
          hintText: 'sk-xxxxxxxxxxxx',
          border: const OutlineInputBorder(),
          helperText: '用于 LLM 自动打标签和 API 嵌入降级',
          helperMaxLines: 1,
          prefixIcon: const Icon(Icons.key),
        ),
        onChanged: controller.saveApiKey,
      ),
    );
  }

  Widget _buildBaseUrlField(SettingsController controller, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller.baseUrlController,
        decoration: const InputDecoration(
          labelText: 'API Base URL',
          hintText: 'https://api.deepseek.com/v1',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.link),
        ),
        keyboardType: TextInputType.url,
        onChanged: controller.saveBaseUrl,
      ),
    );
  }

  Widget _buildModelNameField(SettingsController controller, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller.modelNameController,
        decoration: const InputDecoration(
          labelText: '模型名称',
          hintText: 'deepseek-chat',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.model_training),
        ),
        onChanged: controller.saveModelName,
      ),
    );
  }

  Widget _buildEmbeddingSelector(
      SettingsController controller, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'auto', label: Text('自动')),
              ButtonSegment(value: 'litert', label: Text('LiteRT')),
              ButtonSegment(value: 'api', label: Text('API')),
            ],
            selected: {controller.embeddingBackend},
            onSelectionChanged: (selected) {
              controller.changeEmbeddingBackend(selected.first);
            },
          ),
          const SizedBox(height: 8),
          Text(
            _backendDescription(controller.embeddingBackend),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _backendDescription(String backend) {
    return switch (backend) {
      'auto' => '优先使用设备端模型，不可用时降级到 API',
      'litert' => '仅使用设备端模型，完全离线运行',
      'api' => '仅使用远程 API，需要配置 API Key',
      _ => '',
    };
  }

  Widget _buildAutoTagSwitch(
      SettingsController controller, ThemeData theme) {
    return SwitchListTile(
      title: const Text('保存时自动生成标签'),
      subtitle: const Text('调用 LLM API 分析笔记内容并生成标签'),
      value: controller.autoTag,
      onChanged: controller.toggleAutoTag,
    );
  }

  Widget _buildAboutTile(ThemeData theme) {
    return const ListTile(
      title: Text('SmartKnowledgeBase'),
      subtitle: Text('v1.0.0 — 个人知识管理工具'),
      leading: Icon(Icons.info_outline),
    );
  }
}
