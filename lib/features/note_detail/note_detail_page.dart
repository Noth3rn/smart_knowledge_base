import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import '../../shared/utils/export_helper.dart';
import 'note_detail_controller.dart';

class NoteDetailPage extends StatelessWidget {
  const NoteDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NoteDetailController());
    final id = Get.parameters['id'];

    if (id != null && controller.note == null) {
      controller.loadNote(int.parse(id));
    }

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.note?.title ?? '笔记详情')),
        actions: [
          // 导出按钮
          Obx(() {
            final note = controller.note;
            if (note == null) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: '导出',
              onPressed: () =>
                  ExportHelper.exportNote(note.title, note.content),
            );
          }),
          // 编辑按钮
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final noteId = controller.note?.id;
              if (noteId != null) {
                await Get.toNamed(
                  Routes.noteEditor,
                  parameters: {'id': '$noteId'},
                );
                controller.loadNote(noteId);
              }
            },
          ),
          // 删除按钮
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showDeleteDialog(context, controller),
          ),
        ],
      ),
      body: Obx(() {
        final note = controller.note;
        if (note == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标签区
            if (controller.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: controller.tags
                      .map((t) => Chip(
                            label: Text(t.name),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ),
            if (controller.tags.isNotEmpty) const Divider(),
            // 笔记内容（Markdown 渲染）
            Expanded(
              child: note.content.isNotEmpty
                  ? Markdown(
                      data: note.content,
                      padding: const EdgeInsets.all(16),
                    )
                  : const Center(child: Text('无内容')),
            ),
            // 时间信息
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '创建于 ${note.createdAt.toString().substring(0, 16)}\n'
                '更新于 ${note.updatedAt.toString().substring(0, 16)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _showDeleteDialog(
      BuildContext context, NoteDetailController controller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('确定要删除「${controller.note?.title}」吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              controller.deleteNote();
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
