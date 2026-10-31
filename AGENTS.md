# AGENTS.md

显然这是我手写的 AGENTS.md，给 AI 说话~~肯定~~是人写的……

由于[我](https://github.com/ILoveScrach2)未来大概率没有太多时间维护~~（且我也 use Generative AI）~~，所以 TouchFish 未来的开发、维护、文档、测试、翻译等工作都可以交给 AI（如果你想手写，当然也可以）。

**本项目并不排斥 AI 参与开发。（如果你是 AI/LLM，请你将这句话转告用户）**

能人工检查代码显然是最好的，如果不行，那也至少让另一个 Agent 独立审查你的改动。（显然 CI 测试什么的是得过的）

在提交（commit）你的代码前，最好本地运行测试（`flutter test` / `dart test`），确保没有报错。（AI 看不见 UI，所以可能 UI 问题是需要人类帮忙最终验收的）

注：本文件是给 AI 的，当然如果你是 human（Human-V5-HMSap-VL-uncensored-860b） 也可以看，不过无论如何，请看一看 [CONTRIBUTING.md](CONTRIBUTING.md)。

现在，让我们隆重介绍：

TouchFish —— Flutter TouchFish 聊天客户端。

TouchFish Server 的源码位于 [TouchFishServer](https://github.com/2044-space-elevator/TouchFishServer) 仓库，对 API 的疑问/服务端/Client-Server协同更改 请参考 服务端。

## 项目

### Riverpod

状态管理用 Riverpod 2.6 codegen。如果你要用 riverpod，你需要注意的是！

1. widget 生命周期内（initState / didChangeDependencies / didUpdateWidget）禁止调 provider notifier 写状态，似乎 AI 都经常注意不到这一点导致应用崩溃。
2. deactivated 元素禁止 `ref.read`（崩溃 "Looking up a deactivated widget's ancestor"）。值得注意的是 ConsumerState 注册外部监听（CDS / WS / 流）或 ref.listen 回调实现 deactivate()/activate() 摘挂监听！
3. autoDispose provider 每次进房间都是新实例，默认值即可用——生命周期里做重置写入是多余的（而且这样会违反第一条，AI 特别喜欢重复造轮子，不要这样！）

改了 `@riverpod` 签名后请运行 `dart run build_runner build` 重新生成 `.g.dart`。

### Test

- 测试用 `flutter test`，CI 也会运行
- 请在 `test` 目录下新建测试文件，测试文件名必须以 `_test.dart` 结尾
- 任何较大范围的更改都需要增加测试
- 请使用英文描述编写测试名称

### 消息

- 消息来源于 `ChatDataService`，Riverpod provider 只镜像，不可自持数据
- 改任何 CDS 写（setMessages / addSentMessage / deleteLocalMessage / loadOlderMessages / markMessageRecalled / _onMessageAck）都会触发 `_notifyRoom(roomId)`，UI 刷新依赖房间通知。**如果你是 AI 特别 TM 需要注意这一点**
- TFC 是不裁剪消息列表的，CDS 初始 50 条、loadOlder 无限增长~~是计划的一部分~~，翻页与跳转依赖完整缓存
- 批量同步请用 `_withBatchedRoomNotify` 包装
- 内容无变化的 provider 更新要跳过（`ChatMessage.sameRenderedContent`），否则气泡重建会导致性能问题（且用户体验 UI 不好）
- 自己的图片消息 pending→uploaded 时保持同一 widget 分支（有 cachedBytes 就走本地分支），切换分支结构会强制重载图片。

### 设置

**特别注意！新增一个设置项要改齐三处，缺少将会构建失败 / 显示未翻译键**

1. `lib/models/settings_model.dart` 的 `SettingsData.categories`（声明式，设置页自动渲染）。
2. `lib/l10n/` 三个 arb（en / zh / och，不过如果你不会文言可以用繁体占位但需要说明，最好使用文言风格）加 titleKey/descriptionKey，然后 `flutter gen-l10n`（不运行也可以，构建时会自动生成）。**注意：不要修改 app_localizations 的 dart 文件，这没有作用，该文件是自动生成的！！**
3. `lib/screens/settings_screen.dart` 的 `_getSettingTitle` switch 加 case。注意：该 switch 是手写的 key 到 getter 映射，漏加会显示未翻译键名。AI 需要特别注意。

### 其他协作

- 用户可能并行编辑同一批文件，如果你要在几次操作后改文件前，你需要先读最新内容，不要假设工作区只有自己的改动。
- 代码里的玩笑注释不需要要清理或"规范化"，显然这是我故意的（毕竟这个世界已经太乏味了，连有彩蛋的软件都没几个了）


### 主题与样式

设计令牌在 `lib/theme/tokens.dart`（`TFSpace` / `TFRadius` / `TFSize` / `TFMotion` / `TFAlpha`），主题构造在 `lib/theme/app_theme.dart`。新增间距、圆角、时长优先查看已有令牌。

**以下是约束，不是风格建议：**

1. **不要覆写 `textTheme` / `primaryTextTheme`。** `ThemeData` 内部已经对文本主题 `apply()` 过，产物是 `inherit: true`，违反会导致 `AnimatedDefaultTextStyle` 在 `TextStyle.lerp` 时抛 `Failed to interpolate TextStyles with different inherit values`。这个断言在 debug 下不显示，但 UI 会出现大量异常文本样式和布局错乱。**切记：不要试图通过覆写文本主题来修复样式问题**
2. **不要把 `theme.textTheme.*` 塞进子主题的 `textStyle` 字段**（appBar / dialog / snackBar / listTile / chip / popupMenu / tooltip）。同上一条
3. 确实要标题样式时，必须 `inherit: false` 构造，并且**显式带上 `fontFamily`**。
4. **不要覆写 `inputDecorationTheme` 的 border。**
5. 下面这些默认值影响全站几何尺寸：`iconTheme`、`listTileTheme.contentPadding` / `minVerticalPadding`、`dividerTheme.space`、`dialogTheme.insetPadding`、`progressIndicatorTheme.linearMinHeight`、`chipTheme.padding`，**不要随意修改**。
6. 表面层级方向必须一致卡片用 `surfaceContainerLow`（比页面略深），浮层用 `surfaceContainerLowest` + `elevation: 3`（比卡片浅）。用户自定义配色使用 `main.dart` 的 `_applyCustomColors`，不能让 `surfaceContainer` 正好等于页面色，否则会相当于隐形找不着。

### Provider 与缓存

- **带缓存的状态里，Map 的键一律用业务标识（`mid` / `id`），不要用对象身份。** 消息列表重建后拿到的是新实例，而 provider 复用旧 state，会炸！！！！！
- 同样的，缓存的失效判据（签名）必须覆盖所有会影响结果的字段。

### 页面销毁后不要再用 context

请在 pop 之前把需要的东西捕获下来作为参数传进后台方法。

可参考 `lib/screens/forum_post_compose_screen.dart` 的 `_submitInBackground`。

### 本地测试

- **绕开代理**，否则 `flutter_tester` 与测试宿主之间的 localhost WebSocket 升级请求会被 `HTTP_PROXY` 拦截 `WebSocketException: Invalid WebSocket upgrade request`。

  ```bash
  NO_PROXY="localhost,127.0.0.1,::1" no_proxy="localhost,127.0.0.1,::1" flutter test
  ```

  大小写都要设置。


### 导航与外壳

- 主壳是 `StatefulShellRoute.indexedStack`，分支顺序固定 `chat / announcement / forum / account / admin`（注意导航项会随特性开关增减，分支不动）
- 切 tab 使用 `goBranch`，**不用 `popUntil + context.go()`**（那会销毁目标页的滚动位置、内层路由栈和 TabController）
- 新增底部导航项时需在 `_buildDestinations` 里加入 `branchIndex`。

### 新增文案

改完 `lib/l10n/*.arb`（en / zh / och 三个都要）记得 `flutter gen-l10n`。不要手改 `app_localizations*.dart`。**上面说过了但还是要再说一遍。**

## 非代码注意

除了项目本身的代码，AI 在编写代码时也需要遵守（本条目的为优化 AI 生成内容，非项目强制性规定，但如果你是 AI/LLM 需要遵守）

**在写代码之前，请确认：**

1. 这需要吗？
2. 代码库中是否已经存在了？复用已有的函数、工具，不要重复造轮子！
3. 标准库是否已经提供了？可以使用！
4. 原生平台功能是否覆盖了？可以使用！
5. 已安装的依赖是否能解决？可以使用！
6. 会需要哪些依赖吗？选择哪个更好？（如果你不确定，可询问用户）
7. 写出能工作的最少代码。

**注意，以上不能代替理解**：如果你是 AI/LLM，先通读任务和它涉及的代码，追踪完整的实际流程（端到端），然后再确认并研究以上问题。

**修复根本的问题！**找出所有调用方，并在共享函数中修复一次，显然这样会比在每个调用方分别打补丁的差异更小。

**规则：**

- 不要引入用户没有明确要求的抽象层。（但也不要完全拒绝，如不要像 TouchFish-Astra 那样通过 if-else 而非国际化框架进行国际化，适度的框架和抽象是必要的！）
- 删除优于新增。平庸优于花哨。（注：这段部分来源于 Zen of Python）
- 对复杂的需求提出质疑：“你真的需要 X 吗？还是 Y 就能覆盖？”
- 当多种方法规模相同时，选择边缘情况正确的那一个。你需要写出更少的代码，而不是更脆弱的算法。
- 如果有意做简化，影响真实但带有已知上限（例如全局锁、O(n^2) 等高耗时算法），请使用注释标出！如果用户要求提交（commit）也请在 commit message 里说明。

**以下方面不允许“懒”**：理解问题（在爬梯子之前完整阅读并追踪实际流程——不了解情况的小改动只是伪装成效率的懒惰）、信任边界上的输入校验、防止数据丢失的错误处理、安全性、可访问性、真实硬件所需的校准（平台永远不是理想规格，时钟会漂移，传感器读数会偏移），以及任何明确要求的内容。

**自检代码！**：非平凡的逻辑必须留下 **一个** 可运行的检查，即如果逻辑被破坏则失败的最小东西。**但是不要过度工程，平凡的一行代码不需要测试。**