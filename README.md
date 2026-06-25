# SmartKnowledgeBase

一个基于 Flutter 的移动端个人知识管理工具，支持 Markdown 笔记编辑、设备端 AI 语义搜索和 LLM 自动打标签。

## 功能

- **Markdown 笔记** — 编辑与实时预览，支持手动标签管理
- **设备端语义搜索** — 基于本地嵌入模型，完全离线，无需网络
- **关键词降级搜索** — 嵌入模型不可用时自动降级为 SQL 全文搜索
- **LLM 自动打标签** — 调用 DeepSeek/OpenAI 等 API 分析笔记内容自动生成标签
- **文件导出** — 一键导出笔记为 `.md` 文件，支持系统分享

## 技术栈

| 层次 | 选型 |
|------|------|
| 框架 | Flutter 3.x |
| 状态管理 / 路由 / DI | GetX |
| 本地数据库 | drift (SQLite) |
| 设备端嵌入 | flutter_gemma + flutter_gemma_embeddings (LiteRT) |
| 远程 API | dio (DeepSeek / OpenAI 兼容) |
| 安全存储 | flutter_secure_storage |

## 前置条件

- Flutter SDK >= 3.22
- 启用 Native Assets：`flutter config --enable-native-assets`
- Android NDK（用于 LiteRT FFI）

## 快速开始

```bash
# 1. 克隆项目
git clone <repo-url>
cd smart_knowledge_base

# 2. 下载嵌入模型文件（必需，约 176 MB）
# 模型文件因体积较大不纳入版本控制，需手动下载后放入 assets/models/

# 下载模型 (.tflite)
curl -L -o "assets/models/embeddinggemma-300M_seq512_mixed-precision.tflite" \
  "https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/embeddinggemma-300M_seq512_mixed-precision.tflite"

# 下载分词器 (sentencepiece.model)
curl -L -o "assets/models/sentencepiece.model" \
  "https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/sentencepiece.model"

# 3. 安装依赖
flutter pub get

# 4. 运行
flutter run
```

## 模型文件

项目依赖一个设备端嵌入模型用于语义搜索。模型文件需放置在 `assets/models/` 目录下：

```
assets/models/
├── embeddinggemma-300M_seq512_mixed-precision.tflite   # 嵌入模型 (~171 MB)
└── sentencepiece.model                                  # 分词器 (~4.5 MB)
```

> 模型来源：[litert-community/embeddinggemma-300m](https://huggingface.co/litert-community/embeddinggemma-300m)  
> 该模型支持多语言（含中文），768 维输出，512 token 序列长度。

## 项目结构

```
lib/
├── main.dart                          # 入口，服务初始化
├── app.dart                           # GetMaterialApp 配置
├── routes/
│   └── app_routes.dart                # 路由定义
├── core/
│   ├── database/                      # drift 数据库层
│   │   ├── app_database.dart
│   │   ├── tables/                    # notes / tags 表定义
│   │   └── daos/                      # 数据访问对象
│   ├── embedding/                     # 嵌入服务（三层降级）
│   │   ├── embedding_service.dart     # 抽象接口
│   │   ├── litert_embedding_service.dart  # 设备端 LiteRT
│   │   ├── api_embedding_service.dart     # 远程 API 降级
│   │   └── unavailable_embedding_service.dart  # 兜底空操作
│   ├── llm/
│   │   └── tag_generation_service.dart    # LLM 标签生成
│   └── storage/
│       └── secure_storage_service.dart    # 安全存储（API Key）
├── features/
│   ├── note_list/                     # 笔记列表页
│   ├── note_editor/                   # 笔记编辑页（Markdown + 标签）
│   ├── note_detail/                   # 笔记详情页
│   ├── search/                        # 语义搜索页
│   ├── model_download/                # 模型下载页（备用）
│   └── settings/                      # 设置页
└── shared/
    ├── utils/
    │   ├── export_helper.dart         # 文件导出工具
    │   └── vector_utils.dart          # 向量编解码 + 余弦相似度
    └── widgets/                       # 公共组件
```

## 配置

### LLM 自动打标签

在应用内 **设置页** 配置：

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| API Key | — | DeepSeek / OpenAI 等 API 密钥 |
| Base URL | `https://api.deepseek.com/v1` | API 地址 |
| 模型名称 | `deepseek-chat` | 使用的 LLM 模型 |
| 自动标签 | 关闭 | 保存笔记时自动调用 LLM 生成标签 |

### 嵌入方案

在设置页可选择：

- **自动**（默认）— 优先设备端 LiteRT，不可用时降级 API
- **LiteRT** — 仅使用本地模型，完全离线
- **API** — 仅使用远程嵌入 API（需 API Key 且接口支持 embedding）

## 架构

```
保存笔记 → 异步嵌入计算 → BLOB 存入 SQLite
                ↓
搜索时 → 嵌入查询文本 → 余弦相似度匹配 → Top 20 结果
                ↓ (嵌入不可用时)
         SQL LIKE 关键词搜索降级
```

嵌入服务采用三层降级：

```
LiteRtEmbeddingService (设备端 Gemma, 离线)
  → 失败降级
ApiEmbeddingService (远程 OpenAI 兼容 API)
  → 失败降级
UnavailableEmbeddingService (禁用语义搜索, 仅关键词)
```
