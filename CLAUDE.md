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
| 本地数据库 | drift 2.34.0 (SQLite) | 类型安全 ORM，FFI 模式；代码生成需 `drift_dev` + `build_runner` |
| 设备端嵌入 | flutter_gemma 1.1.1 + flutter_gemma_embeddings 1.0.0 | LiteRT 运行时，768 维向量，512 token 序列 |
| 远程嵌入降级 | dio 5.4.0 | 调用 OpenAI 兼容 `/v1/embeddings` |
| Markdown 渲染 | flutter_markdown 0.7.0 | 笔记预览 |
| API Key 存储 | flutter_secure_storage 9.0.0 | 仅用于 LLM API Key / HuggingFace token |
| 文件导出 | share_plus 12.0.0 | 导出 `.md` 并唤起系统分享 |

## 核心架构

### 1. UI 框架：ForUI

应用使用 ForUI 作为 UI 组件库，不再依赖 Material Design。`app.dart` 在 `GetMaterialApp.builder` 中注入 `FTheme`：

```dart
builder: (_, child) => FTheme(
  data: FThemes.neutral.dark.touch,
  child: FToaster(child: FTooltipGroup(child: child!)),
),
```

- **颜色：** 通过 `context.theme.colors.xxx` 访问（`primary`, `secondary`, `foreground`, `mutedForeground`, `destructive` 等）
- **字体：** `context.theme.typography.xs/sm/md/lg/xl/xl2`…（12 级 Tailwind 比例，扁平结构）
- **图标：** `FLucideIcons`（Lucide 图标集，替代 Material `Icons`）
- **间距/圆角：** 项目专属常量在 `lib/theme/app_theme.dart`（`AppTheme.spacing/radius/edgeInsets/constants`）

### 2. 页面架构模式

每个页面遵循统一模式：
```dart
class XxxPage extends StatelessWidget {
  Widget build(BuildContext context) {
    final controller = Get.put(XxxController());
    final theme = context.theme;  // FThemeData
    return FScaffold(
      header: FHeader.nested(title: ..., prefixes: [FHeaderAction.back(...)], suffixes: [...]),
      child: Obx(() { ... }),
    );
  }
}
```

页面文件必须导入 `package:flutter/widgets.dart` + `package:forui/forui.dart` + `package:get/get.dart' hide ContextExtensionss`（后者消除 ForUI 与 GetX 的 `context.theme` 扩展冲突）。

### 3. 三层嵌入降级（最核心的架构决策）

所有嵌入通过抽象接口 `EmbeddingService` 多态切换，业务层只用 `Get.find<EmbeddingService>()`：

```
EmbeddingService (抽象)
  ├── LiteRtEmbeddingService    # 设备端离线（优先方案）
  ├── ApiEmbeddingService       # 远程 API 降级（需用户配置 API Key）
  └── UnavailableEmbeddingService  # 不可用占位（搜索自动退化为 SQL LIKE）
```

应用启动时 `main.dart` → `_initEmbeddingService()` 尝试 `_tryInitLiteRt()` → `_tryInitApi()`（卫语句模式，无深层嵌套）。运行时可通过设置页切换后端，调用 `reinitEmbeddingService()` 热替换 DI 容器中的实例。

### 4. GetX 贯穿全栈

- **DI：** 服务在 `main()` 中通过 `Get.put()` 注册（数据库单例、嵌入服务），LLM 标签服务通过 `Get.lazyPut()` 延迟初始化
- **路由：** `app_routes.dart` 定义命名路由常量，`GetPage` 列表集中管理，跳转使用 `Get.toNamed()` 无需 `BuildContext`
- **状态：** 每个 Feature 用一个 `GetxController` + `.obs` 响应式字段，Widget 用 `Obx(() => ...)` 包裹订阅部分

### 5. 数据库（drift）

两张核心表在 `lib/core/database/tables/` 中定义：

- **notes：** id (自增 PK), title (1-200 字), content (Markdown 原文), embedding (BLOB, 可为 null), embedding_backend (可为 null, "litert" 或 "api"), created_at, updated_at
- **tags：** id (自增 PK), note_id (FK → notes.id), name (1-50 字), source (默认 "manual", 可为 "llm")

DAOs 在 `lib/core/database/daos/` 中。删除笔记时手动级联删除标签（由 DAO 处理，非 SQL ON DELETE CASCADE）。表结构变更后必须运行 `dart run build_runner build --delete-conflicting-outputs` 重新生成 `app_database.g.dart`。

### 6. 搜索流程

```
用户输入 → 300ms 防抖
  ├── EmbeddingService 可用 → embed(查询文本) → 从 DB 加载所有有 embedding 的笔记
  │     → 对每条笔记计算余弦相似度 → 阈值 > 0.2 → 按相似度降序 → 取 Top 20
  └── 不可用 → SQL LIKE '%关键词%' 搜索 title 和 content → 显示"当前为关键词搜索模式"
```

### 7. Fire-and-forget 嵌入与标签

笔记保存时，嵌入计算和 LLM 标签生成不阻塞保存响应——它们以 fire-and-forget 方式触发。嵌入失败静默处理（向量字段保持 null），标签生成失败通过 `Get.snackbar` 通知可重试。

### 8. 模型文件分发

嵌入模型文件（~171MB `.tflite` + ~4.5MB SentencePiece `.model`）不打包进 APK。应用内提供 `ModelDownloadPage`（路由 `/model-download`）引导用户下载并缓存到 `getApplicationDocumentsDirectory()`。

## 路由表

| 路由 | 页面 | 说明 |
|------|------|------|
| `/` | NoteListPage | 首页笔记列表 |
| `/editor` | NoteEditorPage | 新建/编辑笔记 |
| `/detail` | NoteDetailPage | 笔记详情 + 预览 + 导出（参数 `Routes.paramId`） |
| `/search` | SearchPage | 语义/关键词搜索 |
| `/settings` | SettingsPage | LLM 配置、嵌入后端切换 |
| `/model-download` | ModelDownloadPage | 下载嵌入模型，下载中阻止返回 |

## 代码风格要点

- **禁止 `var`**，全部用 `final` 或显式类型
- **命名参数构造**，禁止位置参数
- **尾随逗号**必须加
- **枚举独立成文件**（`lib/core/enum/`）
- **公开 API 必须写 `///` dartdoc**
- **常量统一管理**：全局键/后端名 → `EmbeddingConstants`，UI 常量 → `AppTheme.constants`
- **标签来源**用 `TagSource` 枚举值，不要硬编码 `'manual'`/`'llm'`
- **嵌入后端**用 `EmbeddingBackend` 枚举值，不要硬编码 `'auto'`/`'litert'`/`'api'`

## 测试注意事项

- 唯一测试 `test/widget_test.dart` 使用 `NativeDatabase.memory()` 创建内存数据库，避免文件系统依赖
- 在 `setUp` 中用 `Get.put()` 注册测试用数据库，`tearDown` 中 `Get.reset()` 清理
- 测试 Widget 需要包裹 `FTheme`（ForUI 主题上下文）
- 新增测试如需数据库访问，同样使用 `AppDatabase.forTesting(NativeDatabase.memory())`
