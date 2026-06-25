import 'package:flutter/widgets.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_embeddings/flutter_gemma_embeddings.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/embedding/embedding_constants.dart';
import 'core/embedding/embedding_service.dart';
import 'core/embedding/api_embedding_service.dart';
import 'core/embedding/litert_embedding_service.dart';
import 'core/embedding/unavailable_embedding_service.dart';
import 'core/enum/embedding_backend.dart';
import 'core/llm/tag_generation_service.dart';
import 'core/storage/secure_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  // Phase 1 — 初始化数据库
  Get.put(AppDatabase());

  // Phase 5 — 注册 LLM 标签服务（延迟初始化）
  Get.lazyPut(() => TagGenerationService());

  // Phase 3 — 初始化嵌入服务
  await _initEmbeddingService();

  runApp(const App());
}

/// 公共函数——供设置页切换嵌入方案后重新初始化。
Future<void> reinitEmbeddingService() async {
  // 释放旧的嵌入服务
  if (Get.isRegistered<EmbeddingService>()) {
    final old = Get.find<EmbeddingService>();
    try {
      await old.dispose();
    } catch (_) {
      // 释放失败不影响后续初始化。
    }
  }

  // 重新决策
  await _initEmbeddingService();
}

/// 初始化嵌入服务。
///
/// 策略（尊重用户偏好设置）：
/// 1. 若用户选择 "litert"：仅尝试 bundled 模型
/// 2. 若用户选择 "api"：仅尝试远程 API
/// 3. 若 "auto" 或未设置：优先 bundled，降级 API
Future<void> _initEmbeddingService() async {
  final box = GetStorage();
  final preferredBackend =
      box.read<String>(EmbeddingConstants.keyPreferredBackend) ??
          EmbeddingBackend.auto.value;

  final litertService = await _tryInitLiteRt(preferredBackend);
  if (litertService != null) {
    Get.put<EmbeddingService>(litertService);
    return;
  }

  final apiService = await _tryInitApi(preferredBackend);
  if (apiService != null) {
    Get.put<EmbeddingService>(apiService);
    return;
  }

  Get.put<EmbeddingService>(UnavailableEmbeddingService());
}

/// 尝试初始化 LiteRT 嵌入服务。
///
/// 返回 [LiteRtEmbeddingService] 实例，若不可用则返回 `null`。
Future<EmbeddingService?> _tryInitLiteRt(String preferredBackend) async {
  if (preferredBackend != EmbeddingBackend.auto.value &&
      preferredBackend != EmbeddingBackend.litert.value) {
    return null;
  }

  try {
    await FlutterGemma.initialize(
      embeddingBackends: const [LiteRtEmbeddingBackend()],
    );

    if (!FlutterGemma.hasActiveEmbedder()) {
      await FlutterGemma.installEmbedder()
          .modelFromAsset(
            'assets/models/embeddinggemma-300M_seq512_mixed-precision.tflite',
          )
          .tokenizerFromAsset('assets/models/sentencepiece.model')
          .install();
    }

    if (!FlutterGemma.hasActiveEmbedder()) {
      return null;
    }

    final service = LiteRtEmbeddingService();
    await service.initialize();

    return service.isAvailable ? service : null;
  } catch (_) {
    // LiteRT 初始化失败——auto 模式下降级，litert 强制模式返回 null。
    return null;
  }
}

/// 尝试初始化远程 API 嵌入服务。
///
/// 返回 [ApiEmbeddingService] 实例，若不可用则返回 `null`。
Future<EmbeddingService?> _tryInitApi(String preferredBackend) async {
  if (preferredBackend != EmbeddingBackend.auto.value &&
      preferredBackend != EmbeddingBackend.api.value) {
    return null;
  }

  try {
    final secureStorage = SecureStorageService();
    final apiKey = await secureStorage.getApiKey();

    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    final baseUrl = await secureStorage.getBaseUrl();
    final service = ApiEmbeddingService(
      apiKey: apiKey,
      baseUrl: baseUrl,
    );
    await service.initialize();

    return service.isAvailable ? service : null;
  } catch (_) {
    return null;
  }
}
