import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart' hide ContextExtensionss;

import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import 'note_search_controller.dart';

/// 语义/关键词搜索页。
///
/// 输入查询文本后自动触发搜索（300ms 防抖），
/// 在语义搜索可用时优先使用语义搜索，否则降级为关键词搜索。
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NoteSearchController());
    final theme = context.theme;

    return FScaffold(
      header: FHeader.nested(
        title: FTextField(
          control: .managed(
            controller: controller.queryController,
            onChange: (v) => controller.onQueryChanged(v.text),
          ),
          hint: '搜索笔记标题或内容...',
          autofocus: true,
          prefixBuilder: (context, style, variants) => Icon(
            FLucideIcons.search,
            size: 18,
            color: theme.colors.mutedForeground,
          ),
          suffixBuilder: (context, style, variants) => Obx(() {
            if (controller.queryText.isEmpty) return const SizedBox.shrink();
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
        prefixes: [
          FHeaderAction.back(onPress: () => Get.back()),
        ],
      ),
      child: Obx(() => _buildBody(context, controller)),
    );
  }

  Widget _buildBody(BuildContext context, NoteSearchController controller) {
    final theme = context.theme;

    if (controller.isSearching) {
      return const Center(child: FCircularProgress());
    }

    if (!controller.hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FLucideIcons.search, size: 52, color: theme.colors.mutedForeground),
            SizedBox(height: AppTheme.spacing.md),
            Text(
              '输入关键词进行搜索',
              style: theme.typography.md.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }

    if (controller.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FLucideIcons.searchX, size: 52, color: theme.colors.mutedForeground),
            SizedBox(height: AppTheme.spacing.md),
            Text('未找到相关笔记', style: theme.typography.md),
            SizedBox(height: AppTheme.spacing.xs),
            Text(
              '换个关键词试试',
              style: theme.typography.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 关键词模式提示条
        if (controller.searchMode == SearchMode.keyword)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.colors.secondary,
            child: Row(
              children: [
                Icon(FLucideIcons.info, size: 14, color: theme.colors.mutedForeground),
                SizedBox(width: AppTheme.spacing.sm),
                Text(
                  '关键词搜索模式（语义模型未加载）',
                  style: theme.typography.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),

        // 结果列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: controller.results.length,
            itemBuilder: (context, index) =>
                _buildResultCard(context, controller.results[index], controller),
          ),
        ),
      ],
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
            // 标题行 + 相似度徽章
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
          ],
        ),
      ),
    );
  }
}
