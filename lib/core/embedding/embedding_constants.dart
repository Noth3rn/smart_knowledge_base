/// 嵌入模块与全局配置的共享常量。
class EmbeddingConstants {
  EmbeddingConstants._();

  // ---------- 模型下载 ----------

  /// 默认嵌入模型下载 URL（EmbeddingGemma 300M, 512 seq, mixed precision）。
  static const String defaultModelUrl =
      'https://huggingface.co/litert-community/embeddinggemma-300m/'
      'resolve/main/embeddinggemma-300M_seq512_mixed-precision.tflite';

  /// 默认分词器下载 URL（SentencePiece model）。
  static const String defaultTokenizerUrl =
      'https://huggingface.co/litert-community/embeddinggemma-300m/'
      'resolve/main/sentencepiece.model';

  /// 模型存储目录名（位于应用文档目录下）。
  static const String modelDirName = 'models';

  /// 模型文件名。
  static const String modelFileName = 'embedding_model.tflite';

  // ---------- GetStorage 键 ----------

  /// 用户配置的模型下载 URL。
  static const String keyModelUrl = 'embeddingModelUrl';

  /// 用户配置的分词器下载 URL。
  static const String keyTokenizerUrl = 'embeddingTokenizerUrl';

  /// 已下载模型的绝对路径。
  static const String keyModelPath = 'modelDownloadPath';

  /// 用户是否选择跳过模型下载。
  static const String keySkipDownload = 'skipModelDownload';

  /// HuggingFace Token（安全存储）。
  static const String keyHfToken = 'huggingFaceToken';

  /// 用户偏好的嵌入后端。
  static const String keyPreferredBackend = 'preferredEmbeddingBackend';

  /// 保存时自动生成标签开关。
  static const String keyAutoTag = 'autoTag';

  /// LLM 模型名称。
  static const String keyLlmModelName = 'llmModelName';

  // ---------- 后端名称 ----------

  static const String backendLiteRt = 'litert';
  static const String backendApi = 'api';
  static const String backendNone = 'none';
  static const String backendAuto = 'auto';

  // ---------- 嵌入参数 ----------

  /// 嵌入文本最大字符数（超出部分截断，避免超出模型上下文窗口）。
  static const int maxEmbeddingChars = 2048;
}
