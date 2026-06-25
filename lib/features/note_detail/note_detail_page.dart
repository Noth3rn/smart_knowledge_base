import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart' hide ContextExtensionss;

import '../../routes/app_routes.dart';
import '../../shared/utils/export_helper.dart';
import '../../theme/app_theme.dart';
import 'note_detail_controller.dart';

/// 笔记详情页——Samsung Notes 风格。
///
/// 正文顶部展示大标题，底部固定工具栏提供编辑/分享/删除操作。
class NoteDetailPage extends StatelessWidget {
  const NoteDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NoteDetailController());
    final id = Get.parameters[Routes.paramId];

    if (id != null && controller.note == null) {
      controller.loadNote(int.parse(id));
    }

    return FScaffold(
      header: FHeader.nested(
        title: Obx(
          () => Text(
            controller.note?.title ?? '笔记详情',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        prefixes: [FHeaderAction.back(onPress: () => Get.back())],
      ),
      child: Obx(() {
        final note = controller.note;
        if (note == null) {
          return const Center(child: FCircularProgress());
        }

        final theme = context.theme;

        return Column(
          children: [
            // 正文可滚动区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 大标题
                    Text(
                      note.title,
                      style: theme.typography.xl2.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),

                    // 时间戳
                    const SizedBox(height: 8),
                    Text(
                      '${_formatDateTime(note.updatedAt)} 编辑',
                      style: theme.typography.xs.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),

                    // 标签
                    if (controller.tags.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: AppTheme.spacing.sm,
                        runSpacing: AppTheme.spacing.xs,
                        children: controller.tags
                            .map(
                              (t) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colors.secondary,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius.full,
                                  ),
                                ),
                                child: Text(
                                  t.name,
                                  style: theme.typography.xs.copyWith(
                                    color: theme.colors.secondaryForeground,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],

                    // 分隔线
                    const SizedBox(height: 20),
                    Container(
                      height: 0.5,
                      color: theme.colors.border,
                    ),
                    const SizedBox(height: 16),

                    // Markdown 正文（非滚动版本，嵌入 SingleChildScrollView）
                    if (note.content.isNotEmpty)
                      MarkdownBody(
                        data: note.content,
                        styleSheet: _buildMarkdownStyle(theme),
                      )
                    else
                      Text(
                        '暂无内容',
                        style: theme.typography.md.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // 底部工具栏
            _BottomToolbar(controller: controller, context: context),
          ],
        );
      }),
    );
  }

  String _formatDateTime(DateTime dt) {
    final y = dt.year;
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$y/$mo/$d $h:$mi';
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
        border: Border(
          left: BorderSide(color: theme.colors.border, width: 3),
        ),
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
}

/// 底部工具栏（编辑 / 分享 / 删除）。
class _BottomToolbar extends StatelessWidget {
  final NoteDetailController controller;
  final BuildContext context;

  const _BottomToolbar({
    required this.controller,
    required this.context,
  });

  @override
  Widget build(BuildContext outerContext) {
    final theme = outerContext.theme;

    return Container(
      decoration: BoxDecoration(
        color: theme.colors.background,
        border: Border(
          top: BorderSide(color: theme.colors.border, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ToolbarAction(
            icon: FLucideIcons.pencil,
            label: '编辑',
            onTap: () async {
              final noteId = controller.note?.id;
              if (noteId != null) {
                await Get.toNamed(
                  Routes.noteEditor,
                  parameters: {Routes.paramId: '$noteId'},
                );
                controller.loadNote(noteId);
              }
            },
            theme: theme,
          ),
          _ToolbarAction(
            icon: FLucideIcons.share2,
            label: '分享',
            onTap: () {
              final note = controller.note;
              if (note != null) {
                ExportHelper.exportNote(note.title, note.content);
              }
            },
            theme: theme,
          ),
          _ToolbarAction(
            icon: FLucideIcons.trash2,
            label: '删除',
            onTap: () => _showDeleteDialog(outerContext, controller),
            isDestructive: true,
            theme: theme,
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    NoteDetailController controller,
  ) {
    showFDialog(
      context: context,
      builder: (context, style, animation) => FTheme(
        data: context.theme,
        child: FDialog(
          style: style,
          animation: animation,
          title: const Text('删除笔记'),
          body: Text('确定要删除「${controller.note?.title}」吗？此操作不可撤销。'),
          actions: [
            FButton(
              variant: .outline,
              size: .sm,
              child: const Text('取消'),
              onPress: () => Navigator.of(context).pop(),
            ),
            FButton(
              variant: .destructive,
              size: .sm,
              child: const Text('删除'),
              onPress: () {
                controller.deleteNote();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部工具栏单个操作按钮。
class _ToolbarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final FThemeData theme;

  const _ToolbarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.theme,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isDestructive ? theme.colors.destructive : theme.colors.foreground;
    final labelColor =
        isDestructive ? theme.colors.destructive : theme.colors.mutedForeground;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.typography.xs.copyWith(color: labelColor),
            ),
          ],
        ),
      ),
    );
  }
}
