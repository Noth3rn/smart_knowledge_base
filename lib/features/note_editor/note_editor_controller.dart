import 'package:get/get.dart' hide Value;
import 'package:drift/drift.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/database/app_database.dart';
import '../../core/embedding/embedding_service.dart';
import '../../core/llm/tag_generation_service.dart';
import '../../shared/utils/vector_utils.dart';

class NoteEditorController extends GetxController {
  final titleController = ''.obs;
  final contentController = ''.obs;
  final _isSaving = false.obs;
  final _noteId = Rxn<int>();
  final _tags = <String>[].obs;
  final newTagText = ''.obs;
  final _isPreview = false.obs;
  final _isGeneratingTags = false.obs;

  bool get isSaving => _isSaving.value;
  int? get noteId => _noteId.value;
  bool get isEditing => _noteId.value != null;
  List<String> get tags => _tags;
  bool get isPreview => _isPreview.value;
  bool get isGeneratingTags => _isGeneratingTags.value;
  bool get canGenerateTags =>
      Get.isRegistered<TagGenerationService>() && !_isGeneratingTags.value;

  AppDatabase get _db => Get.find<AppDatabase>();

  /// 切换编辑/预览模式
  void togglePreview() => _isPreview.toggle();

  /// 如果是编辑模式，加载已有笔记及其标签
  Future<void> loadNote(int id) async {
    _noteId.value = id;
    final note = await _db.getNoteById(id);
    if (note != null) {
      titleController.value = note.title;
      contentController.value = note.content;
      final existingTags = await _db.getTagsByNoteId(id);
      _tags.value = existingTags.map((t) => t.name).toList();
    }
  }

  /// 添加标签
  void addTag(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _tags.contains(trimmed)) return;
    if (_tags.length >= 10) {
      Get.snackbar('提示', '最多添加 10 个标签');
      return;
    }
    _tags.add(trimmed);
    newTagText.value = '';
  }

  /// 移除标签
  void removeTag(String name) {
    _tags.remove(name);
  }

  /// 调用 LLM 自动生成标签（用户手动点击按钮触发）。
  Future<void> generateTags() async {
    if (!Get.isRegistered<TagGenerationService>()) {
      Get.snackbar('提示', 'LLM 服务未就绪');
      return;
    }

    final title = titleController.value.trim();
    final content = contentController.value.trim();
    if (title.isEmpty && content.isEmpty) {
      Get.snackbar('提示', '请先输入笔记内容');
      return;
    }

    _isGeneratingTags.value = true;
    try {
      final service = Get.find<TagGenerationService>();
      final generated = await service.generateTags(title, content);

      // 合并标签（去重，最多 10 个）
      for (final tag in generated) {
        if (!_tags.contains(tag) && _tags.length < 10) {
          _tags.add(tag);
        }
      }

      Get.snackbar(
        '标签生成完成',
        '已添加 ${generated.length} 个标签',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        '标签生成失败',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isGeneratingTags.value = false;
    }
  }

  /// 保存后自动打标签（fire-and-forget，不阻塞保存）。
  void _autoGenerateTags(String title, String content) {
    final autoTag = GetStorage().read<bool>('autoTag') ?? false;
    if (!autoTag) return;
    if (!Get.isRegistered<TagGenerationService>()) return;

    // 异步调用，不等待结果
    TagGenerationService? service;
    try {
      service = Get.find<TagGenerationService>();
    } catch (_) {
      return;
    }

    service.generateTags(title, content).then((generated) {
      for (final tag in generated) {
        if (!_tags.contains(tag) && _tags.length < 10) {
          _tags.add(tag);
        }
      }
      // 更新数据库中的标签
      if (_noteId.value != null) {
        _db.addTags(_noteId.value!, generated, source: 'llm');
      }
    }).catchError((_) {
      // 静默失败——自动标签是增强功能
    });
  }

  /// 保存笔记（新建或更新）
  Future<void> save() async {
    final title = titleController.value.trim();
    final content = contentController.value.trim();

    if (title.isEmpty) {
      Get.snackbar('错误', '标题不能为空');
      return;
    }

    _isSaving.value = true;
    try {
      final entry = NotesCompanion(
        title: Value(title),
        content: Value(content),
        updatedAt: Value(DateTime.now()),
      );

      int noteId;
      if (_noteId.value != null) {
        await _db.updateNote(_noteId.value!, entry);
        noteId = _noteId.value!;
        // 更新标签：先删后加
        await _db.removeTagsByNoteId(noteId);
      } else {
        noteId = await _db.insertNote(entry);
      }

      // 保存手动标签
      if (_tags.isNotEmpty) {
        await _db.addTags(noteId, _tags, source: 'manual');
      }

      // Phase 3 — 异步触发嵌入计算（fire-and-forget，不阻塞保存返回）
      _computeEmbedding(noteId, title, content); // 无 await

      // Phase 5 — 自动打标签（如果设置中开启）
      _autoGenerateTags(title, content);

      Get.back(result: true);
    } finally {
      _isSaving.value = false;
    }
  }

  /// 后台计算文本嵌入向量并写入数据库。
  ///
  /// 全程 try/catch，失败静默——嵌入是增强功能，笔记已成功保存。
  Future<void> _computeEmbedding(
    int noteId,
    String title,
    String content,
  ) async {
    try {
      // 检查 EmbeddingService 是否已注册且可用
      if (!Get.isRegistered<EmbeddingService>()) return;
      final embeddingService = Get.find<EmbeddingService>();
      if (!embeddingService.isAvailable) return;

      // 拼接标题和内容以获取更丰富的语义
      final textToEmbed = '$title\n\n$content';
      if (textToEmbed.trim().isEmpty) return;

      final vector = await embeddingService.embed(textToEmbed);

      // 编码为 BLOB 兼容的字节数组并写入数据库
      final bytes = VectorUtils.encode(vector);
      await _db.updateEmbedding(
        noteId,
        bytes,
        embeddingService.backendName,
      );
    } catch (_) {
      // 静默失败——嵌入仅用于增强语义搜索，不影响基本笔记功能
    }
  }
}
