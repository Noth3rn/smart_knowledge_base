import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';

import 'embedding_service.dart';
import 'embedding_constants.dart';

/// 设备端 LiteRT 嵌入服务——使用 flutter_gemma + flutter_gemma_embeddings
/// 在本地运行 Gecko/EmbeddingGemma 模型进行文本向量化。
///
/// 前置条件：必须在 [initialize] 前调用过
/// `FlutterGemma.initialize(embeddingBackends: [LiteRtEmbeddingBackend()])`
/// 并通过 `FlutterGemma.installEmbedder()` 安装模型。
///
/// [isAvailable] 为 `true` 当且仅当有活跃的嵌入模型且初始化成功。
class LiteRtEmbeddingService implements EmbeddingService {
  EmbeddingModel? _model;
  bool _initialized = false;

  @override
  bool get isAvailable => _model != null;

  @override
  bool get isInitialized => _initialized;

  @override
  String get backendName => EmbeddingConstants.backendLiteRt;

  @override
  Future<void> initialize() async {
    _initialized = true;

    if (!FlutterGemma.hasActiveEmbedder()) {
      // 模型尚未安装——标记为不可用但不算初始化失败。
      // 上层应引导用户下载模型后再调用 reinitialize()。
      _model = null;
      return;
    }

    try {
      _model = await FlutterGemma.getActiveEmbedder();
    } catch (e) {
      _model = null;
      rethrow;
    }
  }

  /// 在模型下载成功后重新初始化，尝试获取已安装的嵌入模型。
  Future<void> reinitialize() async {
    if (!FlutterGemma.hasActiveEmbedder()) {
      _model = null;
      throw StateError('No active embedding model after download.');
    }
    _model = await FlutterGemma.getActiveEmbedder();
    _initialized = true;
  }

  @override
  Future<List<double>> embed(String text) async {
    if (_model == null) {
      throw StateError(
        'LiteRtEmbeddingService is not available. '
        'Install an embedding model first.',
      );
    }

    // 截断过长的文本，避免超出模型上下文窗口
    final truncated = text.length > EmbeddingConstants.maxEmbeddingChars
        ? text.substring(0, EmbeddingConstants.maxEmbeddingChars)
        : text;

    if (truncated.trim().isEmpty) {
      throw ArgumentError('Cannot embed empty text.');
    }

    return _model!.generateEmbedding(
      truncated,
      taskType: TaskType.retrievalDocument, // 文档索引模式
    );
  }

  @override
  Future<void> dispose() async {
    if (_model != null) {
      await _model!.close();
      _model = null;
      _initialized = false;
    }
  }
}
