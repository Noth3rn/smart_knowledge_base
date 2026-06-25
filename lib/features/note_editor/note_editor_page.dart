import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';

import 'note_editor_controller.dart';

class NoteEditorPage extends StatelessWidget {
  const NoteEditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NoteEditorController());

    // 从路由参数获取笔记 ID
    final id = Get.parameters['id'];
    if (id != null && controller.noteId == null) {
      controller.loadNote(int.parse(id));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.isEditing ? '编辑笔记' : '新建笔记'),
        actions: [
          // 预览切换按钮
          Obx(() => IconButton(
                icon: Icon(controller.isPreview ? Icons.edit : Icons.visibility),
                tooltip: controller.isPreview ? '编辑' : '预览',
                onPressed: () => controller.togglePreview(),
              )),
          // 保存按钮
          Obx(() => controller.isSaving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : TextButton(
                  onPressed: () => controller.save(),
                  child: const Text('保存'),
                ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 标题输入
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: TextEditingController(
                  text: controller.titleController.value)
                ..selection = TextSelection.fromPosition(TextPosition(
                    offset: controller.titleController.value.length)),
              decoration: const InputDecoration(
                hintText: '笔记标题',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: Theme.of(context).textTheme.titleLarge,
              onChanged: (v) => controller.titleController.value = v,
            ),
          ),

          // 标签输入区
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _buildTagSection(controller),
          ),

          const SizedBox(height: 8),

          // 内容区：编辑或预览
          Expanded(
            child: Obx(() => controller.isPreview
                ? _buildPreview(controller)
                : _buildEditor(controller)),
          ),
        ],
      ),
    );
  }

  Widget _buildTagSection(NoteEditorController controller) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 已添加的标签
          if (controller.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: controller.tags.map((tag) {
                  return Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 13)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => controller.removeTag(tag),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ),
          // 添加新标签
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(
                      text: controller.newTagText.value)
                    ..selection = TextSelection.fromPosition(TextPosition(
                        offset: controller.newTagText.value.length)),
                  decoration: const InputDecoration(
                    hintText: '添加标签...',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (v) => controller.newTagText.value = v,
                  onSubmitted: (v) => controller.addTag(v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () =>
                    controller.addTag(controller.newTagText.value),
                style: IconButton.styleFrom(
                  minimumSize: const Size(36, 36),
                ),
              ),
              // 自动打标签按钮
              if (controller.canGenerateTags)
                IconButton.filled(
                  icon: controller.isGeneratingTags
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  onPressed: controller.isGeneratingTags
                      ? null
                      : () => controller.generateTags(),
                  tooltip: '自动打标签',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(Get.context!)
                        .colorScheme
                        .tertiaryContainer,
                    minimumSize: const Size(36, 36),
                  ),
                ),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildEditor(NoteEditorController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        controller: TextEditingController(
            text: controller.contentController.value)
          ..selection = TextSelection.fromPosition(TextPosition(
              offset: controller.contentController.value.length)),
        decoration: const InputDecoration(
          hintText: '在此输入 Markdown 内容...',
          border: OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        onChanged: (v) => controller.contentController.value = v,
      ),
    );
  }

  Widget _buildPreview(NoteEditorController controller) {
    return Obx(() {
      final content = controller.contentController.value;
      if (content.isEmpty) {
        return const Center(child: Text('暂无内容'));
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Markdown(data: content),
      );
    });
  }
}
