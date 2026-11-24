# PortWeave（端流）：多订阅端口与策略优先级

更新日期：2026-11-23。当前开发版本 `0.9.4`，Flutter `3.50.0`。仓库已更名为 `Minggle/PortWeave`，`origin` 已更新，当前保持公开。升级、测试和交付进度统一记录在 [Mac 开发记录](MACOS_DEVELOPMENT.md)；本页旧版结果不代表 0.9.4 已验证。

工作已归并回原主工作区，以 `ac80b820` 提交并推送 `main`；临时升级工作区已删除，本地及 origin 开发分支仅保留 `main`，原有修改的 stash 备份保留。后续开发从仓库根目录 `.` 继续。

`ac80b820` 的 ARM64 包已通过下载后 SHA256、DMG、应用身份、架构与 bundle 签名校验，并安装至本机供用户测试。真实网络验收待用户完成；双架构与后续 CI 状态统一见 [Mac 开发记录](MACOS_DEVELOPMENT.md)。

[English overview](README.md) · [中文介绍](README_zh_CN.md) · [发布记录](RELEASE_PORTS.md) · [Mac 验证进度](MACOS_DEVELOPMENT.md)

## 多订阅独立端口

Windows / macOS：打开 **工具 → 多订阅端口**。先在原有配置页面导入订阅，再添加端口绑定：选择端口和策略：默认沿用一个订阅的原有规则/策略组，或选择固定节点、按关键词聚合多个订阅，最后开启专用多端口模式。区域关键词以 `|` 分隔，忽略大小写，按节点名称匹配；自动选择衡量延迟，不是带宽或出口国家认证。

每个端口同时支持 HTTP、HTTPS CONNECT 和 SOCKS5 TCP，只监听 `127.0.0.1`。例如两个应用分别设置 `http://127.0.0.1:18082` 和 `socks5h://127.0.0.1:18083`。右键绑定可复制地址、更新订阅和设置更新间隔。一个订阅可建立多条绑定。此版本不支持 UDP、局域网共享或按进程接管。

开启时切入受管理的自定义配置，关闭时恢复此前配置。选择其他普通配置也会停用端口。多端口模式支持**主出站共存**与**隔离模式**：
- 当启用默认出站（`takeoverSystem = true` 且存在已启用绑定，按 `defaultBindingId` → 首个聚合绑定 → 首个原策略绑定 → 首个已启用绑定的顺序解析）时，顶层 `rules` 复用主出站的规则或策略组，从而与系统代理、TUN、控制接口和默认混合端口（如 `7891`）共存；主出站被禁用或删除时会自动回退到下一个已启用绑定（或提示进入隔离模式）。共存模式下会校验启用绑定端口与主机活动端口（`mixedPort`/`port`/`socksPort`/`redirPort`/`tproxyPort`/控制接口端口）的双向冲突。
- 当关闭系统接管（`takeoverSystem = false`）或无已启用绑定时进入隔离模式：运行时关闭系统代理、TUN、控制接口和默认混合端口（不改写保存值），顶层规则兜底为 `MATCH,REJECT`，应用自身下载与探测改为直连。
- 多端口模式激活期间强制锁定为规则模式（`Mode.rule`），以确保各次级监听端口的 `sub-rules` 隔离生效；支持在列表中拖动调整端口绑定顺序而不触发 Core 重载。

## 聚合代理与端口页面

每个绑定在桌面“代理”下有独立入口，按名称和端口区分。聚合代理同样拥有独立监听端口，应用填入聚合地址才会使用该配置；其他代理商端口同时运行。`工具 → 聚合代理` 创建聚合绑定，选择底稿后在端口专页的“策略组与优先级”配置业务组的主备层级。旧普通配置优先级在聚合总览内保留，可复制到端口后独立编辑。

`PortBinding.policies` 保存端口级策略，`sourceIds` 包含底稿和所有备用订阅。生成配置按绑定 ID 隔离节点、组及子规则，不再让两个引用同一订阅的端口共用策略组。聚合绑定保留源文件规则，按优先级编译 fallback 和各订阅层的 url-test；空候选指向 REJECT，源配置的显式直连规则保留。聚合源更新复用原策略的重应用与失败恢复路径，可能短暂重连。备份恢复重映射每一层来源，任一来源缺失时丢弃完整绑定。

共存模式下默认混合端口（如 `7891`）跟随主出站规则，聚合 `18084` 和代理商 `18082` 等次级端口同时独立运行；隔离模式下则仅开放显式绑定端口。完整操作与 curl 示例见 [中文 README](README_zh_CN.md#普通旧端口与多端口如何切换)。

## 节点与更新

- 使用已有订阅的顶层代理节点；嵌套 `proxy-providers`、直接连接节点、重复节点名和带 `dialer-proxy` 的代理链会被拒绝。现有导入支持的分享链接与加密订阅仍由原校验流程转换。
- “沿用原有策略”使用一个订阅的原始规则、策略组及已保存的组选项，保留规则中的 DIRECT/REJECT。规则空间按来源隔离，不使用其他订阅的规则；引用同一来源的原策略端口共用该来源的规则和组。全局/直连模式分别映射到此订阅的组/直连，原规则未命中时也保留直连兜底。DNS、TUN、系统代理和额外监听等主机设置仍由专用模式统一管理。
- “固定节点”按完整名称匹配；消失后拒绝新连接。“按区域自动选择”可在配置选择页勾选多个订阅，例如用 `US|美国` 汇总所有所选订阅的匹配节点。同名节点保留来源标识，候选为空时拒绝连接；不会扩大到未选订阅或自动直连。
- 每个订阅默认每 5 分钟拉取，调度器每 30 秒检查到期任务。更新设置对同一订阅的所有端口生效，可暂停或改为 1～1440 分钟。程序退出期间不更新。
- 仅用于固定/关键词绑定的订阅继续使用临时文件校验及 provider 局部加载，失败保留最后可用缓存，更新一个来源会刷新引用它的聚合组。涉及原策略绑定的订阅更新时会重新应用多端口配置，以同步规则和组的变化，可能短暂重连；失败恢复旧源文件、缓存和配置。
- 添加和编辑成功后才关闭表单；保存失败保留输入并显示错误。REALITY 的未加引号 short-id 按原始文本读取，避免前导零丢失或被解析成科学计数法后无法添加。
- “已监听”表示端口归当前 Core 所有且 SOCKS 握手成功，不表示节点的互联网出口已验证。
- macOS 通过系统自带的 `lsof` 查询 IPv4 TCP 监听归属，不额外请求管理员权限。查询失败或无法确认归属时显示不可用；确认属于其他进程时才显示端口冲突。窗口可见时每 30 秒检查状态，重新显示窗口时也会检查；隐藏窗口仍按订阅周期更新，但不定时探测监听。

## 维护与验证

历史功能基线见固定提交 [`f2b03c06`](https://github.com/Minggle/PortWeave/tree/f2b03c06)。多端口代码集中在 `lib/common/port_*`、`lib/models/port_routing.dart`、`lib/providers/port_routing.dart`、`lib/providers/actions/port_routing.dart` 和 `lib/views/port_routing.dart`；策略优先级对应 `priority_policy.dart`。多端口配置持久化使用 `Config.portRouting`，功能引入时没有新增数据库 schema 版本；旧设置默认关闭。恢复备份时检查订阅引用并丢弃可重建缓存。

多端口功能复用单一 Core 与原有生命周期，不另建进程管理入口。`CoreService.processId` 只读暴露已持有的进程 ID，用于监听归属检查。以下为开发验证命令，实际通过项与待修复检查以 [Mac 开发记录](MACOS_DEVELOPMENT.md) 为准：

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter analyze --no-fatal-infos
flutter test test/common/port_routing_test.dart test/providers/port_routing_action_test.dart test/views/port_routing_test.dart
flutter test test/common/priority_policy_test.dart test/providers/priority_policy_action_test.dart test/views/priority_policy_test.dart
flutter test test/database/migration_v1_to_v2_test.dart test/common/backup_task_test.dart test/providers/script_outbounds_test.dart test/providers/setup_state_test.dart
$env:CGO_ENABLED = '0'
go test -C core . -run '^Test(PortRouting|PriorityPolicy)Wire$' -count=1 -v
flutter build windows --release
```

Go 测试在独立子进程与临时目录运行，只使用回环端口和本地模拟出口，覆盖 HTTP/SOCKS5 分离、区域选择、局部更新保留另一个订阅的持续连接，以及空源/节点消失的拒绝行为。不会启动 GUI、TUN 或修改系统代理。外部真实订阅与公网出口仍需实际环境验收。

本机 GUI 调试必须使用 `flutter run --dart-define-from-file=env.json --dart-define=SAFE_MODE=true`。安全模式不会开放这些端口，真实流量测试应使用上述隔离测试或单独的测试环境。只结束自行启动并记录 PID 的测试进程。

## macOS 与 Windows 开发与构建

macOS 最低部署目标为 macOS 12.0，Apple Silicon（`arm64`）和 Intel（`amd64`）分别构建；Windows 面向 x64（`amd64`）同时输出便携 ZIP 与 Inno Setup 安装包。实际验证范围见 [Mac 开发记录](MACOS_DEVELOPMENT.md)与[发布状态](RELEASE_PORTS.md)。

两端应用均名 **PortWeave（端流）**，可与 FlClash 并存安装：
- **macOS**：`PortWeave.app`，独立图标、Bundle ID `io.github.minggle.portweave`（Debug 为 `.debug`）与 `portweave://` 协议。
- **Windows**：`PortWeave.exe`，独立图标、`CompanyName=io.github.minggle` / `ProductName=PortWeave`（数据目录 `%APPDATA%\io.github.minggle\PortWeave` 与 `%LOCALAPPDATA%\io.github.minggle\PortWeave`）、独立 Inno Setup `AppId` 与 `portweave://` 协议。

两者同时与 FlClash 运行时，仍需避免抢占系统代理/TUN 和相同监听端口；建议 PortWeave 使用专用多端口模式。

普通混合代理默认端口为 **7891**。外部控制接口默认关闭，开启后监听 `127.0.0.1:9091`，未设置密钥时自动生成。新建订阅端口从 **18082** 开始跳过已有绑定的端口；其他进程占用仍需通过监听检查确认。DNS 默认不开放监听，编辑器示例使用 **1054**。导入备份会保留其中明确设置的代理端口；网络设置里的“重置”可恢复 7891。

需要完整 Xcode（macOS，仅 Command Line Tools 不够）或 Visual Studio + Inno Setup 6（Windows）、Flutter 3.50.0、Go 1.27 和 Rust。macOS 本地打包示例：

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test test/common/port_routing_test.dart test/providers/port_routing_action_test.dart test/views/port_routing_test.dart test/common/system_dns_test.dart test/core/desktop
flutter test test/common/priority_policy_test.dart test/providers/priority_policy_action_test.dart test/views/priority_policy_test.dart
flutter test test/database/migration_v1_to_v2_test.dart test/common/backup_task_test.dart test/providers/script_outbounds_test.dart test/providers/setup_state_test.dart
CGO_ENABLED=0 go test -C core . -run '^Test(PortRouting|PriorityPolicy)Wire$' -count=1
FLUTTER_MACOS_ARM64_ONLY=true flutter build macos --release --build-name=1.0.0 --dart-define=APP_ENV=stable
bash tool/package_macos.sh 1.0.0 arm64
```

Windows 本地打包示例（需已安装 Inno Setup 6）：

```powershell
flutter build windows --release --build-name=1.0.0 --dart-define=APP_ENV=stable
pwsh -File tool/package_windows.ps1 -Version 1.0.0 -Arch amd64
```

ARM64 构建设置 `FLUTTER_MACOS_ARM64_ONLY=true`，Intel 构建打包参数改为 `amd64`。`tool/package_macos.sh` 检查应用身份、协议、图标、App/Core 架构及 bundle 签名，生成 `dist/PortWeave-<版本>-macos-<架构>.dmg` 和 `SHA256SUMS-macos-<架构>`；`tool/package_windows.ps1` 检查 `PortWeave.exe` 身份及 Core/Helper 二进制，生成 `dist/PortWeave-<版本>-windows-amd64.zip`、`dist/PortWeave-<版本>-windows-amd64-setup.exe` 和 `SHA256SUMS-windows-amd64`。

分支开发构建由 [PortWeave - macOS](https://github.com/Minggle/PortWeave/actions/workflows/ports-macos.yaml) 和 [PortWeave - Windows](https://github.com/Minggle/PortWeave/actions/workflows/ports-windows.yaml) 在 `main` 推送和手动 **Run workflow** 时运行（Mac 的 `safe_mode` 手动选项默认 `false`，开启时额外构建 ARM64 安全模式调试包）。每个平台仅保留最新 run 的 artifact，一天后到期。上传文件预算：macOS ARM64 250 MB（含可选安全模式包）、macOS Intel 100 MB、Windows 200 MB（同时包含便携 ZIP 与 Inno Setup EXE），超出预算会阻止上传。这些规则针对分支 workflows 的 Actions artifact，GitHub Release 附件另行保留。

正式与预发行版本统一由 `.github/workflows/release.yaml`（`PortWeave - Release`）在推送 `v*` 标签或手动触发时并行构建 macOS (`arm64` / `amd64`) 和 Windows (`amd64`)，合并校验全部平台产物生成统一 `SHA256SUMS` 后原子发布到 [GitHub Releases](https://github.com/Minggle/PortWeave/releases/latest)。

DMG 内含应用和 Applications 快捷方式；更新时退出已安装的 PortWeave，将新应用拖入 Applications，再由用户启动。macOS 当前沿用临时签名，尚未接入 Developer ID 签名或 Apple 公证。

## 仓库与发布

仓库及下载来源为 `Minggle/PortWeave`，正式发布位于 [GitHub Releases](https://github.com/Minggle/PortWeave/releases/latest)。`PortWeave - Release` workflow 在推送 `v*` 标签时构建并发布 `PortWeave-<版本>-macos-arm64.dmg`、`PortWeave-<版本>-macos-amd64.dmg`、`PortWeave-<版本>-windows-amd64.zip`、`PortWeave-<版本>-windows-amd64-setup.exe` 以及统一 `SHA256SUMS`：带 `-` 的版本标签标为预发行，纯数字 semver 标签（如 `v1.0.0`）自动标为 Latest 正式版。

合并上游稳定版本后重新生成代码，并优先运行多端口功能测试、配置/备份/HTTP 回归和桌面 Core 测试。不要在正式构建中关闭 `pubspec.yaml` 的原生 `build_assets` hooks。

## CI Runner 切换

`build` workflow 的 Dart、Plugins、Go core、Android unit tests、Rust 和 Desktop linux 共用仓库变量 `LINUX_CI_RUNNER`。未设置时使用 GitHub 的 `ubuntu-latest`，合并到其他仓库不会自动启用 Instabox。测试步骤、工具链版本和检查范围保持一致。

在 Instabox 的目标工作区连接 GitHub 的 `Minggle` 账号，并授权 `Minggle/PortWeave` 后启用：

```powershell
gh variable set LINUX_CI_RUNNER --repo Minggle/PortWeave --body instabox-medium
```

`instabox-medium` 是 Ubuntu 24.04、4 vCPU / 8 GiB 的临时机器，支持免费计划；每个 job 结束后自动删除。Windows、macOS 原生构建仍使用 GitHub 对应平台的 runner；Instabox 无法解决 macOS 构建机容量不足。实际耗时取决于排队、缓存和工作区额度，应比较完整 CI 耗时后再判断是否加速。

首次启用后同时查看 `gh run view <run-id> --repo Minggle/PortWeave` 和 `instabox ci`。若 GitHub 排队而 Instabox 没有对应 job，检查 App 对此仓库的访问授权；若 Instabox 显示拒绝或等待，按其中的原因处理。回退命令只影响之后调度的任务：

```powershell
gh variable delete LINUX_CI_RUNNER --repo Minggle/PortWeave
```

已排队的任务需要取消后重新运行才会使用回退后的 runner。原有上游发布 job 和独立的 Windows 发布 workflow 不受这个变量控制。

macOS ARM runner 容量不足时，可将普通编译检查临时切到 Intel runner：

```powershell
gh variable set MACOS_CI_RUNNER --repo Minggle/PortWeave --body macos-15-intel
```

未设置 `MACOS_CI_RUNNER` 时仍用 `macos-latest`，删除变量即可恢复。Intel 编译不能代替 ARM 编译验证；此开关只影响普通检查，原有发布矩阵中的 macOS 两种架构不变。

参考：[Instabox CI 官方文档](https://instabox.sh/docs/ci.md)。

## 本次验证记录

以下是 v0.9.3 Windows 首版的历史记录，保留原始结果与阻塞项，不作为 0.9.4 的通过结论。

基线 `be847366`（v0.9.3），Windows x64，Flutter 3.47.6 / Dart 3.13.5 / Go 1.27.3。

- `flutter pub get`、代码生成、国际化生成、`flutter analyze --no-fatal-infos` 完成。
- 多端口、配置、备份、HTTP、桌面 Core/协议及国际化集成测试通过（205 项）；其后补跑订阅导入/更新回归（16 项）与页面编辑/导航/布局测试（5 项）通过。计数为各次运行，不应相加为唯一测试数。
- `TestPortRoutingWire` 在 Windows 独立子进程中通过：HTTP/SOCKS5 端口出口隔离、自动组更新、固定节点/区域消失拒绝连接、空订阅不替换、订阅 B 持续连接不受 A 更新影响。
- 发布更新/下载相关测试通过（23 项），`go vet . ./cmd/...` 和独立 workflow 的 `actionlint` 通过。
- Windows Release 编译成功，包含 GUI、Go Core、Helper、Rust DLL 和 SQLite DLL。未使用真实订阅验证公网出口，也没有在主机上启动普通代理模式。
- 原有 `test/lint/` 在 Windows 下有 9 项路径相关误报，因检查用 `/` 匹配豁免路径而 Windows 返回 `\`。与新功能相关的布局检查、国际化键集合检查已通过。
- 全部 Go wrapper 测试在 Windows 下仍有两项既有兼容问题：`TestApplyConfigTellsARejectedProfileFromAFailedCall` 的 cache.db 句柄阻止临时目录清理；`TestHandleValidateProxiesLeavesARunningProxysResolverInPlace` 的路径错误文本断言不同。独立 Windows workflow 运行新增流量测试和 `go vet`，原有 Linux workflow 继续跑 Go 全套。

## 按业务规则使用自建主用与订阅备用

旧的普通配置功能入口现为“工具 → 聚合代理 → 策略优先级”，用于未关联脚本的普通配置，不需要创建额外端口。选择底稿和业务组后，保留底稿中的分流规则，为目标组建立从上到下的优先级链。例如视频组为“台湾自建组 → 家宽订阅中的 US 节点 → 其他订阅中的指定地区节点”。每个订阅层可勾选多个来源，使用包含/排除关键词筛选，并预览匹配结果；关键词以 `|` 分隔且忽略大小写，包含留空匹配全部。右键或长按层级行可上移、下移或删除。新聚合端口的策略与这份普通配置设置分别保存。

高层探测可用时始终优先；低层不会因为延迟更低抢占高层。层级间使用 fallback，订阅层内使用 url-test，每 60 秒探测，来源刷新后重新计算候选。恢复高层后新连接回切；现有连接不保证无缝迁移。使用时在“配置”页选择底稿并开启规则模式；系统代理、TUN 的启用仍由已有设置控制。修改只保存增强策略，不覆盖原文件；删除增强策略即可恢复原始组。DIRECT 仅在显式层级或原规则包含时生效。
