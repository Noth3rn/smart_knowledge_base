import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/embedding/embedding_constants.dart';
import '../../core/enum/embedding_backend.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../main.dart' show reinitEmbeddingService;

/// 设置页控制器——管理 LLM API 配置、嵌入后端选择、自动标签开关。
class SettingsController extends GetxController {
  final apiKeyController = TextEditingController();
  final baseUrlController = TextEditingController();
  final modelNameController = TextEditingController();

  final _embeddingBackend = EmbeddingBackend.auto.value.obs;
  String get embeddingBackend => _embeddingBackend.value;

  final _autoTag = false.obs;
  bool get autoTag => _autoTag.value;

  final _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  final _secureStorage = SecureStorageService();
  final _box = GetStorage();

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  @override
  void onClose() {
    apiKeyController.dispose();
    baseUrlController.dispose();
    modelNameController.dispose();
    super.onClose();
  }

  /// 从存储加载当前设置。
  Future<void> loadSettings() async {
    _isLoading.value = true;

    final apiKey = await _secureStorage.getApiKey();
    if (apiKey != null) {
      apiKeyController.text = apiKey;
    }

    final baseUrl = await _secureStorage.getBaseUrl();
    baseUrlController.text = baseUrl ?? 'https://api.deepseek.com/v1';

    modelNameController.text =
        _box.read<String>(EmbeddingConstants.keyLlmModelName) ?? 'deepseek-chat';

    _embeddingBackend.value =
        _box.read<String>(EmbeddingConstants.keyPreferredBackend) ??
            EmbeddingBackend.auto.value;

    _autoTag.value =
        _box.read<bool>(EmbeddingConstants.keyAutoTag) ?? false;

    _isLoading.value = false;
  }

  /// 保存 API Key 到安全存储。
  Future<void> saveApiKey(String value) async {
    await _secureStorage.setApiKey(value.trim());
  }

  /// 保存 Base URL 到安全存储。
  Future<void> saveBaseUrl(String value) async {
    final url = value.trim();
    await _secureStorage.setBaseUrl(url.isNotEmpty ? url : null);
  }

  /// 保存 LLM 模型名称。
  void saveModelName(String value) {
    _box.write(EmbeddingConstants.keyLlmModelName, value.trim());
  }

  /// 切换嵌入后端方案并重新初始化。
  Future<void> changeEmbeddingBackend(String value) async {
    _embeddingBackend.value = value;
    _box.write(EmbeddingConstants.keyPreferredBackend, value);
    await reinitEmbeddingService();
  }

  /// 切换"保存时自动生成标签"开关。
  void toggleAutoTag(bool value) {
    _autoTag.value = value;
    _box.write(EmbeddingConstants.keyAutoTag, value);
  }
}
