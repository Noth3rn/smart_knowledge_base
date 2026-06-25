import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/embedding/embedding_service.dart';
import '../../core/embedding/embedding_constants.dart';
import '../../core/embedding/litert_embedding_service.dart';

/// 模型下载页面状态枚举。
enum DownloadStatus {
  idle,
  downloadingModel,
  downloadingTokenizer,
  completed,
  failed,
}

/// 模型下载控制器——使用 flutter_gemma 的 installEmbedder API 下载嵌入模型。
class ModelDownloadController extends GetxController {
  final _status = DownloadStatus.idle.obs;
  DownloadStatus get status => _status.value;

  final _modelProgress = 0.obs;
  int get modelProgress => _modelProgress.value;

  final _tokenizerProgress = 0.obs;
  int get tokenizerProgress => _tokenizerProgress.value;

  final _statusMessage = ''.obs;
  String get statusMessage => _statusMessage.value;

  final _hasError = false.obs;
  bool get hasError => _hasError.value;

  final _isDownloading = false.obs;
  bool get isDownloading => _isDownloading.value;

  late final TextEditingController modelUrlController;
  late final TextEditingController tokenizerUrlController;
  late final TextEditingController hfTokenController;

  final _secureStorage = const FlutterSecureStorage();
  CancelToken? _cancelToken;

  @override
  void onInit() {
    super.onInit();
    final box = GetStorage();
    modelUrlController = TextEditingController(
      text: box.read<String>(EmbeddingConstants.keyModelUrl) ??
          EmbeddingConstants.defaultModelUrl,
    );
    tokenizerUrlController = TextEditingController(
      text: box.read<String>(EmbeddingConstants.keyTokenizerUrl) ??
          EmbeddingConstants.defaultTokenizerUrl,
    );
    hfTokenController = TextEditingController();
    _loadHfToken();
  }

  Future<void> _loadHfToken() async {
    final token = await _secureStorage.read(key: EmbeddingConstants.keyHfToken);
    if (token != null) {
      hfTokenController.text = token;
    }
  }

  @override
  void onClose() {
    modelUrlController.dispose();
    tokenizerUrlController.dispose();
    hfTokenController.dispose();
    super.onClose();
  }

  String get modelUrl => modelUrlController.text.trim();
  String get tokenizerUrl => tokenizerUrlController.text.trim();
  String get hfToken => hfTokenController.text.trim();

  bool get canStartDownload =>
      modelUrl.isNotEmpty && tokenizerUrl.isNotEmpty && !_isDownloading.value;

  /// 开始下载嵌入模型。
  Future<void> startDownload() async {
    if (modelUrl.isEmpty || tokenizerUrl.isEmpty) {
      _statusMessage.value = '请先填写模型和分词器的下载地址。';
      return;
    }

    final box = GetStorage();
    box.write(EmbeddingConstants.keyModelUrl, modelUrl);
    box.write(EmbeddingConstants.keyTokenizerUrl, tokenizerUrl);

    if (hfToken.isNotEmpty) {
      await _secureStorage.write(key: EmbeddingConstants.keyHfToken, value: hfToken);
    }

    _hasError.value = false;
    _isDownloading.value = true;
    _cancelToken = CancelToken();

    try {
      _status.value = DownloadStatus.downloadingModel;
      _statusMessage.value = '正在下载嵌入模型...';
      _modelProgress.value = 0;
      _tokenizerProgress.value = 0;

      await FlutterGemma.installEmbedder()
          .modelFromNetwork(modelUrl, token: hfToken.isNotEmpty ? hfToken : null)
          .tokenizerFromNetwork(tokenizerUrl,
              token: hfToken.isNotEmpty ? hfToken : null)
          .withModelProgress((progress) {
            if (progress >= 0 && progress <= 100) {
              _modelProgress.value = progress;
              _statusMessage.value = '正在下载嵌入模型... $progress%';
            }
          })
          .withTokenizerProgress((progress) {
            if (progress >= 0 && progress <= 100) {
              _tokenizerProgress.value = progress;
              _statusMessage.value = '正在下载分词器... $progress%';
            }
          })
          .withCancelToken(_cancelToken!)
          .install();

      _status.value = DownloadStatus.completed;
      _statusMessage.value = '模型下载完成！点击"继续"启用设备端语义搜索。';
      _isDownloading.value = false;
    } catch (e) {
      if (e is DownloadCancelledException) {
        _status.value = DownloadStatus.idle;
        _statusMessage.value = '下载已取消。';
      } else {
        _status.value = DownloadStatus.failed;
        final errorStr = e.toString();
        if (errorStr.contains('401')) {
          _statusMessage.value =
              '下载失败 (401)：需要登录授权。\n'
              '该模型需要 HuggingFace Token 才能下载。\n'
              '请在 https://huggingface.co/settings/tokens 创建 Token 后填入上方。';
        } else if (errorStr.contains('404') || errorStr.contains('notFound')) {
          _statusMessage.value =
              '下载失败 (404)：文件未找到。请检查 URL 是否正确。';
        } else {
          _statusMessage.value = '下载失败：$errorStr';
        }
        _hasError.value = true;
      }
      _isDownloading.value = false;
    }
  }

  /// 取消正在进行的下载。
  void cancel() {
    _cancelToken?.cancel('用户取消下载');
    _isDownloading.value = false;
    _status.value = DownloadStatus.idle;
    _statusMessage.value = '下载已取消。';
  }

  /// 下载完成后，重新初始化设备端嵌入服务并返回。
  Future<void> continueWithModel() async {
    try {
      final litertService = LiteRtEmbeddingService();
      await litertService.reinitialize();

      if (litertService.isAvailable) {
        Get.replace<EmbeddingService>(litertService);
        GetStorage().remove(EmbeddingConstants.keySkipDownload);
      }
    } catch (_) {}
  }

  /// 跳过模型下载。
  Future<void> skip() async {
    final box = GetStorage();
    if (modelUrl.isNotEmpty) {
      box.write(EmbeddingConstants.keyModelUrl, modelUrl);
    }
    if (tokenizerUrl.isNotEmpty) {
      box.write(EmbeddingConstants.keyTokenizerUrl, tokenizerUrl);
    }
    if (hfToken.isNotEmpty) {
      await _secureStorage.write(key: EmbeddingConstants.keyHfToken, value: hfToken);
    }
    box.write(EmbeddingConstants.keySkipDownload, true);
  }

  /// 重试下载。
  Future<void> retry() async {
    _hasError.value = false;
    await startDownload();
  }
}
