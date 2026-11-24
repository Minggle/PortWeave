<div align="center">

<img src="assets/images/portweave/icon.png" alt="PortWeave" width="88">

# PortWeave · 端流

面向 macOS 与 Windows 的代理客户端，让不同应用通过独立本地端口使用不同订阅。

[English](README.md) · **简体中文**

[代码仓库](https://github.com/Minggle/PortWeave) · [正式发布下载](https://github.com/Minggle/PortWeave/releases/latest) · [使用与开发说明](PORT_ROUTING.md) · [发布状态](RELEASE_PORTS.md)

</div>

PortWeave 可以同时运行代理商端口和聚合端口：应用指向哪个本地端口，就使用哪个页面的配置。聚合代理拥有自己的监听端口、分流规则和策略组主备顺序，修改它不会改变代理商端口的策略。

**发布版本线：1.0.0 · Flutter 3.50.0**。构建与验证记录见[发布状态](RELEASE_PORTS.md)和 [Mac 开发记录](MACOS_DEVELOPMENT.md)。

## 选择分流方式

| 方式 | 用途 | 操作入口 |
| --- | --- | --- |
| 多订阅端口 | 每条绑定在 `127.0.0.1` 提供独立的 HTTP / HTTPS CONNECT / SOCKS5 TCP 端口 | **工具 → 多订阅端口** |
| 沿用原有策略 | 使用一个订阅的原始规则、策略组和已保存组选项，与其他订阅的规则隔离 | 为端口绑定选择“沿用原有策略” |
| 固定节点 | 使用一个订阅中名称完全匹配的节点 | 为绑定选择节点 |
| 关键词聚合 | 从一个或多个选定订阅中筛选节点，并按延迟自动选择 | 勾选来源，输入 `US\|美国` 等关键词 |
| 聚合代理 | 独立端口保留底稿的分流规则，为各业务组配置跨订阅主备顺序 | **工具 → 聚合代理**，创建后从左侧“代理”下进入 |

关键词以 `|` 分隔，忽略大小写，按节点名称匹配；它不验证出口国家、带宽或特定服务的可用性。固定节点和关键词绑定在候选消失时拒绝新连接，不会悄悄切换到其他来源或直连。“沿用原有策略”保留 `DIRECT` / `REJECT` 等行为，可能根据原策略直连。

## 开始使用多订阅端口

1. 在**配置**页通过链接或文件导入订阅。
2. 打开**工具 → 多订阅端口**，添加绑定，选择来源、端口和策略。新建绑定默认沿用单个订阅的原有策略。
3. 开启**专用多端口模式**。
4. 在各个应用自身的代理设置中填写对应地址。

| 示例 | 代理地址 | 绑定策略 |
| --- | --- | --- |
| 应用 A | `http://127.0.0.1:18082` | 订阅 A 的原有规则与策略组 |
| 应用 B | `socks5h://127.0.0.1:18083` | 订阅 B 的固定节点 |
| 应用 C | `http://127.0.0.1:18084` | 聚合代理：按业务规则选择自建主用、订阅 A／B 备用 |

每个端口同时支持上述三种 TCP 代理协议。若应用分别填写服务器和端口，服务器填 `127.0.0.1`，端口填绑定中的数字。应用需要支持手动设置代理；专用模式不按进程接管流量。

开启专用模式会切入受管理的配置，并在运行时关闭系统代理、TUN、控制接口和默认混合端口，保留这些功能的保存值。关闭后恢复此前配置；选择其他普通配置也会退出专用模式。PortWeave 自身下载在此模式下直连。

创建后的端口会列在桌面左侧“代理”下面，名称旁显示端口号。点击某个子页面只显示该端口的配置和状态，右上角“编辑”修改来源、端口和策略；页面内可单独启用／停用该端口，其他端口继续运行。“代理”总览及“工具 → 多订阅端口”保留添加、删除和所有端口状态。

右键绑定可复制地址、立即更新订阅或调整更新间隔。每个订阅默认每 5 分钟更新，程序运行时每 30 秒检查到期任务。固定节点与关键词来源采用局部更新，失败保留最后可用缓存；涉及原策略或聚合绑定的来源更新会重新应用受管理配置，可能短暂重连。

## 聚合代理：一个端口，自建主用与多订阅备用

1. 打开**工具 → 聚合代理 → 添加**，填写名称和空闲端口（例如 `18084`），选择一份订阅／文件配置作为分流底稿，策略选择“聚合代理”。使用来源文件本身的规则与策略组，不执行普通配置附加的脚本。
2. 从左侧**代理 → 聚合名称 · 18084**进入专页，打开**策略组与优先级**。
3. 添加一个底稿已有的业务组，将底稿中的组／节点与多个订阅层按优先级排序。例如为“视频组”配置：

```text
视频组 → 台湾自建组 → 所选订阅中的 US 节点 → 其他备用层
```

每个订阅层可选择多个来源，设置包含／排除关键词并预览匹配结果。高层探测可用时始终优先；低层不会因为延迟更低而抢占高层，订阅层内部自动优选。探测间隔为 60 秒，高层恢复后新连接回切，已有连接不保证无缝迁移。

保存后开启**专用多端口模式**，确保此端口的开关也已打开。应用填写 `http://127.0.0.1:18084` 或 `socks5h://127.0.0.1:18084` 即使用聚合代理；改填 `18082` 就改用对应代理商的端口，无需停掉聚合端口。各端口可以同时服务不同应用。

未设置主备增强的组沿用底稿定义；运行中的手动选择组可在该端口页面切换节点。每个端口的组名和规则均隔离，同一订阅可以作为多个端口的底稿。删除某组的优先级设置会恢复其底稿定义，不修改源文件。备用订阅更新后会重新计算候选；空候选拒绝连接，显式配置的 `DIRECT` 和底稿直连规则仍会直连。

旧的普通配置优先级保留在**工具 → 聚合代理 → 策略优先级**中，仅影响普通混合端口。新建聚合端口会复制所选底稿已有的优先级；已建端口也可点“复制底稿的优先级设置”覆盖复制。复制后独立保存，之后修改原设置不会自动改变聚合端口。

## 普通旧端口与多端口如何切换

| 使用方式 | 应用填写 | PortWeave 状态 |
| --- | --- | --- |
| 普通代理 | `127.0.0.1:7891`（或自己保存的混合端口） | 关闭专用多端口模式，选中普通配置并启动 |
| 某个代理商 | `127.0.0.1:18082`／`18083` 等实际绑定端口 | 开启专用多端口模式及该绑定 |
| 聚合代理 | `127.0.0.1:18084` 等实际聚合端口 | 开启专用多端口模式及聚合绑定 |

普通 `7891` 与专用多端口模式互斥：开启专用模式会关闭普通混合端口、TUN 和系统代理；关闭专用模式恢复此前普通配置。`7890` 是原 FlClash 的常见默认端口，不是 PortWeave 新装默认值；旧备份导入的显式端口会保留，请以网络设置为准。`9091` 是控制接口，不能填作应用代理端口。

如需验证某个端口，可在启用相应配置后执行 `curl --proxy http://127.0.0.1:18084 https://example.com`，或将地址换成 `socks5h://127.0.0.1:18082`。这里的端口只是示例，必须与对应页面一致。

## 独立 macOS / Windows 应用与默认端口

PortWeave 在 **macOS**（`PortWeave.app`，支持 macOS 12 及以上 Apple Silicon `arm64` 与 Intel `amd64`）与 **Windows**（`PortWeave.exe`，提供 x64 安装包与便携 ZIP）均以独立身份打包，具有各自独立的图标、数据目录、偏好设置、URL 协议（`portweave://`）和开机自启项，可与 FlClash 并存安装而不相互覆盖。初次使用需自行导入订阅或备份。

| 设置 | 默认值 |
| --- | --- |
| 普通混合代理端口 | `7891` |
| 外部控制接口 | 默认关闭；开启后监听 `127.0.0.1:9091`，未设置密钥时自动生成 |
| 新建订阅绑定 | 从 `18082` 开始，跳过已有绑定占用的端口 |
| DNS 监听 | 默认关闭；编辑器示例使用 `1054` |
| macOS Release / Profile Bundle ID | `io.github.minggle.portweave`（Debug 使用 `.debug` 后缀） |
| Windows 数据目录 | `%APPDATA%\io.github.minggle\PortWeave` 与 `%LOCALAPPDATA%\io.github.minggle\PortWeave` |
| Windows 安装包与主程序 | 独立 Inno Setup `AppId` 与 `PortWeave.exe`（与 FlClash 并存隔离） |
| 注册的 URL 协议 | `portweave://` |

导入备份时保留其中明确设置的端口；网络端口表单的“重置”可恢复 `7891`。系统代理、TUN 与监听端口仍是主机共享资源，与其他客户端同时运行时应使用专用多端口模式并避开端口冲突。

## 下载与更新

请前往 [GitHub Releases](https://github.com/Minggle/PortWeave/releases/latest) 下载最新版本。每次发布同时提供 macOS 与 Windows 产物及统一的 `SHA256SUMS` 校验文件：

| 平台 | 产物文件名 | 说明 |
| --- | --- | --- |
| macOS（Apple Silicon） | `PortWeave-<版本>-macos-arm64.dmg` | 打开 DMG 后将 `PortWeave.app` 拖入 Applications |
| macOS（Intel） | `PortWeave-<版本>-macos-amd64.dmg` | 打开 DMG 后将 `PortWeave.app` 拖入 Applications |
| Windows（x64 安装包） | `PortWeave-<版本>-windows-amd64-setup.exe` | Inno Setup 安装程序，与 FlClash 并存隔离 |
| Windows（x64 便携版） | `PortWeave-<版本>-windows-amd64.zip` | 完整解压后运行 `PortWeave.exe` |
| 校验文件 | `SHA256SUMS` | 覆盖全部 4 个发布产物 |

安装前请核对 `SHA256SUMS`：

```bash
# macOS
shasum -a 256 -c SHA256SUMS --ignore-missing
```

```powershell
# Windows（PowerShell）
Get-FileHash .\PortWeave-<版本>-windows-amd64-setup.exe -Algorithm SHA256
Get-FileHash .\PortWeave-<版本>-windows-amd64.zip -Algorithm SHA256
```

- **macOS**：退出已安装的 PortWeave，打开 DMG，将 `PortWeave.app` 拖入 Applications，再由用户启动。采用手动下载安装，Developer ID 签名与 Apple 公证尚未完成。
- **Windows**：运行 `-setup.exe` 安装或覆盖升级；便携版需完整解压 `.zip`（保留 `PortWeave.exe`、`FlClashCore.exe`、`FlClashHelperService.exe`、DLL 及 `data/` 目录）。
- **CI 测试构建**：`main` 分支的开发构建也会上传至 [PortWeave - macOS](https://github.com/Minggle/PortWeave/actions/workflows/ports-macos.yaml) 与 [PortWeave - Windows](https://github.com/Minggle/PortWeave/actions/workflows/ports-windows.yaml)（下载 Actions artifact 需登录 GitHub，保留 1 天）。

## 当前限制

- 多订阅端口仅监听 IPv4 回环，不支持 UDP、局域网共享或按进程接管。
- 端口来源需包含顶层代理节点；嵌套 `proxy-providers`、直连类型节点、同一来源内的重复名称及 `dialer-proxy` 代理链会被拒绝。不同来源中的同名节点保留来源标识。
- “已监听”只代表端口归当前 Core 所有且 SOCKS 握手成功，不代表公网出口或业务访问已验证。

## 开发与验证

使用 Flutter **3.50.0**、Go **1.27**、通过 rustup 安装的 Rust，以及 macOS 上的完整 Xcode。仅安装 Command Line Tools 无法编译应用；子模块使用 SSH 地址，递归克隆前需配置 GitHub SSH 访问。

```bash
git clone --recursive https://github.com/Minggle/PortWeave.git
cd PortWeave
flutter pub get
flutter analyze --no-fatal-infos
flutter test test/common/port_routing_test.dart test/providers/port_routing_action_test.dart test/views/port_routing_test.dart
flutter test test/common/priority_policy_test.dart test/providers/priority_policy_action_test.dart test/views/priority_policy_test.dart
CGO_ENABLED=0 go test -C core . -run '^Test(PortRouting|PriorityPolicy)Wire$' -count=1
```

本机 GUI 开发使用安全模式：

```bash
flutter run -d macos --dart-define-from-file=env.json --dart-define=SAFE_MODE=true
```

安全模式不修改主机网络，也不开放代理监听，因此不能用它验证真实代理流量。全套 Flutter 测试使用 `dart run tool/test.dart`；应用测试使用 `flutter test`，不要使用 `dart test`。修改模型、provider 或数据库后执行 `dart run build_runner build --delete-conflicting-outputs`。打包时保持原生 build hooks 开启。完整命令与待验证清单见[开发命令](.agents/commands.md)、[端口维护说明](PORT_ROUTING.md)和 [Mac 开发记录](MACOS_DEVELOPMENT.md)。

## 来源与许可证

PortWeave 基于 [FlClash](https://github.com/chen08209/FlClash) 改造，使用 Flutter 与 mihomo（Clash.Meta）内核。原 FlClash 作者（`com.follow`）及贡献者保留其作品的署名与版权，PortWeave 的改造由 Minggle 维护。本项目继续遵循 [GPL-3.0](LICENSE)，保留原有版权声明及第三方许可证。
