import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/database/app_database.dart';
import '../../routes/app_routes.dart';
import 'note_list_controller.dart';

class NoteListPage extends StatelessWidget {
  const NoteListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NoteListController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartKnowledgeBase'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Get.toNamed(Routes.search),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Get.toNamed(Routes.settings),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.notes.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.note_add_outlined, size: 64,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text('还没有笔记，点击右下角创建',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: controller.notes.length,
          itemBuilder: (context, index) {
            final note = controller.notes[index];
            return Card(
              child: ListTile(
                title: Text(note.title, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(note.content.isNotEmpty
                    ? note.content.replaceAll('\n', ' ').substring(
                        0, note.content.length > 100 ? 100 : note.content.length) +
                        (note.content.length > 100 ? '...' : '')
                    : '无内容'),
                trailing: Text(
                  '${note.updatedAt.month}/${note.updatedAt.day}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () async {
                  await Get.toNamed(
                    Routes.noteDetail,
                    parameters: {'id': '${note.id}'},
                  );
                  controller.loadNotes();
                },
                onLongPress: () {
                  _showDeleteDialog(context, controller, note);
                },
              ),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Get.toNamed(Routes.noteEditor);
          controller.loadNotes();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, NoteListController controller, Note note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('确定要删除「${note.title}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              controller.deleteNote(note.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
