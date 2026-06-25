# SmartKnowledgeBase · 开发文档

**版本** v1.1 · **日期** 2026-06-24

---

## 1. 项目概述

SmartKnowledgeBase 是一款基于 Flutter 的移动端笔记应用，核心定位是"可检索的个人知识管理工具"。用户可以用 Markdown 编写笔记，由 LLM 自动或手动为笔记打标签，并借助本地文本嵌入模型实现语义相似度检索，将普通的关键词搜索升级为"语义搜索"。

应用的 AI 能力分为两层：嵌入层负责将文本转化为向量以支撑检索，由 `flutter_gemma_embeddings` 在设备端离线运行；标签层负责理解笔记内容并生成标签，调用外部 LLM REST API 实现。两层相互独立，互不阻塞。

---

## 2. 技术选型

| 层次 | 选型 | 说明 |
|---|---|---|
| UI 框架 | Flutter 3.x | 跨平台，优先适配 Android / iOS |
| 状态管理 | GetX | 响应式状态 + 路由 + 依赖注入三合一 |
| 路由 | GetX 路由 | 命名路由，无需 context |
| 依赖注入 | `Get.put` / `Get.lazyPut` | 替代 Riverpod Provider |
| 轻量 KV 存储 | GetStorage | 存储非敏感配置项（嵌入方案选择、自动打标签开关等） |
| 本地数据库 | drift (SQLite) | 类型安全 ORM，支持 FFI 模式 |
| Markdown 编辑 | 原生 TextField | 输入原始 Markdown 文本 |
| Markdown 预览 | flutter_markdown | 官方维护，稳定 |
| 文本嵌入（主方案） | flutter_gemma_embeddings | 设备端离线，LiteRT + dart:ffi |
| 向量存储 | flutter_gemma_rag_sqlite | 与嵌入包配套，开箱即用 |
| 文本嵌入（备用方案） | dio + 远程 Embedding API | 当主方案不可用时降级 |
| LLM 标签接口 | dio | 调用 OpenAI / DeepSeek / 通义等 REST API |
| 文件导出 | dart:io + path_provider + share_plus | 写文件 + 系统分享 |
| API Key 存储 | flutter_secure_storage | 加密存储敏感数据，不可用 GetStorage 替代 |

---

## 3. 项目目录结构

```
lib/
├── main.dart
├── app.dart                        # GetMaterialApp + GetPages 入口
│
├── core/
│   ├── database/
│   │   ├── app_database.dart       # drift 数据库定义
│   │   ├── tables/
│   │   │   ├── notes_table.dart
│   │   │   └── tags_table.dart
│   │   └── daos/
│   │       ├── notes_dao.dart
│   │       └── tags_dao.dart
│   ├── embedding/
│   │   ├── embedding_service.dart          # 抽象接口
│   │   ├── litert_embedding_service.dart   # 主方案实现
│   │   ├── api_embedding_service.dart      # 备用方案实现
│   │   └── unavailable_embedding_service.dart  # 不可用时的空实现
│   ├── llm/
│   │   └── tag_generation_service.dart     # LLM 标签调用
│   └── storage/
│       └── secure_storage_service.dart     # API Key 管理
│
├── routes/
│   └── app_routes.dart             # 路由名常量 + GetPages 列表
│
├── features/
│   ├── note_list/
│   │   ├── note_list_page.dart
│   │   └── note_list_controller.dart
│   ├── note_editor/
│   │   ├── note_editor_page.dart
│   │   └── note_editor_controller.dart
│   ├── note_detail/
│   │   ├── note_detail_page.dart
│   │   └── note_detail_controller.dart
│   ├── search/
│   │   ├── search_page.dart
│   │   └── search_controller.dart
│   └── settings/
│       ├── settings_page.dart
│       └── settings_controller.dart
│
└── shared/
    ├── widgets/                    # 公共组件
    └── utils/                      # 工具函数（导出、格式化等）
```

---

## 4. 数据库设计

数据库使用 drift 管理，包含两张核心表。

**notes 表**存储笔记的全部信息。`id` 为自增主键，`title` 和 `content` 分别存储标题和 Markdown 原文，`embedding` 字段将向量序列化为 `BLOB` 存储（在使用 `flutter_gemma_rag_sqlite` 时该字段由 RAG 包接管，此处作为备用字段保留），`embedding_backend` 记录该条笔记的向量是由哪个方案生成的（`litert` 或 `api`），方便将来混合场景下的一致性校验，`created_at` 和 `updated_at` 记录时间戳。

**tags 表**存储标签信息，通过 `note_id` 外键关联到 notes 表，`source` 字段区分标签来源为 `manual`（手动）还是 `llm`（自动生成）。

```dart
// core/database/tables/notes_table.dart
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get content => text()();
  BlobColumn get embedding => blob().nullable()();
  TextColumn get embeddingBackend => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// core/database/tables/tags_table.dart
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get noteId => integer().references(Notes, #id)();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get source => text().withDefault(const Constant('manual'))();
}
```

---

## 5. 嵌入方案设计

### 5.1 抽象接口

为了在主备方案之间平滑切换，先定义一个抽象接口，两种实现都遵循同一个契约，业务层通过 `Get.find<EmbeddingService>()` 获取实例，完全不感知底层是哪个方案。

```dart
// core/embedding/embedding_service.dart
abstract class EmbeddingService {
  bool get isAvailable;
  Future<List<double>> embed(String text);
  Future<void> dispose();
}
```

### 5.2 主方案：`flutter_gemma_embeddings`

在应用启动时完成初始化，之后通过 `LiteRtEmbeddingBackend` 进行推理，全程离线。

```dart
// core/embedding/litert_embedding_service.dart
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_embeddings/flutter_gemma_embeddings.dart';

class LiteRtEmbeddingService implements EmbeddingService {
  late final EmbeddingModel _model;

  @override
  bool get isAvailable => true;

  Future<void> initialize() async {
    await FlutterGemma.initialize(
      embeddingBackends: [LiteRtEmbeddingBackend()],
    );
    _model = await FlutterGemma.instance.createEmbeddingModel();
  }

  @override
  Future<List<double>> embed(String text) async {
    return await _model.embed(text);
  }

  @override
  Future<void> dispose() async {
    await _model.dispose();
  }
}
```

**模型文件分发策略**：Gecko / EmbeddingGemma `.tflite` 模型文件体积较大，不适合直接打包进 APK/IPA。推荐在应用首次启动时检测模型是否已下载，若未下载则展示一个进度页面从指定 URL 拉取并缓存到 `getApplicationDocumentsDirectory()`，后续启动直接读取本地缓存，无需重复下载。

### 5.3 备用方案：远程 Embedding API

当主方案初始化失败（例如设备不支持、模型下载失败）时，自动降级到此方案。以 OpenAI 兼容接口为例：

```dart
// core/embedding/api_embedding_service.dart
class ApiEmbeddingService implements EmbeddingService {
  final Dio _dio;
  final String _apiKey;
  final String _baseUrl;

  @override
  bool get isAvailable => true;

  ApiEmbeddingService({
    required String apiKey,
    String baseUrl = 'https://api.openai.com/v1',
  })  : _apiKey = apiKey,
        _baseUrl = baseUrl,
        _dio = Dio();

  @override
  Future<List<double>> embed(String text) async {
    final response = await _dio.post(
      '$_baseUrl/embeddings',
      options: Options(headers: {'Authorization': 'Bearer $_apiKey'}),
      data: {'input': text, 'model': 'text-embedding-3-small'},
    );
    return List<double>.from(response.data['data'][0]['embedding']);
  }

  @override
  Future<void> dispose() async {}
}
```

### 5.4 方案选择逻辑

在 `main.dart` 启动时由统一的初始化函数决策，结果通过 `Get.put` 注册到 GetX 的依赖容器中。优先尝试初始化 `LiteRtEmbeddingService`，若抛出异常则检查是否配置了 API Key，有则降级到 `ApiEmbeddingService`，否则注入 `UnavailableEmbeddingService` 并在 UI 上给出提示，搜索功能自动退化为关键词检索。设置页也提供手动切换开关，让用户可以主动选择使用哪个方案。

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await _initServices();
  runApp(const App());
}

Future<void> _initServices() async {
  // 数据库
  Get.put(AppDatabase());
  Get.lazyPut(() => TagGenerationService());

  // 嵌入方案决策
  try {
    final service = LiteRtEmbeddingService();
    await service.initialize();
    Get.put<EmbeddingService>(service);
  } catch (_) {
    final apiKey = await SecureStorageService().getApiKey();
    if (apiKey != null) {
      Get.put<EmbeddingService>(ApiEmbeddingService(apiKey: apiKey));
    } else {
      Get.put<EmbeddingService>(UnavailableEmbeddingService());
    }
  }
}
```

---

## 6. 路由设计

所有路由名集中在 `app_routes.dart` 管理，页面跳转使用 `Get.toNamed`，无需传递 `BuildContext`。

```dart
// routes/app_routes.dart
abstract class Routes {
  static const noteList   = '/';
  static const noteEditor = '/editor';
  static const noteDetail = '/detail/:id';
  static const search     = '/search';
  static const settings   = '/settings';
}

final appPages = [
  GetPage(name: Routes.noteList,   page: () => const NoteListPage()),
  GetPage(name: Routes.noteEditor, page: () => const NoteEditorPage()),
  GetPage(name: Routes.noteDetail, page: () => const NoteDetailPage()),
  GetPage(name: Routes.search,     page: () => const SearchPage()),
  GetPage(name: Routes.settings,   page: () => const SettingsPage()),
];

// app.dart
class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      initialRoute: Routes.noteList,
      getPages: appPages,
    );
  }
}
```

页面间跳转示例：`Get.toNamed(Routes.noteDetail, parameters: {'id': '${note.id}'})` 传递参数，`Get.back()` 返回上一页，`Get.offAllNamed(Routes.noteList)` 清栈跳转。

---

## 7. 状态管理

每个 Feature 对应一个 `GetxController`，通过 `Get.put` 在页面入口注入，页面使用 `Obx` 包裹需要响应式更新的部分。以笔记列表为例：

```dart
// features/note_list/note_list_controller.dart
class NoteListController extends GetxController {
  final _notes = <NoteModel>[].obs;
  final _isLoading = false.obs;

  List<NoteModel> get notes => _notes;
  bool get isLoading => _isLoading.value;

  @override
  void onInit() {
    super.onInit();
    loadNotes();
  }

  Future<void> loadNotes() async {
    _isLoading.value = true;
    _notes.value = await Get.find<NotesDao>().getAllNotes();
    _isLoading.value = false;
  }

  Future<void> deleteNote(int id) async {
    await Get.find<NotesDao>().deleteNote(id);
    _notes.removeWhere((n) => n.id == id);
    Get.snackbar('提示', '笔记已删除');
  }
}

// features/note_list/note_list_page.dart
class NoteListPage extends StatelessWidget {
  const NoteListPage({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NoteListController());
    return Obx(() => controller.isLoading
        ? const CircularProgressIndicator()
        : NoteListView(notes: controller.notes));
  }
}
```

非敏感的用户偏好设置（嵌入方案选择、是否自动打标签等）直接通过 `GetStorage` 读写，敏感的 API Key 仍然走 `flutter_secure_storage`。

---

## 8. LLM 自动打标签

标签生成调用外部 LLM 的 Chat Completions 接口，通过 Prompt 约束模型输出严格的 JSON 格式，避免解析失败。

```dart
// core/llm/tag_generation_service.dart
class TagGenerationService {
  static const _systemPrompt = '''
你是一个知识笔记标签生成助手。
根据用户提供的笔记内容，生成 3-6 个简洁的中文标签。
必须严格按照如下 JSON 格式返回，不要输出任何其他文字：
{"tags": ["标签1", "标签2", "标签3"]}
''';

  Future<List<String>> generateTags(String noteContent) async {
    final response = await _callLlmApi(noteContent);
    final json = jsonDecode(response);
    return List<String>.from(json['tags']);
  }
}
```

LLM 标签生成为异步操作，在笔记保存后由用户主动触发（点击"自动打标签"按钮），或在设置中开启"保存时自动生成标签"。生成过程中 UI 显示 loading 状态，失败时通过 `Get.snackbar` 给出可重试的提示，不阻塞笔记保存流程。

---

## 9. 功能模块说明

### 9.1 笔记编辑页

编辑页采用编辑与预览双模式 Tab 布局。编辑模式下使用原生 `TextField` 接收 Markdown 文本输入；预览模式下使用 `flutter_markdown` 渲染预览结果。保存时同时触发向量嵌入计算（异步，不阻塞保存响应），嵌入完成后更新数据库中的向量字段。

### 9.2 语义搜索页

用户在搜索框输入查询文本，应用对查询文本调用 `EmbeddingService.embed()` 得到查询向量，再通过 `flutter_gemma_rag_sqlite` 的 `searchSimilar()` 方法检索最相关的笔记列表并按相似度排序展示。在嵌入功能不可用时（`isAvailable == false`），自动退化为关键词全文搜索（SQLite `LIKE` 查询），并在搜索框下方显示"当前为关键词搜索模式"的提示条。

### 9.3 文件导出

导出功能直接将笔记的 `content` 字段写入 `.md` 文件，文件名为笔记标题（特殊字符替换为下划线），存放于 `getTemporaryDirectory()`，随后调用 `share_plus` 的 `ShareXFiles` 唤起系统分享菜单，用户可选择保存到文件系统或发送到其他应用。

### 9.4 设置页

设置页管理以下配置项：LLM API Key 和 Base URL（通过 `flutter_secure_storage` 加密存储）、LLM 模型名称、嵌入方案选择（自动 / 强制 LiteRT / 强制 API，通过 `GetStorage` 存储）、是否在保存时自动生成标签。修改嵌入方案后会重新执行 `_initServices` 中的决策逻辑并热替换 GetX 容器中的 `EmbeddingService` 实例。

---

## 10. 开发里程碑

| 阶段 | 内容 | 目标产出 |
|---|---|---|
| Phase 1 | 项目初始化、GetX 路由、数据库、笔记 CRUD | 可运行的基础笔记应用 |
| Phase 2 | Markdown 编辑 + 预览、文件导出、手动标签 | 功能完整的笔记应用 |
| Phase 3 | `flutter_gemma_embeddings` 集成、模型下载页、向量写入 | 本地嵌入可用 |
| Phase 4 | 语义搜索页、备用 API 嵌入方案、降级逻辑 | 检索功能完整 |
| Phase 5 | LLM 自动打标签、设置页、整体 UI 打磨 | 功能全部完成 |

建议 Phase 1~2 先跑通主流程，Phase 3 开始集成 `flutter_gemma_embeddings` 时单独开一个 demo 工程验证模型加载是否正常，确认可用后再合并进主项目，避免早期引入不确定因素干扰基础功能开发。

---

## 11. 关键依赖清单

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  get: ^4.6.6                       # 状态管理 + 路由 + DI
  get_storage: ^2.1.1               # 轻量 KV 存储（非敏感配置）
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.0
  flutter_markdown: ^0.7.0
  flutter_gemma: ^0.4.0
  flutter_gemma_embeddings: ^1.0.1
  flutter_gemma_rag_sqlite: latest
  dio: ^5.4.0
  flutter_secure_storage: ^9.0.0   # 仅用于 API Key 等敏感数据
  path_provider: ^2.1.0
  share_plus: ^9.0.0

dev_dependencies:
  drift_dev: ^2.18.0
  build_runner: ^2.4.0
```

> **注意**：`flutter_gemma_embeddings` 依赖 Dart Native Assets 特性，需在 Flutter SDK `>=3.22` 下启用。如构建时提示 Native Assets 未开启，执行 `flutter config --enable-native-assets` 后重新构建。Native Assets 在部分 CI 环境下需要额外配置，建议本地验证通过后再接入 CI 流水线。