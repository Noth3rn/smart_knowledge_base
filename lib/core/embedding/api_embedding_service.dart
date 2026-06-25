import 'package:dio/dio.dart';

import 'embedding_service.dart';
import 'embedding_constants.dart';

/// 远程 API 嵌入服务——通过 Dio 调用 OpenAI 兼容的 /v1/embeddings 接口。
///
/// 作为 LiteRT 不可用时的备选方案，需要用户提供 API Key。
/// [isAvailable] 为 `true` 当且仅当初始化校验通过。
class ApiEmbeddingService implements EmbeddingService {
  final String _apiKey;
  final String _baseUrl;
  late final Dio _dio;
  bool _initialized = false;

  /// 创建 API 嵌入服务实例。
  ///
  /// [apiKey] — API 密钥（必填）。
  /// [baseUrl] — API 基础地址，默认为 OpenAI。
  ApiEmbeddingService({
    required this._apiKey,
    String? baseUrl,
  })  : _baseUrl = baseUrl ?? 'https://api.openai.com/v1' {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
    ));
  }

  @override
  bool get isAvailable => _initialized;

  @override
  bool get isInitialized => _initialized;

  @override
  String get backendName => EmbeddingConstants.backendApi;

  @override
  Future<void> initialize() async {
    // 发送轻量请求校验 API Key 和网络连通性
    try {
      final response = await _dio.get('/models');
      if (response.statusCode == 200) {
        _initialized = true;
        return;
      }
    } on DioException catch (e) {
      // 将 Dio 异常转换为更明确的信息
      final message = switch (e.response?.statusCode) {
        401 => 'API key is invalid (401).',
        429 => 'API rate limited (429).',
        _ => 'API connectivity check failed: ${e.message}',
      };
      throw Exception(message);
    }
    throw Exception('API connectivity check failed with unknown error.');
  }

  @override
  Future<List<double>> embed(String text) async {
    if (!_initialized) {
      throw StateError(
        'ApiEmbeddingService is not initialized. Call initialize() first.',
      );
    }

    // 截断过长的文本
    final truncated = text.length > EmbeddingConstants.maxEmbeddingChars
        ? text.substring(0, EmbeddingConstants.maxEmbeddingChars)
        : text;

    if (truncated.trim().isEmpty) {
      throw ArgumentError('Cannot embed empty text.');
    }

    final response = await _dio.post(
      '/embeddings',
      data: {
        'input': truncated,
        'model': 'text-embedding-3-small',
      },
    );

    final data = response.data as Map<String, dynamic>;
    final embeddingList = (data['data'] as List).first as Map<String, dynamic>;
    final values = (embeddingList['embedding'] as List).cast<num>();

    return values.map((v) => v.toDouble()).toList();
  }

  @override
  Future<void> dispose() async {
    _dio.close();
    _initialized = false;
  }
}
