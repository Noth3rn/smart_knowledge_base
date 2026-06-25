# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

SmartKnowledgeBase 是一款基于 Flutter 的个人知识管理移动应用。用户使用 Markdown 编写笔记，通过 LLM 自动/手动打标签，借助设备端 AI 模型实现语义相似度检索。核心卖点：将关键词搜索升级为**离线语义搜索**。

包名：`com.noth3rny.github.smart_knowledge_base` | 语言优先：中文

## 常用命令

```bash
# 获取依赖
flutter pub get

# 静态分析
flutter analyze

# 运行测试（单一 widget test，使用内存 SQLite）
flutter test

# 代码生成 — drift 数据库表变更后必须执行
dart run build_runner build --delete-conflicting-outputs

# 运行应用
flutter run

# 构建 APK
flutter build apk
```

**前置条件：** Flutter SDK ≥ 3.44（ForUI 要求），已启用 Native Assets（`flutter config --enable-native-assets`），Android NDK（供 LiteRT FFI 使用）。

## 技术栈

| 角色 | 选型 | 说明 |
|------|------|------|
| 框架 | Flutter 3.x (Dart SDK ^3.12.0) | 跨平台，优先 Android |
| UI 组件库 | ForUI 0.22.x | shadcn/ui 风格，平台无关，Lucide 图标 |
| 状态管理 / 路由 / DI | GetX 4.6.6 | 三合一：`GetxController` + `Get.toNamed()` + `Get.put()/Get.find()` |
| 非敏感 KV | GetStorage 2.1.1 | 嵌入后端偏好、自动标签开关 |
| 本地数据库 | drift ^2.18.0 (SQLite) | 类型安全 ORM，FFI 模式；代码生成需 `drift_dev` + `build_runner` |
| 设备端嵌入 | flutter_gemma ^1.0.0 + flutter_gemma_embeddings ^1.0.0 | LiteRT 运行时，768 维向量，512 token 序列 |
| 向量存储 | flutter_gemma_rag_qdrant ^1.0.0 | 与嵌入模型配套的本地向量存储 |
| 远程嵌入降级 | dio 5.4.0 | 调用 OpenAI 兼容 `/v1/embeddings` |
| Markdown 渲染 | flutter_markdown 0.7.0 | 笔记预览 |
| API Key 存储 | flutter_secure_storage 9.0.0 | 仅用于 LLM API Key / HuggingFace token |
| 文件导出 | share_plus 12.0.0 | 导出 `.md` 并唤起系统分享 |

## 核心架构

### 1. UI 框架：ForUI

应用使用 ForUI 作为 UI 组件库。`app.dart` 在 `GetMaterialApp.builder` 中注入 `FTheme`：

```dart
builder: (_, child) => FTheme(
  data: FThemes.neutral.dark.touch,
  child: FToaster(child: FTooltipGroup(child: child!)),
),
```

- **色彩：** 通过 `context.theme.colors.xxx` 访问（`primary`, `primaryForeground`, `secondary`, `secondaryForeground`, `foreground`, `mutedForeground`, `destructive`, `destructiveForeground`, `border` 等）
- **字体：** `context.theme.typography.xs3/xs2/xs/sm/md/lg/xl/xl2`…（12 级 Tailwind 比例，扁平结构，无 `body`/`display` 嵌套）
- **图标：** `FLucideIcons`（Lucide 图标集，如 `FLucideIcons.plus`, `FLucideIcons.search`, `FLucideIcons.trash`, `FLucideIcons.pencil`, `FLucideIcons.chevronRight`, `FLucideIcons.x`）
- **间距/圆角/常量：** `lib/theme/app_theme.dart` — `AppTheme.spacing/radius/edgeInsets/constants`

### 2. 页面架构模式

每个页面遵循统一模式——StatelessWidget + GetX Controller + ForUI 组件：

```dart
class XxxPage extends StatelessWidget {
  Widget build(BuildContext context) {
    final controller = Get.put(XxxController());
    final theme = context.theme;  // FThemeData
    return FScaffold(
      header: FHeader.nested(
        title: const Text('页面标题'),
        prefixes: [FHeaderAction.back(onPress: () => Get.back())],
        suffixes: [FHeaderAction(icon: ..., onPress: ...)],
      ),
      child: Obx(() {
        if (controller.isLoading) return const Center(child: FCircularProgress());
        // ... 列表用 FTileGroup.builder + FTile
        // ... 表单用 FTextField + FSwitch + FButton
      }),
    );
  }
}
```

**必备导入：**
```dart
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart' hide ContextExtensionss;  // 消除 context.theme 扩展冲突
```

**Material → ForUI 组件对照：**

| Material | ForUI |
|---|---|
| `Scaffold` + `AppBar` | `FScaffold(header: FHeader(...))` |
| `FScaffold(header: FHeader.nested(...))` | 带返回箭头的嵌套页 |
| `IconButton` | `FHeaderAction`（在 header 中）/ `FButton.icon(...)`（在 body 中）|
| `Card` + `ListTile` | `FTile`（在 `FTileGroup` 中）|
| `ListView.builder` | `FTileGroup.builder(tileBuilder: ...)` |
| `TextField` | `FTextField(control: .managed(...))` |
| `FilledButton` / `TextButton` | `FButton(variant: .primary/.outline/.ghost)` |
| `AlertDialog` + `showDialog` | `FDialog` + `showFDialog(...)`（**注意**：builder 内必须再包一层 `FTheme(data: context.theme, ...)` |
| `SwitchListTile` | `FSwitch(label:, description:)` |
| `SegmentedButton` | `FTabs` |
| `Divider` | `FDivider` |
| `Chip` | 自定义 `Container` + `BoxDecoration`（ForUI 无 Chip） |
| `CircularProgressIndicator` | `FCircularProgress` |
| `LinearProgressIndicator` | `FDeterminateProgress` |

### 3. 三层嵌入降级（最核心的架构决策）

所有嵌入通过抽象接口 `EmbeddingService` 多态切换，业务层只用 `Get.find<EmbeddingService>()`：

```
EmbeddingService (抽象)
  ├── LiteRtEmbeddingService    # 设备端离线（优先方案）
  ├── ApiEmbeddingService       # 远程 API 降级（需用户配置 API Key）
  └── UnavailableEmbeddingService  # 不可用占位（搜索自动退化为 SQL LIKE）
```

`main.dart` 中 `_initEmbeddingService()` 按优选顺序调用 `_tryInitLiteRt()` → `_tryInitApi()`（卫语句模式，每个方法返回 `EmbeddingService?`）。设置页切换后端调用 `reinitEmbeddingService()` 热替换 DI 容器中的实例。

### 4. GetX 贯穿全栈

- **DI：** `main()` 中 `Get.put(AppDatabase())` 注册数据库单例，`Get.lazyPut(() => TagGenerationService())` 延迟初始化 LLM 标签服务，嵌入服务通过 `Get.put<EmbeddingService>(instance)` 注册
- **路由：** `app_routes.dart` 中 `Routes` 抽象类集中定义路由常量 + `Routes.paramId`，`appPages` 列表管理 `GetPage`
- **状态：** 每个 Feature 用一个 `GetxController` + `.obs` 响应式字段，Widget 用 `Obx(() => ...)` 包裹订阅部分

### 5. 数据库（drift）

两张核心表在 `lib/core/database/tables/` （part of `AppDatabase`）：

- **notes：** id (自增 PK), title (1-200), content (文本), embedding (BLOB, 可为 null), embedding_backend (可为 null), created_at, updated_at
- **tags：** id (自增 PK), note_id (FK → notes.id), name (1-50), source (默认 "manual")

DAOs 为 `AppDatabase` 的 extension（`notes_dao.dart`, `tags_dao.dart`）。删除笔记手动级联删标签。**表结构变更后必须运行 `dart run build_runner build --delete-conflicting-outputs`。**

### 6. 搜索流程

```
用户输入 → 300ms 防抖
  ├── EmbeddingService 可用 → embed(查询文本) → 从 DB 加载所有有 embedding 的笔记
  │     → 对每条笔记计算余弦相似度 → 阈值 > 0.2 → 按相似度降序 → 取 Top 20
  └── 不可用 → SQL LIKE '%关键词%' 搜索 title 和 content → 显示"当前为关键词搜索模式"
```

### 7. Fire-and-forget 嵌入与标签

笔记保存后异步触发 `_computeEmbedding()` 和 `_autoGenerateTags()`，不阻塞保存返回。嵌入失败静默处理；标签生成失败通过 `Get.snackbar` 通知。

### 8. 模型文件分发

嵌入模型文件（~171MB `.tflite` + ~4.5MB SentencePiece `.model`）不打包进 APK。应用内 `ModelDownloadPage` 引导用户下载到 `getApplicationDocumentsDirectory()`。模型 URL 等常量在 `EmbeddingConstants` 中定义。

## 路由表

| 路由 | 页面 | 说明 |
|------|------|------|
| `/` | NoteListPage | 首页笔记列表（右上角 + 新建） |
| `/editor` | NoteEditorPage | 新建/编辑笔记，Markdown 编辑+预览双模式 |
| `/detail` | NoteDetailPage | 笔记详情，Markdown 渲染，标签展示，导出/删除 |
| `/search` | SearchPage | 语义搜索（优先）或关键词搜索（降级） |
| `/settings` | SettingsPage | LLM API 配置、嵌入后端选择（FTabs）、自动标签开关 |
| `/model-download` | ModelDownloadPage | 下载嵌入模型，下载中阻止返回（PopScope） |

**路由参数：** 笔记 ID 通过 `Routes.paramId`（即 `'id'`）传递，如 `Get.toNamed(Routes.noteDetail, parameters: {Routes.paramId: '$id'})`。

## 代码风格要点

需遵循 `docs/CODE_STYLE_GUIDE.md`，核心规则：

- **禁止 `var`**，全部用 `final` 或显式类型
- **命名参数构造**，禁止位置参数
- **尾随逗号**必须加（多行参数列表）
- **枚举独立成文件** → `lib/core/enum/`
- **公开 API 必须写 `///` dartdoc**
- **常量统一管理**：全局存储键/后端名 → `EmbeddingConstants`，UI 常量（阈值、topK、间距等） → `AppTheme.constants`
- **标签来源**用 `TagSource.llm.value` / `TagSource.manual.value`，不硬编码字符串
- **嵌入后端**用 `EmbeddingBackend.auto/litert/api.value`，不硬编码字符串
- **async/await** 优先，禁止 `.then()` 链式调用
- **能用 `const` 就用 `const`**

## 测试注意事项

- 测试文件 `test/widget_test.dart` 使用 `NativeDatabase.memory()` + `AppDatabase.forTesting(...)`
- `setUp` 中 `Get.put()` 注册，`tearDown` 中 `Get.reset()` 清理
- 需要 `FTheme` 上下文的 Widget 测试，使用真实的 `App` 组件（其 builder 已注入 FTheme）
- 新增测试如需数据库访问，同样使用 `AppDatabase.forTesting(NativeDatabase.memory())`
