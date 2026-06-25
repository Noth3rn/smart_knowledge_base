import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart' hide ContextExtensionss;

import '../../core/database/app_database.dart';
import '../../routes/app_routes.dart';
import '../../shared/widgets/frosted_container.dart';
import '../../theme/app_theme.dart';
import 'note_list_controller.dart';

/// 笔记列表首页——Samsung Notes 风格。
///
/// 按日期分组（今天/昨天/本周/本月/更早），深色卡片，右下角 FAB 新建。
/// 顶部标题在列表滚离顶部时淡出，回到顶部时淡入。
class NoteListPage extends StatefulWidget {
  const NoteListPage({super.key});

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  late final NoteListController _controller;
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;
  static const double _kFadeThreshold = 40.0;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(NoteListController());
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
        child: Obx(() {
          if (_controller.isLoading) {
            return const Center(child: FCircularProgress());
          }

          return Stack(
            children: [
              if (_controller.notes.isEmpty)
                _buildEmptyState(theme)
              else
                _buildGroupedList(context, theme),
              Positioned(
                bottom: 24,
                right: 24,
                child: _buildFrostedFab(theme),
              ),
              _buildTopBar(theme),
            ],
          );
        }),
      ),
    );
  }

  // ── 顶部栏（标题 + 操作按钮，无大胶囊背景）──────────────────────────────

  Widget _buildTopBar(FThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 16, right: 12),
      child: Row(
        children: [
          AnimatedOpacity(
            opacity: _showTitle ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              '笔记',
              style: theme.typography.xl.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          // 胶囊形毛玻璃按钮组——与 editor 页右上角一致
          FrostedContainer(
            blurSigma: AppTheme.frost.blurSigma,
            backgroundColor: theme.colors.background.withValues(
              alpha: AppTheme.frost.barAlpha,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radius.full),
            border: Border.all(
              color: theme.colors.border.withValues(alpha: 0.35),
              width: AppTheme.frost.borderWidth,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => Get.toNamed(Routes.search),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Icon(
                      FLucideIcons.search,
                      size: 18,
                      color: theme.colors.foreground,
                    ),
                  ),
                ),
                Container(
                  width: 0.5,
                  height: 20,
                  color: theme.colors.border.withValues(alpha: 0.35),
                ),
                GestureDetector(
                  onTap: () => Get.toNamed(Routes.settings),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Icon(
                      FLucideIcons.settings,
                      size: 18,
                      color: theme.colors.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 空状态 ─────────────────────────────────────────────────────────────────

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
        ],
      ),
    );
  }

  // ── 分组列表 ───────────────────────────────────────────────────────────────

  Widget _buildGroupedList(BuildContext context, FThemeData theme) {
    final groups = _controller.noteGroups;

    final List<_ListItem> items = [];
    for (final group in groups) {
      items.add(_ListItem.header(group.title));
      for (final note in group.notes) {
        items.add(_ListItem.note(note));
      }
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 52, bottom: 88),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isHeader) {
          return _buildSectionHeader(item.title!, theme);
        }
        return _buildNoteCard(context, item.note!, theme);
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
    FThemeData theme,
  ) {
    final preview = _controller.notePreview(note);
    final timeStr = _formatNoteTime(note.updatedAt);

    return GestureDetector(
      onTap: () async {
        await Get.toNamed(
          Routes.noteDetail,
          parameters: {Routes.paramId: '${note.id}'},
        );
        _controller.loadNotes();
      },
      onLongPress: () => _showDeleteDialog(context, note),
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

            // 标签 badge 行
            Obx(() {
              final tags = _controller.tagsForNote(note.id);
              if (tags.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: tags
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colors.primary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius.full,
                              ),
                            ),
                            child: Text(
                              t,
                              style: theme.typography.xs3.copyWith(
                                color: theme.colors.primary,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────

  Widget _buildFrostedFab(FThemeData theme) {
    return GestureDetector(
      onTap: () async {
        await Get.toNamed(Routes.noteEditor);
        _controller.loadNotes();
      },
      child: FrostedContainer(
        width: 58,
        height: 58,
        blurSigma: 8.0,
        backgroundColor: theme.colors.primary.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        alignment: Alignment.center,
        child: Icon(
          FLucideIcons.plus,
          color: theme.colors.primaryForeground,
          size: 26,
        ),
      ),
    );
  }

  // ── 时间格式化 ─────────────────────────────────────────────────────────────

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

  // ── 删除对话框 ─────────────────────────────────────────────────────────────

  void _showDeleteDialog(BuildContext context, Note note) {
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
                _controller.deleteNote(note.id);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── 列表项类型 ───────────────────────────────────────────────────────────────

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
