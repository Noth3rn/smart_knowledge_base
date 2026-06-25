/// 嵌入后端枚举。
enum EmbeddingBackend {
  /// 自动选择：优先 LiteRT，不可用时降级 API。
  auto('auto'),

  /// 仅使用设备端 LiteRT 模型。
  litert('litert'),

  /// 仅使用远程 API。
  api('api');

  const EmbeddingBackend(this.value);

  /// 数据库中存储的字符串值。
  final String value;

  /// 用户可见的显示名称。
  String get displayName {
    return switch (this) {
      EmbeddingBackend.auto => '自动',
      EmbeddingBackend.litert => 'LiteRT',
      EmbeddingBackend.api => 'API',
    };
  }

  /// 后端方案的说明文字。
  String get description {
    return switch (this) {
      EmbeddingBackend.auto => '优先使用设备端模型，不可用时降级到 API',
      EmbeddingBackend.litert => '仅使用设备端模型，完全离线运行',
      EmbeddingBackend.api => '仅使用远程 API，需要配置 API Key',
    };
  }
}
