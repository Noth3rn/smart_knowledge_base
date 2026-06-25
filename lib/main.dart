import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_embeddings/flutter_gemma_embeddings.dart';
import 'package:get/get.dart' hide Value;
import 'package:get_storage/get_storage.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/embedding/embedding_constants.dart';
import 'core/embedding/embedding_service.dart';
import 'core/embedding/api_embedding_service.dart';
import 'core/embedding/litert_embedding_service.dart';
import 'core/embedding/unavailable_embedding_service.dart';
import 'core/enum/embedding_backend.dart';
import 'core/enum/tag_source.dart';
import 'core/llm/tag_generation_service.dart';
import 'core/storage/secure_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  Get.put(AppDatabase());

  Get.lazyPut(() => TagGenerationService());

  await _initEmbeddingService();

  await _insertWelcomeNotes();

  runApp(const App());
}

/// 首次启动时插入两份欢迎笔记（使用指南 + Markdown 速查）。
Future<void> _insertWelcomeNotes() async {
  final box = GetStorage();
  if (box.read<bool>(EmbeddingConstants.keyWelcomeNotesInserted) == true) {
    return;
  }

  final db = Get.find<AppDatabase>();

  final guideNoteId = await db.insertNote(NotesCompanion(
    title: Value('SmartKnowledgeBase 使用指南'),
    content: Value(_welcomeGuideContent),
    updatedAt: Value(DateTime.now()),
  ));
  await db.addTags(guideNoteId, ['使用说明'], source: TagSource.manual.value);

  final mdNoteId = await db.insertNote(NotesCompanion(
    title: Value('Markdown 语法速查'),
    content: Value(_markdownGuideContent),
    updatedAt: Value(DateTime.now()),
  ));
  await db.addTags(mdNoteId, ['使用说明'], source: TagSource.manual.value);

  await box.write(EmbeddingConstants.keyWelcomeNotesInserted, true);
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

const String _welcomeGuideContent = '''## 欢迎使用 SmartKnowledgeBase

SmartKnowledgeBase 是一款基于设备端 AI 的个人知识管理工具。
以下是最常用的功能操作指引。

### 创建笔记

点击首页右下角的 **+** 按钮进入编辑页。输入标题和正文后，点击右上角 **✓** 保存。

### Markdown 编辑与预览

编辑器支持 Markdown 语法。点击右上角的 **眼睛图标** 可切换实时预览，确认排版效果。

### 标签管理

每篇笔记都可以添加标签进行分类。你可以：
- 点击标签行的 **+** 按钮手动添加
- 点击 **✨ 按钮** 让 AI 根据笔记内容自动生成标签
- 点击已有标签可将其删除

AI 标签功能需要在设置中配置 LLM API Key。

### 语义搜索

点击首页右上角 **🔍** 进入搜索。输入关键词后，应用优先使用设备端 AI 模型进行语义搜索——即使关键词不完全匹配，也能找到语义相关的笔记。

搜索页支持按时间和标签筛选结果。

### 离线优先

设备端嵌入模型运行完全在本地完成，无需网络连接。首次使用需下载模型（约 170 MB），之后即可离线使用语义搜索。

### 设置

在设置页可以配置：
- **LLM API**：用于 AI 自动标签和远程嵌入降级
- **嵌入方案**：选择 LiteRT（本地）或远程 API
- **自动标签**：开启后保存笔记时自动调用 AI 打标签
''';

const String _markdownGuideContent = '''## Markdown 基础语法

### 标题

```
# 一级标题
## 二级标题
### 三级标题
#### 四级标题
```

### 文字样式

```
**粗体文字**
*斜体文字*
~~删除线~~
```

### 列表

无序列表：
```
- 项目一
- 项目二
  - 子项目
```

有序列表：
```
1. 第一步
2. 第二步
3. 第三步
```

### 引用

```
> 这是一段引用文字
> 可以多行
```

### 代码

行内代码：`print("hello")`

代码块：
````
```dart
void main() {
  print("Hello, World!");
}
```
````

### 链接与图片

```
[链接文字](https://example.com)
![图片描述](https://example.com/image.png)
```

### 分隔线

```
---
```

### 表格

```
| 列1 | 列2 | 列3 |
|-----|-----|-----|
| A   | B   | C   |
| D   | E   | F   |
```

### 任务列表

```
- [ ] 待办事项
- [x] 已完成事项
```
''';
