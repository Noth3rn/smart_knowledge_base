import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show InputBorder;
import 'package:forui/forui.dart';
import 'package:get/get.dart' hide ContextExtensionss;

import '../../routes/app_routes.dart';
import '../../shared/widgets/frosted_container.dart';
import '../../theme/app_theme.dart';
import 'note_search_controller.dart';

/// 语义/关键词搜索页。
///
/// 底部毛玻璃浮动搜索栏，返回按钮左上角，
/// 支持时间 + 标签筛选，结果卡片带 tag badge。
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NoteSearchController());
    final theme = context.theme;

    return FScaffold(
      child: SafeArea(
        child: Stack(
          children: [
            Obx(() => _buildBody(context, controller)),
            _buildBackButton(theme),
            _buildFloatingSearchBar(theme, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton(FThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 12),
      child: GestureDetector(
        onTap: () => Get.back(),
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
          child: Icon(
            FLucideIcons.chevronLeft,
            size: 18,
            color: theme.colors.foreground,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingSearchBar(
    FThemeData theme,
    NoteSearchController controller,
  ) {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: FTextField(
          control: .managed(
            controller: controller.queryController,
            onChange: (v) => controller.onQueryChanged(v.text),
          ),
          style: .delta(
            color: FVariantsValueDelta.delta([
              FVariantValueDeltaOperation.all(null),
            ]),
            border: FVariantsValueDelta.delta([
              FVariantValueDeltaOperation.all(InputBorder.none),
            ]),
          ),
          hint: '搜索笔记标题或内容...',
          autofocus: true,
          suffixBuilder: (ctx, style, variants) => Obx(() {
            if (controller.queryText.isEmpty) {
              return const SizedBox.shrink();
            }
            return GestureDetector(
              onTap: () => controller.clear(),
              child: Icon(
                FLucideIcons.x,
                size: 18,
                color: theme.colors.mutedForeground,
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, NoteSearchController controller) {
    final theme = context.theme;

    if (controller.isSearching) {
      return const Center(child: FCircularProgress());
    }

    return Column(
      children: [
        if (controller.searchMode == SearchMode.keyword)
          _buildKeywordNotice(theme),

        _buildFilterBar(theme, controller),

        if (!controller.hasSearched)
        _buildIdleState(theme),

        if (controller.hasSearched && controller.results.isEmpty)
          _buildNoResults(theme),

        if (controller.hasSearched && controller.results.isNotEmpty)
        Expanded(
          child: ListView.builder(
            padding:
            const EdgeInsets.only(top: 4, bottom: 72),
            itemCount: controller.results.length,
            itemBuilder: (context, index) => _buildResultCard(
              context,
              controller.results[index],
              controller,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdleState(FThemeData theme) {
    return Expanded(child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FLucideIcons.search,
            size: 52,
            color: theme.colors.mutedForeground,
          ),
          SizedBox(height: AppTheme.spacing.md),
          Text(
            '输入关键词进行搜索',
            style: theme.typography.md.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildNoResults(FThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FLucideIcons.searchX,
            size: 52,
            color: theme.colors.mutedForeground,
          ),
          SizedBox(height: AppTheme.spacing.md),
          Text('未找到相关笔记', style: theme.typography.md),
          SizedBox(height: AppTheme.spacing.xs),
          Text(
            '换个关键词或调整筛选条件试试',
            style: theme.typography.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeywordNotice(FThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(top: 52),
      color: theme.colors.secondary,
      child: Row(
        children: [
          Icon(
            FLucideIcons.info,
            size: 14,
            color: theme.colors.mutedForeground,
          ),
          SizedBox(width: AppTheme.spacing.sm),
          Text(
            '关键词搜索模式（语义模型未加载）',
            style: theme.typography.xs.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(FThemeData theme, NoteSearchController controller) {
    return Column(
      children: [
        SizedBox(height: AppTheme.spacing.lg),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(top: 40),
          child: GestureDetector(
            onTap: () => controller.toggleFilter(),
            behavior: HitTestBehavior.opaque,
            child: Obx(() {
              return Row(
                children: [
                  Text(
                    '筛选条件',
                    style: theme.typography.sm.copyWith(
                      color: theme.colors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    controller.filterExpanded
                        ? FLucideIcons.chevronUp
                        : FLucideIcons.chevronDown,
                    size: 16,
                    color: theme.colors.mutedForeground,
                  ),
                ],
              );
            }),
          ),
        ),


        Obx(() {
          if (!controller.filterExpanded) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: AppTheme.spacing.md),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '时间',
                  style: theme.typography.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ),
              SizedBox(height: AppTheme.spacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: AppTheme.spacing.sm,
                  runSpacing: AppTheme.spacing.sm,
                  children: TimeFilter.values
                      .where((f) => f != TimeFilter.none)
                      .map((f) => _buildCapsuleOption(
                            theme: theme,
                            label: f.label,
                            selected: controller.timeFilter == f,
                            onTap: () => controller.setTimeFilter(f),
                          ))
                      .toList(),
                ),
              ),


              if (controller.allTags.isNotEmpty) ...[
                SizedBox(height: AppTheme.spacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '标签',
                    style: theme.typography.xs.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.spacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Obx(() {
                    return Wrap(
                      spacing: AppTheme.spacing.sm,
                      runSpacing: AppTheme.spacing.sm,
                      children: controller.allTags.map((tag) {
                        final selected =
                            controller.selectedTags.contains(tag);
                        return _buildCapsuleOption(
                          theme: theme,
                          label: tag,
                          selected: selected,
                          onTap: () => controller.toggleTag(tag),
                        );
                      }).toList(),
                    );
                  }),
                ),
              ],

              SizedBox(height: AppTheme.spacing.sm),
              const FDivider(),
            ],
          );
        }),

        if (!controller.filterExpanded) const FDivider(),
      ],
    );
  }

  /// 胶囊单选/多选按钮。
  Widget _buildCapsuleOption({
    required FThemeData theme,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? theme.colors.primary.withValues(alpha: 0.25)
              : theme.colors.secondary,
          borderRadius: BorderRadius.circular(AppTheme.radius.full),
          border: Border.all(
            color: selected
                ? theme.colors.primary.withValues(alpha: 0.5)
                : theme.colors.border.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          label,
          style: theme.typography.xs.copyWith(
            color: selected ? theme.colors.primary : theme.colors.foreground,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    SearchResult result,
    NoteSearchController controller,
  ) {
    final note = result.note;
    final theme = context.theme;
    final preview = note.content.length > 100
        ? '${note.content.substring(0, 100)}...'
        : note.content;

    return GestureDetector(
      onTap: () async {
        await Get.toNamed(
          Routes.noteDetail,
          parameters: {Routes.paramId: '${note.id}'},
        );
        if (controller.queryController.text.trim().isNotEmpty) {
          controller.search(controller.queryController.text.trim());
        }
      },
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.md.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (controller.searchMode == SearchMode.semantic) ...[
                  SizedBox(width: AppTheme.spacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radius.sm),
                    ),
                    child: Text(
                      '${(result.similarity * 100).toStringAsFixed(0)}%',
                      style: theme.typography.xs.copyWith(
                        color: theme.colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            if (preview.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],


            if (result.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: result.tags
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
            ],
          ],
        ),
      ),
    );
  }
}
