import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart' hide ContextExtensionss;

import '../../core/enum/embedding_backend.dart';
import '../../shared/widgets/frosted_container.dart';
import '../../theme/app_theme.dart';
import 'settings_controller.dart';

/// 设置页。
///
/// 管理 LLM API 配置、嵌入后端选择、自动标签开关。
/// 顶部标题在滚离顶部时淡出。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsController _controller;
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;
  static const double _kFadeThreshold = 40.0;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(SettingsController());
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final shouldShow = _scrollController.hasClients &&
        _scrollController.offset < _kFadeThreshold;
    if (shouldShow != _showTitle) {
      setState(() => _showTitle = shouldShow);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return FScaffold(
      child: SafeArea(
        child: Stack(
          children: [
            Obx(() {
              if (_controller.isLoading) {
                return const Center(child: FCircularProgress());
              }

              return SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 52),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(theme, 'LLM API'),
                    _buildApiKeyField(),
                    _buildBaseUrlField(),
                    _buildModelNameField(),
                    const FDivider(),
                    _buildSectionHeader(theme, '嵌入方案'),
                    _buildEmbeddingSelector(theme),
                    const FDivider(),
                    _buildSectionHeader(theme, '标签'),
                    _buildAutoTagSwitch(theme),
                    const FDivider(),
                    _buildSectionHeader(theme, '关于'),
                    _buildAboutTile(theme),
                    SizedBox(height: AppTheme.spacing.xxl),
                  ],
                ),
              );
            }),
            _buildTopBar(theme),
          ],
        ),
      ),
    );
  }

  // ── 顶部栏（返回按钮 + 标题淡入淡出）─────────────────────────────────────

  Widget _buildTopBar(FThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 12, right: 16),
      child: Row(
        children: [
          _buildFrostedCircleBtn(
            theme: theme,
            onTap: () => Get.back(),
            child: Icon(
              FLucideIcons.chevronLeft,
              size: 18,
              color: theme.colors.foreground,
            ),
          ),
          const SizedBox(width: 10),
          AnimatedOpacity(
            opacity: _showTitle ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              '设置',
              style: theme.typography.md.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 毛玻璃圆形按钮 ─────────────────────────────────────────────────────────

  Widget _buildFrostedCircleBtn({
    required FThemeData theme,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: FrostedContainer(
        width: 40,
        height: 40,
        blurSigma: AppTheme.frost.blurSigma,
        backgroundColor: theme.colors.background.withValues(
          alpha: AppTheme.frost.btnAlpha,
        ),
        border: Border.all(
          color: theme.colors.border.withValues(alpha: 0.35),
          width: AppTheme.frost.borderWidth,
        ),
        shape: BoxShape.circle,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  // ── 内容构建方法 ───────────────────────────────────────────────────────────

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

  Widget _buildApiKeyField() {
    return Padding(
      padding: AppTheme.edgeInsets.fieldPadding,
      child: FTextField(
        control: .managed(
          controller: _controller.apiKeyController,
          onChange: (v) => _controller.saveApiKey(v.text),
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

  Widget _buildBaseUrlField() {
    return Padding(
      padding: AppTheme.edgeInsets.fieldPadding,
      child: FTextField(
        control: .managed(
          controller: _controller.baseUrlController,
          onChange: (v) => _controller.saveBaseUrl(v.text),
        ),
        label: const Text('API Base URL'),
        hint: 'https://api.deepseek.com/v1',
        keyboardType: TextInputType.url,
        size: .md,
      ),
    );
  }

  Widget _buildModelNameField() {
    return Padding(
      padding: AppTheme.edgeInsets.fieldPadding,
      child: FTextField(
        control: .managed(
          controller: _controller.modelNameController,
          onChange: (v) => _controller.saveModelName(v.text),
        ),
        label: const Text('模型名称'),
        hint: 'deepseek-chat',
        size: .md,
      ),
    );
  }

  Widget _buildEmbeddingSelector(FThemeData theme) {
    final backends = EmbeddingBackend.values;
    final currentBackend = _backendFromString(_controller.embeddingBackend);
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
              _controller.changeEmbeddingBackend(backends[index].value);
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

  Widget _buildAutoTagSwitch(FThemeData theme) {
    return Padding(
      padding: AppTheme.edgeInsets.fieldPadding,
      child: Obx(
        () => FSwitch(
          label: const Text('保存时自动生成标签'),
          description: const Text('调用 LLM API 分析笔记内容并生成标签'),
          value: _controller.autoTag,
          onChange: _controller.toggleAutoTag,
        ),
      ),
    );
  }

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

  EmbeddingBackend _backendFromString(String backend) {
    return switch (backend) {
      'litert' => EmbeddingBackend.litert,
      'api' => EmbeddingBackend.api,
      _ => EmbeddingBackend.auto,
    };
  }
}
