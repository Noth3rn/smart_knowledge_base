import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart' hide ContextExtensionss;

import '../../core/database/app_database.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import 'note_list_controller.dart';

/// 笔记列表首页——Samsung Notes 风格。
///
/// 按日期分组（今天/昨天/本周/本月/更早），深色卡片，右下角 FAB 新建。
class NoteListPage extends StatelessWidget {
  const NoteListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NoteListController());
    final theme = context.theme;

    return FScaffold(
      header: FHeader(
        title: Text(
          '笔记',
          style: theme.typography.xl.copyWith(fontWeight: FontWeight.w700),
        ),
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.search),
            onPress: () => Get.toNamed(Routes.search),
          ),
          FHeaderAction(
            icon: const Icon(FLucideIcons.settings),
            onPress: () => Get.toNamed(Routes.settings),
          ),
        ],
      ),
      child: Obx(() {
        if (controller.isLoading) {
          return const Center(child: FCircularProgress());
        }

        // FAB 始终浮在最上层，无论是否有笔记
        return Stack(
          children: [
            if (controller.notes.isEmpty)
              _buildEmptyState(theme)
            else
              _buildGroupedList(context, controller, theme),
            Positioned(
              bottom: 24,
              right: 24,
              child: _buildFab(context, controller, theme),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildEmptyState(FThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FLucideIcons.notebookPen,
            size: 56,
            color: theme.colors.mutedForeground,
          ),
          SizedBox(height: AppTheme.spacing.lg),
          Text(
            '还没有笔记',
            style: theme.typography.lg.copyWith(
              color: theme.colors.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppTheme.spacing.sm),
          Text(
            '点击右下角按钮创建第一条笔记',
            style: theme.typography.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          // 空状态也需要 FAB，所以这个会由外层 Stack 提供
        ],
      ),
    );
  }

  Widget _buildGroupedList(
    BuildContext context,
    NoteListController controller,
    FThemeData theme,
  ) {
    final groups = controller.noteGroups;

    // 展开为扁平 item 列表：section header + note cards
    final List<_ListItem> items = [];
    for (final group in groups) {
      items.add(_ListItem.header(group.title));
      for (final note in group.notes) {
        items.add(_ListItem.note(note));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 88),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isHeader) {
          return _buildSectionHeader(item.title!, theme);
        }
        return _buildNoteCard(context, item.note!, controller, theme);
      },
    );
  }

  Widget _buildSectionHeader(String title, FThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        title,
        style: theme.typography.sm.copyWith(
          color: theme.colors.mutedForeground,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildNoteCard(
    BuildContext context,
    Note note,
    NoteListController controller,
    FThemeData theme,
  ) {
    final preview = controller.notePreview(note);
    final timeStr = _formatNoteTime(note.updatedAt);

    return GestureDetector(
      onTap: () async {
        await Get.toNamed(
          Routes.noteDetail,
          parameters: {Routes.paramId: '${note.id}'},
        );
        controller.loadNotes();
      },
      onLongPress: () => _showDeleteDialog(context, controller, note),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colors.secondary,
          borderRadius: BorderRadius.circular(AppTheme.radius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              timeStr,
              style: theme.typography.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              note.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.md.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (preview != '无内容') ...[
              const SizedBox(height: 4),
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFab(
    BuildContext context,
    NoteListController controller,
    FThemeData theme,
  ) {
    return GestureDetector(
      onTap: () async {
        await Get.toNamed(Routes.noteEditor);
        controller.loadNotes();
      },
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: theme.colors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.colors.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          FLucideIcons.plus,
          color: theme.colors.primaryForeground,
          size: 26,
        ),
      ),
    );
  }

  /// 格式化笔记时间：今天显示时分，否则显示月日。
  String _formatNoteTime(DateTime dt) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final noteDay = DateTime(dt.year, dt.month, dt.day);

    if (!noteDay.isBefore(todayStart)) {
      final period = dt.hour >= 12 ? '下午' : '上午';
      final h = dt.hour > 12
          ? dt.hour - 12
          : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      return '$period $h:$m';
    }
    return '${dt.month}月${dt.day}日';
  }

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
          body: Text('确定要删除「${note.title}」吗？此操作不可撤销。'),
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

/// 列表项类型（section header 或 note card）。
class _ListItem {
  final bool isHeader;
  final String? title;
  final Note? note;

  const _ListItem.header(this.title)
      : isHeader = true,
        note = null;

  const _ListItem.note(this.note)
      : isHeader = false,
        title = null;
}
