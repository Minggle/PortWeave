# Mac 版本开发计划与进度

更新日期：2026-11-09。基线：`feature/multi-subscription-ports`，`f2b03c0`，应用版本 `0.9.3+2026110401`。

## 当前进度

上游已具备 macOS Runner、菜单栏、窗口、系统代理、DNS 恢复、Core 生命周期及 ARM64/Intel 构建配置。
当前分支已实现多订阅独立端口的模型、配置生成、局部订阅更新、失败回退和管理页面。
Mac 已独立命名为 PortWeave（端流），主代理默认 7891；本页记录 Mac 验证，Windows 的历史记录见 `PORT_ROUTING.md`。

本轮已补齐 Mac 工具页入口与 `lsof` 监听归属查询，修复原先 Mac 空归属表导致的端口冲突误报。
状态检查现在区分查询失败、无监听与其他进程占用，并丢弃停机或较新检查之后到达的旧结果。
窗口恢复和可见窗口的定时检查会更新状态；隐藏期间继续订阅更新。另已加入 ARM64/Intel DMG 构建流程。

当前主机为 Apple Silicon，已在临时目录准备 Flutter 3.47.6、Dart 3.13.5、Go 1.27.1、Rust 1.99.0。
仅有 Command Line Tools，缺少完整 Xcode，本机 Release 命令已确认因此不能编译。
原始工作区存在大量 CRLF/LF 和文件模式差异；后续开发在独立 worktree `codex/macos-subscription-ports` 完成，原始工作区变更保留。

## 开发顺序与验收

| 阶段 | 任务 | 完成标准 | 状态 |
| --- | --- | --- | --- |
| M0 | 核对源码、历史与工具链，记录开发计划 | 区分已有功能、移植缺口与验证阻塞 | 已完成 |
| M1 | Mac 多端口入口与监听归属检查 | Mac 可进入管理页；解析实际监听 PID；拒绝其他进程占用；保留 Windows 行为 | 已实现，专项测试通过 |
| M2 | 状态恢复与 Mac 回归 | 检查失败显示可靠状态；停机/重启不显示过期结果；系统代理、TUN、DNS 保存值保持可恢复 | 已实现，自动化回归通过；系统实机验收待完成 |
| M3 | fork 的 Mac 构建交付 | ARM64、Intel 分别测试与 Release 构建，输出 DMG 和各自校验文件；保留 Intel Impeller 配置 | 两架构测试、Release 编译、DMG 打包和上传均通过 |
| M4 | 使用文档与完整验收记录 | 操作入口、安装/更新、验证命令和未验收范围清晰；记录实际执行结果 | 已完成本轮开发记录；人工验收范围见清单 |
| M5 | PortWeave 独立 Mac 品牌 | 应用、包名、Bundle ID、网址协议、图标及数据独立；完成两架构重新构建 | 已完成，双架构构建与下载后验收通过 |
| M6 | 测试版默认监听端口错开原版 | 主代理 7891、控制接口 9091、多端口绑定起点 18082；重置入口和配置提示一致 | 已完成，4,912 项全套测试及双架构验收通过 |

| M7 | 私有仓库更新与个人分发 | GitHub 仓库为 Private；Mac 手动下载入口需登录；不自动请求匿名 Release API | 已完成；4,917 项测试、双架构构建/包校验、ARM64 安全启动通过 |

M0—M6 已完成本轮自动化与打包验收。M7 完成后优先做签名分发及明确列出的实机验收；性能优化以实际测量为依据。

## 实现约束

- 复用单一 Core、已有 PortRoutingAction 和配置合成；桌面进程始终由 `lib/core/desktop/` 管理。
- 多端口只监听 IPv4 回环，支持 HTTP、HTTPS CONNECT、SOCKS5 TCP；固定节点丢失或区域候选为空时拒绝连接。
- 专用模式继续关闭有效系统代理、TUN、DNS 改写和默认混合端口，保留用户设置。
- GUI 在开发主机上只使用 `SAFE_MODE=true`；真实流量通过独立 Core 回环测试验证。完整公网及系统接管验收由用户在测试环境运行。
- 代码修改遵循 `core-platform`、`ui-work` 技能。模型/provider 定义变化后运行生成器；生成文件不手改。
- Mac 包未经过签名、公证或真实安装验证前，明确标为测试构建；不宣称正式发布。

## 验证清单

- [x] `flutter pub get`：使用原锁文件，未升级依赖。
- [x] `flutter analyze --no-fatal-infos`
- [x] 当前本地全套 Flutter 测试：4,917 项通过，含模型、provider、页面、Core、插件、widget 和 lint（`tool/test.dart` 调用 `flutter test`）。
- [x] 本轮私有更新入口专项测试：50 项；中英文关于页截图渲染检查通过。
- [x] `CGO_ENABLED=0 go test -C core . -run '^TestPortRoutingWire$' -count=1`
- [x] `CGO_ENABLED=0 go vet -C core . ./cmd/...`
- [x] 新 workflow 的 `actionlint` 和打包脚本的 `bash -n`。
- [x] Mac ARM64 Release 编译、产物内容和 DMG 检查：云端构建成功；下载后 SHA256、DMG 完整性、GUI/Core/Rust/SQLite 的 ARM64 架构及 bundle 签名均通过。
- [x] Mac Intel Release 编译、签名/架构检查和 DMG 打包：云端构建通过；下载后 SHA256、DMG 完整性及 GUI/Core/Rust/SQLite 的 x86_64 架构检查通过，确认 `FLTEnableImpeller=false`；Intel 硬件的运行体验待人工验收。
- [x] ARM64 安全模式启动：`f814efe` 的 `io.github.minggle.portweave.debug` 应用及 Core IPC 成功启动；启动和退出前后系统代理/DNS 快照一致，Core 无 TCP 监听，无匿名更新错误；记录 PID 后结束测试，GUI/Core 均退出。
- [ ] 安全模式 GUI 点击验收：早期检查时 Mac 锁屏，后续界面读取工具超时；菜单入口和表单已有自动化 widget 测试通过。
- [ ] 测试环境：真实订阅、两个应用的出口隔离、睡眠唤醒、网络切换、退出后的系统状态恢复

完整 Xcode 是本机 Flutter macOS 原生编译的外部前提。未通过的检查保持未勾选，并记录具体原因。

## 交付与后续优化

Mac 产品名称为 **PortWeave（端流）**，应用为 `PortWeave.app`，安装包为
`PortWeave-<版本>-macos-<架构>.dmg`。Release/Profile 标识为
`io.github.minggle.portweave`，Debug 为 `io.github.minggle.portweave.debug`。
系统只注册 `portweave://`，手动导入仍识别兼容的 Clash 订阅链接。
应用数据、偏好、缓存和登录项按新标识隔离，首次启动是空配置，不自动迁移已有 FlClash 数据；可手动导入备份或订阅。
PortWeave 可与 FlClash 同时安装，但系统代理、TUN 和监听端口仍是主机共享资源；并行使用时应启用专用多端口模式并选择未占用端口。
应用及菜单栏图标源文件在 `assets_source/images/portweave/`，安装 librsvg 后运行
`bash tool/generate_portweave_icons.sh` 可重建所有尺寸。上游许可证和作者信息保留。

M5/M6 验证基线为 `37d171d`，M7 应用代码为 `f814efe`；后续文档提交不改变构建内容。

M5 本地验证：136 项专项测试及 2,692 项公共模块、界面、窗口、语言和规范回归全部通过；
代码生成、全仓格式检查、actionlint 和打包负向检查通过。依赖锁文件未变化。
M5 的 CI 静态分析与完整跨平台检查通过；ARM64 PortWeave 包的身份、25 个图标资源、架构、签名及 SHA256 验证通过。
安全模式用新 Debug 标识启动并连接 Core IPC，代理/DNS 未变化、Core 无 TCP 监听，测试进程均按记录 PID 退出。
GUI 点击读取超时，仍留待实机交互验收。

按测试版要求，固定的本地默认端口在原值上加 1：混合代理 `7890 → 7891`、
控制接口 `9090 → 9091`（仍需手动开启并设置密钥）、新建绑定起点 `18081 → 18082`。
DNS 默认不监听，编辑器的监听示例由 `1053` 改为 `1054`；值为 0 的关闭项继续保持关闭。
DNS 协议目的端口 53、远端服务端口以及系统分配的临时端口不属于应用固定监听默认值。
已有用户指定的端口保留；导入旧备份后可在网络设置的端口表单中重置到新默认值。
旧备份里的控制接口开启状态仍可导入，实际监听使用 9091。

M6 本地 `flutter analyze --no-fatal-infos`、262 项专项测试和全套 4,912 项 Flutter 测试通过；
代码生成、全仓格式检查及注释密度检查通过。ARM64/Intel 新端口包均已完成构建与本机下载验收。两包的 SHA256、DMG 完整性、应用身份/协议、GUI/Core/Flutter/App/Rust/SQLite 架构、bundle 签名和 25 个图标资源一致性通过；Intel 保留 `FLTEnableImpeller=false`。

- 开发分支：`codex/macos-subscription-ports`；[草稿 PR #1](https://github.com/Minggle/FlClash/pull/1)。
- [完整跨平台 CI](https://github.com/Minggle/FlClash/actions/runs/42575216818) 在 `37d171d` 上通过，包含 Dart 全套、插件、Go、Rust、Android 单元测试和三桌面平台 Debug 编译。
- [Mac 双架构构建](https://github.com/Minggle/FlClash/actions/runs/42620141996) 产出独立 DMG、`SHA256SUMS-macos-*` 和单独的 ARM64 安全模式调试包。
- 本机产物保存在 `dist/portweave-f814efe/arm64/`、`dist/portweave-f814efe/amd64/` 和 `dist/portweave-f814efe/safe-mode/`；验收日志与中英文截图位于 `dist/portweave-f814efe/validation/`；这些构建输出不提交 Git。
- 当前构建是开发测试包，应用数字版本仍为 `0.9.3`。正式发版应选取新版本标签；本轮未创建或发布版本标签。
- Developer ID 签名、公证、Gatekeeper 首次安装、Intel 实机运行、真实订阅公网出口以及睡眠/网络切换验收尚未完成。
- 后续优先级：先完成上述实机验收及签名分发，再基于大量绑定/订阅下的实际测量优化状态列表和后台能耗；不预先更换 Core 生命周期或重写现有 UI。
- 仓库已在 2026-11-09 设为 **PRIVATE**，GitHub 再次读取确认 `isPrivate=true`。后续代码及构建仅向此私有仓库推送。
- 私有仓库不提供匿名更新查询；M7 已将 Mac 关于页改为“下载测试版本”，通过浏览器登录 GitHub 下载构建，并关闭自动查询入口。应用不存储 GitHub 令牌。

M7 验证：依赖锁文件未变化，代码与本地化生成器运行成功，静态分析、50 项专项测试及全套 4,917 项测试通过。Mac 更新策略由 `lib/common/app_update.dart` 统一提供；关于页、自动查询和设置入口复用同一策略。ARM64/Intel 最终包的 SHA256、DMG 完整性、Bundle ID/协议、GUI/Core/各框架架构、签名和全部 25 个图标资源验证通过。ARM64 安全模式启动通过，见上述清单。私有仓库分支推送时完整跨平台 CI 按既有规则跳过；本轮使用本地全套测试和双 Mac CI 验证，没有将跳过视为通过。

## 下一阶段实机验收

| 场景 | 操作 | 通过条件 |
| --- | --- | --- |
| 并行安装 | 将对应架构的 `PortWeave.app` 拖入 Applications，保留原 FlClash；首次启动检查网络设置 | 应用、图标和数据独立；普通混合代理默认 7891；旧备份的显式端口需自行检查或重置 |
| 两个订阅出口 | 在 PortWeave 导入两个真实订阅，分别绑定空闲的 18082、18083 并开启专用模式；两个客户端分别连接对应端口 | 两个客户端使用各自选择的节点；修改一条绑定不改变另一条的订阅归属 |
| 订阅刷新 | 保持一个客户端连接，更新另一条绑定对应的订阅，再检查节点消失和空候选情况 | 正常更新不关闭其他订阅连接；无可用节点时拒绝连接，不切换到其他订阅或直连 |
| 睡眠和网络切换 | 连接后睡眠/唤醒、切换 Wi-Fi，再显示应用窗口 | 状态重新检查，归属正确；无旧检查结果覆盖新结果，定时订阅更新恢复 |
| 退出恢复 | 专用模式下退出 PortWeave，对照启动前记录检查系统代理/DNS，并确认原 FlClash 仍可使用 | PortWeave Core 与监听退出，原应用的代理/DNS设置保持一致 |
| 受限下载 | 在有权限的浏览器账号下打开“关于 → 下载测试版本” | 进入私有构建列表，选择成功构建并下载对应架构；应用启动不反复报告更新 404 |

以上真实网络和安装操作由用户在测试环境执行。Developer ID 签名及公证需要 Apple Developer 分发身份，待提供后单独验收 Gatekeeper 首次安装行为。
