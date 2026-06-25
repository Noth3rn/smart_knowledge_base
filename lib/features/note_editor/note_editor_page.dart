import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart' hide ContextExtensionss;

import '../../theme/app_theme.dart';
import 'note_editor_controller.dart';

/// 笔记编辑页——支持 Markdown 编辑与预览双模式切换。
///
/// 提供标题输入、标签管理、内容编辑/预览、保存等功能。
class NoteEditorPage extends StatelessWidget {
  const NoteEditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NoteEditorController());

    // 从路由参数获取笔记 ID（编辑模式）
    final id = Get.parameters['id'];
    if (id != null && controller.noteId == null) {
      controller.loadNote(int.parse(id));
    }

    return FScaffold(
      header: FHeader.nested(
        title: Text(controller.isEditing ? '编辑笔记' : '新建笔记'),
        prefixes: [
          FHeaderAction.back(onPress: () => Get.back()),
        ],
        suffixes: [
          // 预览切换
          Obx(() => FHeaderAction(
                icon: Icon(
                  controller.isPreview
                      ? FLucideIcons.pencil
                      : FLucideIcons.eye,
                ),
                onPress: () => controller.togglePreview(),
              )),
          // 保存
          Obx(() {
            if (controller.isSaving) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: FCircularProgress(size: .sm),
                ),
              );
            }
            return FHeaderAction(
              icon: const Icon(FLucideIcons.check),
              onPress: () => controller.save(),
            );
          }),
        ],
      ),
      child: Column(
        children: [
          // 标题输入
          Obx(() => Padding(
                padding: AppTheme.edgeInsets.editorPadding,
                child: FTextField(
                  control: .managed(
                    initial: TextEditingValue(
                      text: controller.titleController.value,
                    ),
                    onChange: (v) =>
                        controller.titleController.value = v.text,
                  ),
                  hint: '笔记标题',
                  size: .lg,
                ),
              )),

          // 标签输入区
          Padding(
            padding: AppTheme.edgeInsets.editorTagPadding,
            child: _buildTagSection(context, controller),
          ),

          SizedBox(height: AppTheme.spacing.sm),

          // 内容区：编辑或预览
          Expanded(
            child: Obx(() => controller.isPreview
                ? _buildPreview(context, controller)
                : _buildEditor(context, controller)),
          ),
        ],
      ),
    );
  }

  /// 标签管理区域——已添加标签 + 新标签输入 + 自动打标签按钮。
  Widget _buildTagSection(
    BuildContext context,
    NoteEditorController controller,
  ) {
    final theme = context.theme;

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
                runSpacing: AppTheme.spacing.xs,
                children: controller.tags.map((tag) {
                  return Container(
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tag,
                          style: theme.typography.xs.copyWith(
                            color: theme.colors.secondaryForeground,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => controller.removeTag(tag),
                          child: Icon(
                            FLucideIcons.x,
                            size: 14,
                            color: theme.colors.secondaryForeground,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // 添加新标签
          Row(
            children: [
              Expanded(
                child: Obx(() => FTextField(
                      control: .managed(
                        initial: TextEditingValue(
                          text: controller.newTagText.value,
                        ),
                        onChange: (v) =>
                            controller.newTagText.value = v.text,
                      ),
                      hint: '添加标签...',
                      size: .sm,
                      onSubmit: (v) => controller.addTag(v),
                    )),
              ),
              SizedBox(width: AppTheme.spacing.sm),
              FButton.icon(
                variant: .outline,
                size: .sm,
                onPress: () =>
                    controller.addTag(controller.newTagText.value),
                child: const Icon(FLucideIcons.plus, size: 18),
              ),

              // 自动打标签按钮
              if (controller.canGenerateTags) ...[
                SizedBox(width: AppTheme.spacing.xs),
                FButton.icon(
                  variant: .outline,
                  size: .sm,
                  onPress: controller.isGeneratingTags
                      ? null
                      : () => controller.generateTags(),
                  child: controller.isGeneratingTags
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: FCircularProgress(size: .sm),
                        )
                      : const Icon(FLucideIcons.sparkles, size: 16),
                ),
              ],
            ],
          ),
        ],
      );
    });
  }

  /// Markdown 编辑区。
  Widget _buildEditor(
    BuildContext context,
    NoteEditorController controller,
  ) {
    return Obx(() => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FTextField(
                control: .managed(
                  initial: TextEditingValue(
                    text: controller.contentController.value,
                  ),
                  onChange: (v) =>
                      controller.contentController.value = v.text,
                ),
                hint: '在此输入 Markdown 内容...',
                maxLines: null,
                expands: true,
                size: .md,
              ),
            ));
  }

  /// Markdown 预览区。
  Widget _buildPreview(
    BuildContext context,
    NoteEditorController controller,
  ) {
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
