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
          prefixBuilder: (context, style, variants) =>
              Icon(FLucideIcons.search, size: 18, color: theme.colors.mutedForeground),
          suffixBuilder: (context, style, variants) => Obx(() {
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
        prefixes: [
          FHeaderAction.back(onPress: () => Get.back()),
        ],
      ),
      child: Obx(() => _buildBody(context, controller)),
    );
  }

  Widget _buildBody(BuildContext context, NoteSearchController controller) {
    final theme = context.theme;

    // 搜索中
    if (controller.isSearching) {
      return const Center(child: FCircularProgress());
    }

    // 尚未搜索
    if (!controller.hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FLucideIcons.search,
              size: 64,
              color: theme.colors.mutedForeground,
            ),
            SizedBox(height: AppTheme.spacing.lg),
            Text(
              '输入关键词进行搜索',
              style: theme.typography.lg.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }

    // 无结果
    if (controller.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FLucideIcons.searchX,
              size: 64,
              color: theme.colors.mutedForeground,
            ),
            SizedBox(height: AppTheme.spacing.sm),
            Text(
              '未找到相关笔记',
              style: theme.typography.lg,
            ),
            if (controller.searchMode == SearchMode.semantic)
              Text(
                '尝试使用其他关键词',
                style: theme.typography.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
          ],
        ),
      );
    }

    // 有结果
    return Column(
      children: [
        // 关键词模式提示条
        if (controller.searchMode == SearchMode.keyword)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colors.secondary,
            child: Row(
              children: [
                Icon(
                  FLucideIcons.info,
                  size: 16,
                  color: theme.colors.secondaryForeground,
                ),
                SizedBox(width: AppTheme.spacing.sm),
                Text(
                  '当前为关键词搜索模式',
                  style: theme.typography.sm.copyWith(
                    color: theme.colors.secondaryForeground,
                  ),
                ),
              ],
            ),
          ),

        // 结果列表
        Expanded(
          child: FTileGroup.builder(
            count: controller.results.length,
            tileBuilder: (context, index) {
              final result = controller.results[index];
              return _buildResultTile(context, result, controller);
            },
          ),
        ),
      ],
    );
  }

  /// 构建单条搜索结果。
  Widget _buildResultTile(
    BuildContext context,
    SearchResult result,
    NoteSearchController controller,
  ) {
    final note = result.note;
    final theme = context.theme;

    return FTile(
      title: Text(
        note.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.typography.lg.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        note.content.length > 80
            ? '${note.content.substring(0, 80)}...'
            : note.content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.typography.sm.copyWith(
          color: theme.colors.mutedForeground,
        ),
      ),
      details: Row(
        children: [
          // 语义模式显示相似度
          if (controller.searchMode == SearchMode.semantic) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colors.primary,
                borderRadius:
                    BorderRadius.circular(AppTheme.radius.sm),
              ),
              child: Text(
                '${(result.similarity * 100).toStringAsFixed(0)}%',
                style: theme.typography.xs.copyWith(
                  color: theme.colors.primaryForeground,
                ),
              ),
            ),
            SizedBox(width: AppTheme.spacing.sm),
          ],

          // 嵌入后端标识
          if (note.embeddingBackend != null &&
              note.embeddingBackend!.isNotEmpty)
            Text(
              note.embeddingBackend!,
              style: theme.typography.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
        ],
      ),
      suffix: const Icon(FLucideIcons.chevronRight),
      onPress: () async {
        await Get.toNamed(
          Routes.noteDetail,
          parameters: {Routes.paramId: '${note.id}'},
        );
        // 返回后刷新搜索结果
        if (controller.queryController.text.trim().isNotEmpty) {
          controller.search(controller.queryController.text.trim());
        }
      },
    );
  }
}
