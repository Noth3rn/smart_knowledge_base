import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../embedding/embedding_constants.dart';

/// 安全存储服务——封装 flutter_secure_storage，用于管理 API Key 等敏感信息。
class SecureStorageService {
  static const _keyApiKey = 'llm_api_key';
  static const _keyBaseUrl = 'llm_base_url';

  final FlutterSecureStorage _storage;

  /// 创建安全存储服务实例。
  ///
  /// 可选的 [storage] 参数用于测试时注入自定义实现，默认使用系统安全存储。
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// 读取已保存的 LLM API Key。
  Future<String?> getApiKey() => _storage.read(key: _keyApiKey);

  /// 读取已保存的 LLM API Base URL。
  Future<String?> getBaseUrl() => _storage.read(key: _keyBaseUrl);

  /// 保存 LLM API Key 到安全存储。
  Future<void> setApiKey(String key) =>
      _storage.write(key: _keyApiKey, value: key);

  /// 保存 LLM API Base URL 到安全存储。
  Future<void> setBaseUrl(String? url) =>
      _storage.write(key: _keyBaseUrl, value: url);

  /// 读取已保存的 HuggingFace Token。
  Future<String?> getHfToken() =>
      _storage.read(key: EmbeddingConstants.keyHfToken);
  /// 保存 HuggingFace Token 到安全存储。
  Future<void> setHfToken(String token) =>
      _storage.write(key: EmbeddingConstants.keyHfToken, value: token);

  /// 清空所有已保存的密钥和 Token。
  Future<void> clear() async {
    await _storage.delete(key: _keyApiKey);
    await _storage.delete(key: _keyBaseUrl);
    await _storage.delete(key: EmbeddingConstants.keyHfToken);
  }
}
