<div align="center">

<img src="assets/images/portweave/icon.png" alt="PortWeave" width="88">

# PortWeave · 端流

面向 macOS 的代理客户端，让不同应用通过独立本地端口使用不同订阅。

[English](README.md) · **简体中文**

[代码仓库](https://github.com/Minggle/PortWeave) · [测试构建](https://github.com/Minggle/PortWeave/actions/workflows/ports-macos.yaml) · [使用与开发说明](PORT_ROUTING.md) · [构建进度](MACOS_DEVELOPMENT.md)

</div>

PortWeave 可以同时使用多个订阅：为每个应用分配本地代理地址，沿用订阅原有规则、指定固定节点，或从多个选定订阅中按关键词聚合节点。普通配置还支持策略优先级，让自建线路作为主用、订阅节点作为逐级备用。

**开发版本：0.9.4 · Flutter 3.50.0**（2026-11-23）。人工安装与真实网络验收尚未完成，进度及验证记录见 [Mac 开发记录](MACOS_DEVELOPMENT.md)。

## 选择分流方式

| 方式 | 用途 | 操作入口 |
| --- | --- | --- |
| 多订阅端口 | 每条绑定在 `127.0.0.1` 提供独立的 HTTP / HTTPS CONNECT / SOCKS5 TCP 端口 | **工具 → 多订阅端口** |
| 沿用原有策略 | 使用一个订阅的原始规则、策略组和已保存组选项，与其他订阅的规则隔离 | 为端口绑定选择“沿用原有策略” |
| 固定节点 | 使用一个订阅中名称完全匹配的节点 | 为绑定选择节点 |
| 关键词聚合 | 从一个或多个选定订阅中筛选节点，并按延迟自动选择 | 勾选来源，输入 `US\|美国` 等关键词 |
| 策略优先级 | 保留普通配置的分流规则，为指定业务组添加有序主备层级 | **工具 → 策略优先级** |

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
| 应用 C | `http://127.0.0.1:18084` | 从订阅 A、B 聚合匹配 `US\|美国` 的节点 |

每个端口同时支持上述三种 TCP 代理协议。若应用分别填写服务器和端口，服务器填 `127.0.0.1`，端口填绑定中的数字。应用需要支持手动设置代理；专用模式不按进程接管流量。

开启专用模式会切入受管理的配置，并在运行时关闭系统代理、TUN、控制接口和默认混合端口，保留这些功能的保存值。关闭后恢复此前配置；选择其他普通配置也会退出专用模式。PortWeave 自身下载在此模式下直连。

右键绑定可复制地址、立即更新订阅或调整更新间隔。每个订阅默认每 5 分钟更新，程序运行时每 30 秒检查到期任务。固定节点与关键词来源采用局部更新，失败保留最后可用缓存；涉及原策略绑定的来源更新会重新应用受管理配置，可能短暂重连。

## 自建主用，订阅备用

打开**工具 → 策略优先级**，选择未关联脚本的普通配置作为底稿，再选择已有业务组。将底稿中的组／节点与订阅层按优先级排序，例如：

```text
视频组 → 台湾自建组 → 所选订阅中的 US 节点 → 其他备用层
```

每个订阅层可选择多个来源，设置包含／排除关键词并预览匹配结果。高层探测可用时始终优先；低层不会因为延迟更低而抢占高层，订阅层内部自动优选。探测间隔为 60 秒，高层恢复后新连接回切，已有连接不保证无缝迁移。

在**配置**页选中底稿并使用**规则模式**。此功能作用于普通代理路径，可按需开启系统代理或 TUN。策略设置独立保存，不覆盖源文件；删除增强策略即可恢复原组。订阅更新后重新计算候选。只有明确配置在层级或底稿规则中的直连才会生效。

## 独立 macOS 应用与默认端口

macOS 应用为 **`PortWeave.app`**，具有独立图标、数据、偏好、缓存和登录项。构建目标为 macOS 12 及以上，覆盖 Apple Silicon（`arm64`）和 Intel（`amd64`）；实际验收状态见 [Mac 开发记录](MACOS_DEVELOPMENT.md)。可与 FlClash 同时安装，初次使用需自行导入订阅或备份。

| 设置 | 默认值 |
| --- | --- |
| 普通混合代理端口 | `7891` |
| 外部控制接口 | 默认关闭；开启后监听 `127.0.0.1:9091`，未设置密钥时自动生成 |
| 新建订阅绑定 | 从 `18082` 开始，跳过已有绑定占用的端口 |
| DNS 监听 | 默认关闭；编辑器示例使用 `1054` |
| Release / Profile Bundle ID | `io.github.minggle.portweave` |
| Debug Bundle ID | `io.github.minggle.portweave.debug` |
| 注册的 URL 协议 | `portweave://` |

导入备份时保留其中明确设置的端口；网络端口表单的“重置”可恢复 `7891`。系统代理、TUN 与监听端口仍是主机共享资源，与其他客户端同时运行时应使用专用多端口模式并避开端口冲突。

源码仍保留其他平台，包括早期 Windows 多订阅端口构建；当前 PortWeave 产品与交付说明以 macOS 为中心，旧 Windows 包见[发布历史](RELEASE_PORTS.md)。

## 下载与更新

打开 [PortWeave - macOS](https://github.com/Minggle/PortWeave/actions/workflows/ports-macos.yaml)。仓库为公开状态，下载 Actions artifact 需按 GitHub 要求登录，并具有仓库读取权限。维护者可通过 **Run workflow** 选择分支手动构建。

选择目标提交对应的成功运行，在 Artifacts 中下载匹配架构的产物。构建流程输出 `PortWeave-<版本>-macos-<架构>.dmg` 和 `SHA256SUMS-macos-<架构>`。解压 artifact 后，在同一目录校验对应文件，例如：

```bash
shasum -a 256 -c SHA256SUMS-macos-arm64
```

Artifacts 一天后到期，每个平台仅保留最新运行的产物，请及时下载需要的文件。

退出已安装的 PortWeave，打开 DMG，将 `PortWeave.app` 拖入 Applications，再由用户启动。**关于 → 下载测试版本**也会打开构建列表。更新采用手动下载、手动安装，macOS 启动时不查询 Releases，也不自动替换应用。当前提供开发构建，Developer ID 签名与 Apple 公证尚未完成。

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
