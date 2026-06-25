import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart' hide ContextExtensionss;

import '../../routes/app_routes.dart';
import '../../shared/utils/export_helper.dart';
import '../../shared/utils/url_launcher_helper.dart';
import '../../shared/widgets/frosted_container.dart';
import '../../theme/app_theme.dart';
import 'note_detail_controller.dart';

/// 笔记详情页。
///
/// 正文顶部展示大标题，顶部标题在滚离顶部时淡出，
/// 底部毛玻璃浮动工具栏。
class NoteDetailPage extends StatefulWidget {
  const NoteDetailPage({super.key});

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  late final NoteDetailController _controller;
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;
  static const double _kFadeThreshold = 40.0;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(NoteDetailController());
    final id = Get.parameters[Routes.paramId];
    if (id != null && _controller.note == null) {
      _controller.loadNote(int.parse(id));
    }
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
    return FScaffold(
      child: SafeArea(
        child: Obx(() {
          final note = _controller.note;
          if (note == null) {
            return const Center(child: FCircularProgress());
          }

          final theme = context.theme;

          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.title,
                            style: theme.typography.xl2.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),


                          const SizedBox(height: 8),
                          Text(
                            '${_formatDateTime(note.updatedAt)} 编辑',
                            style: theme.typography.xs.copyWith(
                              color: theme.colors.mutedForeground,
                            ),
                          ),


                          if (_controller.tags.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: AppTheme.spacing.sm,
                              runSpacing: AppTheme.spacing.xs,
                              children: _controller.tags
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
                                          color:
                                              theme.colors.secondaryForeground,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],


                          const SizedBox(height: 20),
                          Container(
                            height: 0.5,
                            color: theme.colors.border,
                          ),
                          const SizedBox(height: 16),


                          if (note.content.isNotEmpty)
                            MarkdownBody(
                              data: note.content,
                              styleSheet: _buildMarkdownStyle(theme),
                              onTapLink: (text, href, title) {
                                if (href != null) {
                                  openUrlWithConfirm(context, href);
                                }
                              },
                            )
                          else
                            Text(
                              '暂无内容',
                              style: theme.typography.md.copyWith(
                                color: theme.colors.mutedForeground,
                              ),
                            ),

                          const SizedBox(height: 72),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              _buildTopBar(theme),

              _buildFloatingBottomBar(theme),
            ],
          );
        }),
      ),
    );
  }

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
          Expanded(
            child: AnimatedOpacity(
              opacity: _showTitle ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Obx(
                () => Text(
                  _controller.note?.title ?? '笔记详情',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.md.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingBottomBar(FThemeData theme) {
    return Positioned(
      bottom: AppTheme.frost.barBottomMargin,
      left: AppTheme.frost.barHorizontalMargin,
      right: AppTheme.frost.barHorizontalMargin,
      child: FrostedContainer(
        blurSigma: AppTheme.frost.blurSigma,
        backgroundColor: theme.colors.background.withValues(
          alpha: AppTheme.frost.barAlpha,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius.full),
        border: Border.all(
          color: theme.colors.border.withValues(alpha: 0.35),
          width: AppTheme.frost.borderWidth,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          mainAxisSize: .min,
          children: [
            _ToolbarAction(
              icon: FLucideIcons.pencil,
              label: '编辑',
              onTap: () async {
                final noteId = _controller.note?.id;
                if (noteId != null) {
                  await Get.toNamed(
                    Routes.noteEditor,
                    parameters: {Routes.paramId: '$noteId'},
                  );
                  _controller.loadNote(noteId);
                }
              },
              theme: theme,
            ),
            _ToolbarAction(
              icon: FLucideIcons.share2,
              label: '分享',
              onTap: () {
                final note = _controller.note;
                if (note != null) {
                  ExportHelper.exportNote(note.title, note.content);
                }
              },
              theme: theme,
            ),
            _ToolbarAction(
              icon: FLucideIcons.trash2,
              label: '删除',
              onTap: () => _showDeleteDialog(context),
              isDestructive: true,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

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

  void _showDeleteDialog(BuildContext context) {
    showFDialog(
      context: context,
      builder: (context, style, animation) => FTheme(
        data: context.theme,
        child: FDialog(
          style: style,
          animation: animation,
          title: const Text('删除笔记'),
          body: Text('确定要删除「${_controller.note?.title}」吗？此操作不可撤销。'),
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
                _controller.deleteNote();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部工具栏单个操作按钮（缩小版）。
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color).paddingAll(2),
            const SizedBox(height: 3),
            Text(
              label,
              style: theme.typography.xs2.copyWith(color: labelColor),
            ),
          ],
        ),
      ),
    );
  }
}
