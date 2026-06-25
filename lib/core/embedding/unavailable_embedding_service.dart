import 'embedding_service.dart';
import 'embedding_constants.dart';

/// 空操作嵌入服务——当 LiteRT 和远程 API 均不可用时的兜底实现。
///
/// [isAvailable] 返回 `false`，调用 [embed] 会抛出 [UnsupportedError]。
/// 业务代码应在调用 embed 前检查 [isAvailable]。
class UnavailableEmbeddingService implements EmbeddingService {
  @override
  bool get isAvailable => false;

  @override
  bool get isInitialized => true; // 无需初始化

  @override
  String get backendName => EmbeddingConstants.backendNone;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<double>> embed(String text) async {
    throw UnsupportedError(
      'Embedding is not available. Semantic search is disabled.',
    );
  }

  @override
  Future<void> dispose() async {}
}
