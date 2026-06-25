import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import 'note_search_controller.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NoteSearchController());
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: controller.queryController,
          autofocus: true,
          style: theme.textTheme.titleMedium,
          decoration: InputDecoration(
            hintText: '搜索笔记标题或内容...',
            border: InputBorder.none,
            suffixIcon: Obx(() {
              if (controller.queryText.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => controller.clear(),
              );
            }),
          ),
          onChanged: controller.onQueryChanged,
        ),
      ),
      body: Obx(() => _buildBody(context, controller)),
    );
  }

  Widget _buildBody(BuildContext context, NoteSearchController controller) {
    // 搜索中
    if (controller.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    // 尚未搜索
    if (!controller.hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              '输入关键词进行搜索',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              Icons.search_off,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              '未找到相关笔记',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (controller.searchMode == SearchMode.semantic)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '尝试使用其他关键词',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  '当前为关键词搜索模式',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
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
            itemBuilder: (context, index) {
              final result = controller.results[index];
              return _buildResultTile(context, result, controller);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultTile(
    BuildContext context,
    SearchResult result,
    NoteSearchController controller,
  ) {
    final note = result.note;
    final theme = Theme.of(context);

    return ListTile(
      title: Text(
        note.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            note.content.length > 80
                ? '${note.content.substring(0, 80)}...'
                : note.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              // 语义模式显示相似度
              if (controller.searchMode == SearchMode.semantic) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${(result.similarity * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // 嵌入后端标识
              if (note.embeddingBackend != null &&
                  note.embeddingBackend!.isNotEmpty)
                Text(
                  note.embeddingBackend!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await Get.toNamed(
          Routes.noteDetail,
          parameters: {'id': '${note.id}'},
        );
        // 返回后刷新搜索结果（笔记可能被编辑/删除）
        if (controller.queryController.text.trim().isNotEmpty) {
          controller.search(controller.queryController.text.trim());
        }
      },
    );
  }
}
