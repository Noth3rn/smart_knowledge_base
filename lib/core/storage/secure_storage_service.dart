import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../embedding/embedding_constants.dart';

/// 安全存储服务——封装 flutter_secure_storage，用于管理 API Key 等敏感信息。
class SecureStorageService {
  static const _keyApiKey = 'llm_api_key';
  static const _keyBaseUrl = 'llm_base_url';

  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  // ---------- LLM API ----------

  Future<String?> getApiKey() => _storage.read(key: _keyApiKey);
  Future<String?> getBaseUrl() => _storage.read(key: _keyBaseUrl);
  Future<void> setApiKey(String key) =>
      _storage.write(key: _keyApiKey, value: key);
  Future<void> setBaseUrl(String? url) =>
      _storage.write(key: _keyBaseUrl, value: url);

  // ---------- HuggingFace ----------

  Future<String?> getHfToken() =>
      _storage.read(key: EmbeddingConstants.keyHfToken);
  Future<void> setHfToken(String token) =>
      _storage.write(key: EmbeddingConstants.keyHfToken, value: token);

  Future<void> clear() async {
    await _storage.delete(key: _keyApiKey);
    await _storage.delete(key: _keyBaseUrl);
    await _storage.delete(key: EmbeddingConstants.keyHfToken);
  }
}
