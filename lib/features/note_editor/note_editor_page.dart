import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show InputBorder; // FTextField border delta 需要
import 'package:forui/forui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart' hide ContextExtensionss;

import '../../shared/utils/url_launcher_helper.dart';
import '../../shared/widgets/frosted_container.dart';
import '../../theme/app_theme.dart';
import 'note_editor_controller.dart';

/// 笔记编辑页——文档风格，无传统 AppBar。
///
/// 标题/正文字段无边框无背景，与预览模式视觉一致。
/// StatefulWidget 持有 TextEditingController，避免 Obx rebuild 重置光标。
class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final NoteEditorController _controller;
  late final TextEditingController _titleTec;
  late final TextEditingController _contentTec;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(NoteEditorController());
    _titleTec = TextEditingController(text: _controller.titleController.value);
    _contentTec = TextEditingController(text: _controller.contentController.value);

    final id = Get.parameters['id'];
    if (id != null && _controller.noteId == null) {
      _controller.loadNote(int.parse(id)).then((_) {
        if (!mounted) return;
        _titleTec.text = _controller.titleController.value;
        _contentTec.text = _controller.contentController.value;
      });
    }
  }

  @override
  void dispose() {
    _titleTec.dispose();
    _contentTec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return FScaffold(
      child: SafeArea(
        child: Stack(
          children: [
            Obx(
              () =>
                  _controller.isPreview ? _buildPreview(context, theme) : _buildEditContent(context, theme),
            ),
            _buildTopBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(FThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleBtn(
            theme: theme,
            onTap: () => Get.back(),
            child: Icon(FLucideIcons.chevronLeft, size: 18, color: theme.colors.foreground),
          ),
          _buildCapsuleGroup(theme),
        ],
      ),
    );
  }

  /// 圆形毛玻璃按钮（背景模糊 + 半透明 + 细边框）。
  Widget _buildCircleBtn({required FThemeData theme, required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      child: FrostedContainer(
        width: 40,
        height: 40,
        blurSigma: AppTheme.frost.blurSigma,
        backgroundColor: theme.colors.background.withValues(alpha: AppTheme.frost.btnAlpha),
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

  /// 胶囊形毛玻璃按钮组（预览切换 + 保存，背景模糊 + 半透明）。
  Widget _buildCapsuleGroup(FThemeData theme) {
    return FrostedContainer(
      blurSigma: AppTheme.frost.blurSigma,
      backgroundColor: theme.colors.background.withValues(alpha: AppTheme.frost.barAlpha),
      borderRadius: BorderRadius.circular(AppTheme.radius.full),
      border: Border.all(
        color: theme.colors.border.withValues(alpha: 0.35),
        width: AppTheme.frost.borderWidth,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(
            () => GestureDetector(
              onTap: () => _controller.togglePreview(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Icon(
                  _controller.isPreview ? FLucideIcons.pencil : FLucideIcons.eye,
                  size: 18,
                  color: theme.colors.foreground,
                ),
              ),
            ),
          ),


          Container(width: 0.5, height: 20, color: theme.colors.border.withValues(alpha: 0.35)),

          Obx(() {
            if (_controller.isSaving) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: SizedBox(width: 18, height: 18, child: FCircularProgress(size: .sm)),
              );
            }
            return GestureDetector(
              onTap: () => _controller.save(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Icon(FLucideIcons.check, size: 18, color: theme.colors.foreground),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 生成无边框无背景的 FTextField 样式 delta。
  ///
  /// [textStyle] 覆盖输入内容字体，[hintStyle] 覆盖提示字体。
  FTextFieldStyleDelta bareStyle(
    FThemeData theme, {
    required TextStyle textStyle,
    required TextStyle hintStyle,
  }) => .delta(
    // 去掉背景填充色
    color: FVariantsValueDelta.delta([FVariantValueDeltaOperation.all(null)]),
    // 去掉所有状态下的边框
    border: FVariantsValueDelta.delta([FVariantValueDeltaOperation.all(InputBorder.none)]),
    // 去掉内边距，让文字与周围内容对齐
    contentPadding: const EdgeInsetsGeometryDelta.value(EdgeInsets.zero),
    // 去掉最小高度限制
    constraints: const BoxConstraints(),
    // 覆盖输入文字样式
    contentTextStyle:
        FVariants<FTextFieldVariantConstraint, FTextFieldVariant, TextStyle, TextStyleDelta>.all(textStyle),
    // 覆盖 hint 文字样式
    hintTextStyle: FVariants<FTextFieldVariantConstraint, FTextFieldVariant, TextStyle, TextStyleDelta>.all(
      hintStyle,
    ),
  );

  Widget _buildEditContent(BuildContext context, FThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 40),
      children: [
        // 大标题输入——与预览 xl3 bold 一致
        FTextField(
          control: .managed(
            controller: _titleTec,
            onChange: (v) => _controller.titleController.value = v.text,
          ),
          style: bareStyle(
            theme,
            textStyle: theme.typography.xl3.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.4,
              color: theme.colors.foreground,
            ),
            hintStyle: theme.typography.xl3.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.4,
              color: theme.colors.mutedForeground,
            ),
          ),
          hint: '标题',
          size: .lg,
          maxLines: null,
        ),

        const SizedBox(height: 12),


        _buildTagsRow(context, theme),

        const SizedBox(height: 8),
        const FDivider(),
        const SizedBox(height: 12),

        // 正文输入——与预览 md 正文一致
        FTextField(
          control: .managed(
            controller: _contentTec,
            onChange: (v) => _controller.contentController.value = v.text,
          ),
          style: bareStyle(
            theme,
            textStyle: theme.typography.md.copyWith(height: 1.75, color: theme.colors.foreground),
            hintStyle: theme.typography.md.copyWith(height: 1.75, color: theme.colors.mutedForeground),
          ),
          hint: '开始写作...',
          maxLines: null,
          size: .md,
        ),
      ],
    );
  }

  Widget _buildTagsRow(BuildContext context, FThemeData theme) {
    return Obx(() {
      return Wrap(
        spacing: AppTheme.spacing.sm,
        runSpacing: AppTheme.spacing.sm,
        children: [
          ..._controller.tags.map(
            (tag) => GestureDetector(
              onTap: () => _controller.removeTag(tag),
              child: FBadge(
                variant: .outline,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tag),
                    const SizedBox(width: 4),
                    Icon(FLucideIcons.x, size: 12, color: theme.colors.mutedForeground),
                  ],
                ),
              ),
            ),
          ),

          // AI 标签按钮——始终可见，生成中显示 loading
          GestureDetector(
            onTap: _controller.isGeneratingTags ? null : () => _controller.generateTags(),
            child: FBadge(
              variant: .outline,
              child: _controller.isGeneratingTags
                  ? const SizedBox(width: 12, height: 12, child: FCircularProgress(size: .sm))
                  : const Icon(FLucideIcons.sparkles, size: 12).paddingSymmetric(vertical: 3),
            ),
          ),


          GestureDetector(
            onTap: () => _showAddTagDialog(context),
            child: FBadge(
              variant: .outline,
              child: const Icon(FLucideIcons.plus, size: 12).paddingSymmetric(vertical: 3),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildPreview(BuildContext context, FThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(
            () => Text(
              _controller.titleController.value.isEmpty ? '无标题' : _controller.titleController.value,
              style: theme.typography.xl3.copyWith(fontWeight: FontWeight.bold, height: 1.4),
            ),
          ),

          const SizedBox(height: 12),

          Obx(() {
            final tags = _controller.tags;
            if (tags.isEmpty) return const SizedBox.shrink();
            return Wrap(
              spacing: AppTheme.spacing.sm,
              runSpacing: AppTheme.spacing.xs,
              children: tags.map((t) => FBadge(variant: .outline, child: Text(t))).toList(),
            );
          }),

          const SizedBox(height: 8),
          const FDivider(),
          const SizedBox(height: 12),

          Obx(() {
            final content = _controller.contentController.value;
            if (content.isEmpty) {
              return Text('暂无内容', style: theme.typography.md.copyWith(color: theme.colors.mutedForeground));
            }
            return MarkdownBody(
              data: content,
              styleSheet: _buildMarkdownStyle(theme),
              onTapLink: (text, href, title) {
                if (href != null) {
                  openUrlWithConfirm(context, href);
                }
              },
            );
          }),
        ],
      ),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyle(FThemeData theme) {
    final base = theme.typography.md;
    final muted = base.copyWith(color: theme.colors.mutedForeground);

    return MarkdownStyleSheet(
      p: base,
      h1: theme.typography.xl2.copyWith(fontWeight: FontWeight.w700),
      h2: theme.typography.xl.copyWith(fontWeight: FontWeight.w700),
      h3: theme.typography.lg.copyWith(fontWeight: FontWeight.w600),
      h4: theme.typography.md.copyWith(fontWeight: FontWeight.w600),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.colors.border, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12),
      code: theme.typography.sm.copyWith(
        fontFamily: 'monospace',
        color: theme.colors.foreground,
        backgroundColor: theme.colors.secondary,
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colors.secondary,
        borderRadius: BorderRadius.circular(AppTheme.radius.md),
      ),
      listBullet: muted,
    );
  }

  void _showAddTagDialog(BuildContext context) {
    String newTag = '';
    showFDialog(
      context: context,
      builder: (ctx, style, animation) => FTheme(
        data: ctx.theme,
        child: FDialog(
          style: style,
          animation: animation,
          title: const Text('添加标签'),
          body: FTextField(
            control: .managed(initial: TextEditingValue.empty, onChange: (v) => newTag = v.text),
            hint: '输入标签名',
            autofocus: true,
            onSubmit: (v) {
              _controller.addTag(v);
              Navigator.of(ctx).pop();
            },
          ),
          actions: [
            FButton(
              variant: .outline,
              size: .sm,
              child: const Text('取消'),
              onPress: () => Navigator.of(ctx).pop(),
            ),
            FButton(
              variant: .primary,
              size: .sm,
              child: const Text('添加'),
              onPress: () {
                _controller.addTag(newTag);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
