/// 嵌入服务抽象接口。
///
/// 所有嵌入后端（设备端 LiteRT、远程 API、不可用兜底）均实现此接口，
/// 通过 GetX DI 注入，业务代码通过接口引用，切换后端无需改动业务逻辑。
abstract class EmbeddingService {
  /// 当前后端是否处于可用状态（已初始化且可正常调用 embed）。
  bool get isAvailable;

  /// 是否已完成初始化。
  bool get isInitialized;

  /// 后端标识名，存储到 notes.embedding_backend 列。
  /// 例如 "litert"、"api"、"none"。
  String get backendName;

  /// 一次性初始化（加载模型、校验 API Key 等）。
  /// 必须在调用 [embed] 之前执行。
  Future<void> initialize();

  /// 对 [text] 计算嵌入向量，返回浮点列表。
  /// 调用方负责将结果编码为 [Uint8List] 后存入数据库。
  Future<List<double>> embed(String text);

  /// 释放资源（关闭模型、断开连接等）。
  Future<void> dispose();
}
