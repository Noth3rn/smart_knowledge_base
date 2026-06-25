import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart' hide ContextExtensionss;

import '../../core/database/app_database.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import 'note_list_controller.dart';

/// 笔记列表首页。
///
/// 展示所有笔记，支持点击查看、长按删除、跳转搜索/设置/新建。
class NoteListPage extends StatelessWidget {
  const NoteListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NoteListController());
    final theme = context.theme;

    return FScaffold(
      header: FHeader(
        title: const Text('SmartKnowledgeBase'),
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.search),
            onPress: () => Get.toNamed(Routes.search),
          ),
          FHeaderAction(
            icon: const Icon(FLucideIcons.settings),
            onPress: () => Get.toNamed(Routes.settings),
          ),
          FHeaderAction(
            icon: const Icon(FLucideIcons.plus),
            onPress: () async {
              await Get.toNamed(Routes.noteEditor);
              controller.loadNotes();
            },
          ),
        ],
      ),
      child: Obx(() {
        if (controller.isLoading) {
          return const Center(child: FCircularProgress());
        }

        if (controller.notes.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FLucideIcons.filePlus,
                  size: 64,
                  color: theme.colors.mutedForeground,
                ),
                SizedBox(height: AppTheme.spacing.lg),
                Text(
                  '还没有笔记，点击右上角 + 创建',
                  style: theme.typography.lg.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          );
        }

        return FTileGroup.builder(
          count: controller.notes.length,
          tileBuilder: (context, index) {
            final note = controller.notes[index];
            return FTile(
              title: Text(
                note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                controller.notePreview(note),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
              suffix: Text(
                '${note.updatedAt.month}/${note.updatedAt.day}',
                style: theme.typography.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
              onPress: () async {
                await Get.toNamed(
                  Routes.noteDetail,
                  parameters: {Routes.paramId: '${note.id}'},
                );
                controller.loadNotes();
              },
              onLongPress: () => _showDeleteDialog(context, controller, note),
            );
          },
        );
      }),
    );
  }

  /// 显示删除确认对话框。
  void _showDeleteDialog(
    BuildContext context,
    NoteListController controller,
    Note note,
  ) {
    showFDialog(
      context: context,
      builder: (context, style, animation) => FTheme(
        data: context.theme,
        child: FDialog(
          style: style,
          animation: animation,
          title: const Text('删除笔记'),
          body: Text('确定要删除「${note.title}」吗？'),
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
                controller.deleteNote(note.id);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
