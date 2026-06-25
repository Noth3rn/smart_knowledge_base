import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart' hide ContextExtensionss;

import '../../routes/app_routes.dart';
import '../../shared/utils/export_helper.dart';
import '../../theme/app_theme.dart';
import 'note_detail_controller.dart';

/// 笔记详情页。
///
/// 展示 Markdown 渲染的笔记内容、标签列表、时间信息，
/// 支持导出、编辑、删除操作。
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
        title: Obx(() => Text(controller.note?.title ?? '笔记详情')),
        prefixes: [
          FHeaderAction.back(onPress: () => Get.back()),
        ],
        suffixes: [
          Obx(() {
            final note = controller.note;
            if (note == null) {
              return const SizedBox.shrink();
            }
            return FHeaderAction(
              icon: const Icon(FLucideIcons.share),
              onPress: () =>
                  ExportHelper.exportNote(note.title, note.content),
            );
          }),
          FHeaderAction(
            icon: const Icon(FLucideIcons.pencil),
            onPress: () async {
              final noteId = controller.note?.id;
              if (noteId != null) {
                await Get.toNamed(
                  Routes.noteEditor,
                  parameters: {Routes.paramId: '$noteId'},
                );
                controller.loadNote(noteId);
              }
            },
          ),
          FHeaderAction(
            icon: const Icon(FLucideIcons.trash),
            onPress: () => _showDeleteDialog(context, controller),
          ),
        ],
      ),
      child: Obx(() {
        final note = controller.note;
        if (note == null) {
          return const Center(child: FCircularProgress());
        }

        final tags = controller.tags;
        final theme = context.theme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标签区
            if (tags.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Wrap(
                  spacing: AppTheme.spacing.sm,
                  runSpacing: AppTheme.spacing.xs,
                  children: tags
                      .map((t) => Container(
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
                          ))
                      .toList(),
                ),
              ),
              const FDivider(),
            ],

            // 笔记内容（Markdown 渲染）
            if (note.content.isNotEmpty)
              Expanded(
                child: Markdown(
                  data: note.content,
                  padding: const EdgeInsets.all(16),
                ),
              )
            else
              const Expanded(
                child: Center(child: Text('无内容')),
              ),

            // 时间信息
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '创建于 ${_formatDateTime(note.createdAt)}\n'
                '更新于 ${_formatDateTime(note.updatedAt)}',
                style: theme.typography.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  /// 格式化日期时间为简短字符串。
  String _formatDateTime(DateTime dt) => dt.toString().substring(0, 16);

  /// 显示删除确认对话框。
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
          body: Text('确定要删除「${controller.note?.title}」吗？'),
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
