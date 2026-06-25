# MaximumJoy-App 代码风格指导书

> 本指导书基于仓库 `MaximumJoy-App` 的 Noth3rn / 93410 提交历史与代码样本提取，
> 供 LLM 在为此项目生成 / 修改代码时参考。请严格遵守。

---

## 一、项目结构

```
lib/
├── constants/        # 常量（URL、缓存键、环境变量等）
├── controller/       # GetX 控制器（按功能分文件夹）
├── ext/              # Dart 扩展方法
├── pages/            # 页面级 Widget（按功能分文件夹）
├── service/          # 业务服务层（API、缓存、合规等）
├── ui/
│   ├── component/    # 可复用组件（common/、dialog/、dev/ 等子目录）
│   ├── enum/         # 与 UI 相关的枚举（独立文件）
│   └── style/        # 主题、常量、样式
├── utils/            # 工具函数
└── routes/           # 路由定义
```

**规则：**
- 新功能优先放入 `pages/` 下对应子目录，不要全部塞在同一个目录里
- 枚举值务必独立成文件，放在 `ui/enum/` 或对应模块的 `enum/` 子目录
- 组件按用途分文件夹：`common/` 通用组件、`dialog/` 弹窗组件、`dev/` 调试组件

---

## 二、命名规范

### 文件命名：`snake_case`
```
✅ 正确：location_controller.dart、api_constants.dart、app_slidable.dart
❌ 错误：LocationController.dart、APIConstants.dart
```

### 类名：`PascalCase`
```
✅ 正确：class LocationController、class AppSlidable
❌ 错误：class location_controller、class appSlidable
```

### 方法 / 函数：`camelCase`
```
✅ 正确：void locationInit()、Future<Data?> getData()
❌ 错误：void LocationInit()、void location_init()
```

### 私有成员：`_` 前缀
```dart
✅ 正确：final AppLocationData _locationData;
✅ 正确：static IDataCacheService get _cacheService => Get.find();
```

### 常量：`camelCase`（禁止全大写）
```dart
✅ 正确：static final defaultLocation = ...;
❌ 错误：static final DEFAULT_LOCATION = ...;
```

### 枚举值：`lowercase`
```dart
✅ 正确：enum Type { behind, scroll, drawer }
❌ 错误：enum Type { Behind, SCROLL, Drawer }
```

---

## 三、代码格式

### 基础格式
- 缩进：**2 空格**（标准 Dart format）
- 尾随逗号：**多行参数列表必须加尾随逗号**，这是最严格的规则之一

```dart
// ✅ 正确
Widget build(BuildContext context) {
  return Column(
    children: [
      Text('Hello'),
      Text('World'),
    ],
  );
}

// ❌ 错误：缺少尾随逗号
Widget build(BuildContext context) {
  return Column(
    children: [
      Text('Hello'),
      Text('World')
    ]
  );
}
```

### 构造函数参数风格
- **全部使用命名参数**，禁用位置参数构造
- **必须加 `required`**（除非有默认值）
- **默认值友好**：能设默认值的都设上

```dart
// ✅ 正确
class AppSlidable extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final int flex;

  const AppSlidable({
    super.key,
    required this.child,
    this.enabled = true,
    this.flex = 1,
  });
}
```

### 修饰符使用
- **能用 `const` 就用 `const`**：构造函数加 `const`，不变的 widget 加 `const`
- **`final` > `var`**：禁止使用 `var`，一律用 `final` 或具体类型

```dart
// ✅ 正确
final String name;
final int count = 0;

// ❌ 错误
var name = 'hello';
```

---

## 四、架构模式

### 状态管理：GetX
- Controller 继承 `GetxController`
- 服务依赖通过 `Get.find<ServiceType>()` 注入
- 静态 getter 封装服务访问

```dart
class LocationController extends GetxController {
  static IDataCacheService get _cacheService => Get.find<IDataCacheService>();
  static ComplianceService get _complianceService => Get.find<ComplianceService>();

  @override
  void onInit() {
    super.onInit();
    locationInit();
  }
}
```

### 服务层封装
- 外部依赖（API、缓存、位置、合规等）都抽成 Service 类
- Controller 不直接操作底层 API，通过 Service 间接访问
- Service 通过 GetX DI 管理生命周期

### Widget 封装模式
- 第三方 UI 库要包一层自己的壳，方便统一维护和替换
- 类名加 `App` 前缀（如 `AppSlidable`、`AppNetworkImage`）

```dart
/// 对 [Slidable] 的封装组件，简化滑动操作面板的构建。
class AppSlidable extends StatefulWidget {
  // ... 提供自己的参数接口，不暴露第三方库细节
}
```

---

## 五、文档与注释

### 公开 API 必须写 dartdoc（`///`）
- **所有 public 类、方法、属性都要有 `///` 注释**
- 重要的组件要附上 **使用示例代码**

```dart
/// [AppSlidable] 的操作面板子项，用于配置单个操作按钮的外观和行为。
///
/// 每个 [AppSlidablePaneItem] 代表滑动面板中的一个操作按钮，
/// 可自定义图标、标题、背景色、点击回调和 flex 占比。
///
/// 使用示例：
/// ```dart
/// AppSlidable(
///   startPanel: [
///     AppSlidablePaneItem(
///       title: '收藏',
///       backgroundColor: Colors.orange,
///       onTap: () => print('收藏'),
///     ),
///   ],
///   child: YourListTile(),
/// )
/// ```
class AppSlidablePaneItem { ... }
```

### 内部逻辑少写行内注释
- 好的命名和结构应当让代码自解释
- 不需要在每行代码旁边写注释

---

## 六、异步与错误处理

### Async/Await 优先
- **全部使用 async/await 模式**，禁止 `.then()` 链式调用
- 异步方法返回类型请明确指定（`Future<T>`），不要省略

```dart
// ✅ 正确
Future<AppLocationData?> getLocation() async {
  final pos = await getCoordinate();
  return pos;
}

// ❌ 错误
Future getLocation() {
  return getCoordinate().then((pos) => pos);
}
```

### Null Safety 规范
- 可为空的返回值显式加 `?`
- 善用 `??` 提供默认值
- 善用 `?.` 安全调用

---

## 七、提交信息规范

### 格式
- 一行标题，简明扼要
- 中英文均可（这个项目双语混用）
- 作用域前缀可选，但推荐（如 `Sunnylive: xxx`、`chore(ios): xxx`）

### 示例
```
✅ import fix
✅ rename
✅ to eng
✅ Sunnylive: UserProfilePage fix
✅ 不老的搜索框
✅ WIP
❌ 很长很啰嗦的提交信息描述了一堆事情根本看不完
```

---

## 八、禁止事项（LLM 特别注意）

| 禁止行为 | 说明 |
|---------|------|
| ❌ 不要用 `var` | 全部用 `final` 或显式类型 |
| ❌ 不要用位置参数构造 widget | 必须命名参数 |
| ❌ 不要省略 `required` | 除非参数有默认值 |
| ❌ 不要用 `.then()` | 用 async/await |
| ❌ 不要用全大写常量名 | 用 camelCase |
| ❌ 不要把枚举和主类写在一个文件里 | 枚举独立成文件 |
| ❌ 不要把文件直接放 `lib/` 下 | 按目录结构放好 |
| ❌ 不要省略 `///` 注释 | 所有公开 API 都要写 |
| ❌ 不要在行内写过多注释 | 代码本身要清晰 |

---

## 九、代码示例（模板）

### 新建一个 Controller
```dart
import 'package:get/get.dart';

import '../../service/some/some_service.dart';

/// 示例控制器，管理某某功能的状态。
class ExampleController extends GetxController {
  static SomeService get _someService => Get.find<SomeService>();

  String _data = '';
  String get data => _data;

  @override
  void onInit() {
    super.onInit();
    _initData();
  }

  Future<void> _initData() async {
    final result = await _someService.fetchData();
    _data = result;
    update();
  }
}
```

### 新建一个封装组件
```dart
import 'package:flutter/material.dart';

/// [SomeWidget] 的封装组件。
///
/// 使用示例：
/// ```dart
/// AppExampleWidget(
///   title: '示例',
///   onTap: () => print('tapped'),
/// )
/// ```
class AppExampleWidget extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const AppExampleWidget({
    super.key,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(title),
    );
  }
}
```

---

> 本指导书由从雨根据仓库实际代码分析整理，供 LLM 参考遵守。
