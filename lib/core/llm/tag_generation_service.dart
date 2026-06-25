import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../storage/secure_storage_service.dart';

/// LLM 标签生成服务——调用 OpenAI 兼容 Chat Completions API，
/// 根据笔记内容生成 3-6 个简洁的中文标签。
///
/// 需要在 main.dart 中通过 `Get.lazyPut(() => TagGenerationService())` 注册。
class TagGenerationService extends GetxController {
  static const _systemPrompt = '''你是一个知识笔记标签生成助手。
根据用户提供的笔记标题和内容，生成 3-6 个简洁的中文标签。
标签应当概括笔记的核心主题、关键词或领域。

必须严格按照如下 JSON 格式返回，不要输出任何其他文字：
{"tags": ["标签1", "标签2", "标签3"]}''';

  final _secureStorage = SecureStorageService();
  final _box = GetStorage();

  /// 是否已配置 API Key（决定服务是否可用）。
  Future<bool> get isAvailable async {
    final key = await _secureStorage.getApiKey();
    return key != null && key.isNotEmpty;
  }

  /// 根据笔记标题和内容生成标签。
  ///
  /// 返回标签名列表（3-6 个），失败时抛出异常。
  Future<List<String>> generateTags(String title, String content) async {
    final apiKey = await _secureStorage.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key 未配置，请在设置中填写。');
    }

    final baseUrl =
        await _secureStorage.getBaseUrl() ?? 'https://api.deepseek.com/v1';
    final modelName = _box.read<String>('llmModelName') ?? 'deepseek-v4-flash';

    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
    ));

    try {
      final userMessage = '标题：$title\n\n内容：$content';

      final response = await dio.post(
        '/chat/completions',
        data: {
          'model': modelName,
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            {'role': 'user', 'content': userMessage},
          ],
          'temperature': 0.3,
          'max_tokens': 200,
        },
      );

      final choice = (response.data['choices'] as List).first;
      final rawText = choice['message']['content'] as String;

      // 清理可能的 markdown 代码块包裹
      var jsonStr = rawText.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceAll(RegExp(r'```\w*\n?'), '').trim();
      }

      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final tags = (parsed['tags'] as List).cast<String>();

      // 过滤：去重、去空、限制长度
      final cleaned = tags
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty && t.length <= 50)
          .toSet()
          .toList();

      if (cleaned.isEmpty) {
        throw Exception('LLM 未生成有效标签。');
      }

      return cleaned.length > 6 ? cleaned.sublist(0, 6) : cleaned;
    } on FormatException {
      throw Exception('LLM 返回格式异常，请重试。');
    } on DioException catch (e) {
      final message = switch (e.response?.statusCode) {
        401 => 'API Key 无效 (401)。',
        429 => '请求过于频繁，请稍后重试 (429)。',
        503 => '服务暂时不可用 (503)。',
        _ => '网络错误：${e.message}',
      };
      throw Exception(message);
    }
  }
}
