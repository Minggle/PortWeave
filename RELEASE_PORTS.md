# PortWeave（端流）发布状态与历史

更新日期：2026-11-23。当前开发版本 `0.9.4`，Flutter `3.50.0`，ARM64 已安装供用户测试，真实网络验收尚未完成。升级、测试与最新包状态见 [Mac 开发记录](MACOS_DEVELOPMENT.md)。此页下半部分保留 Windows `v0.9.3-ports.1` 首版记录，其通过结果不代表 0.9.4 已通过。

本轮工作已归并回原主工作区，以 `ac80b820` 提交并推送 `main`；临时升级工作区已删除，本地及 origin 开发分支仅保留 `main`，原有修改的 stash 备份保留。

`ac80b820` 的 macOS ARM64 包已完成全套 5,214 项 Flutter 测试、打包、下载后 SHA256／DMG／身份／架构／bundle 签名校验，并已安装到本机。旧应用备份保存在 `dist/installed-backups/`，个人配置保持原位，应用由用户启动测试。双架构及 CI 后续结果统一见 [Mac 开发记录](MACOS_DEVELOPMENT.md)。

仓库已更名为 `Minggle/PortWeave`，`origin` 已更新，当前保持公开。Mac 沿用手动下载策略，**关于 → 下载测试版本**进入 [PortWeave - macOS](https://github.com/Minggle/PortWeave/actions/workflows/ports-macos.yaml)。下载 Actions artifact 需按 GitHub 要求登录并具有仓库读取权限；选择目标提交的成功运行。维护者可通过 **Run workflow** 选择分支手动构建。

Actions artifact 按平台仅保留最新 run，一天后到期；下载及预算规则见 [构建说明](PORT_ROUTING.md#macos-开发与构建)。

## macOS 产物与安装

最低部署目标为 macOS 12.0，Apple Silicon 和 Intel 分别输出 `PortWeave-<版本>-macos-arm64.dmg`、`PortWeave-<版本>-macos-amd64.dmg`，并附 `SHA256SUMS-macos-<架构>`。解压 artifact 后在同目录核对相应校验文件：

```bash
shasum -a 256 -c SHA256SUMS-macos-arm64
```

由用户退出已安装的 PortWeave、打开 DMG 并将 `PortWeave.app` 拖入 Applications 后启动。Mac 不自动替换应用，也不在启动时查询 Releases。当前没有完成 Developer ID 签名、公证或 Gatekeeper 首次安装验收；临时 bundle 签名检查不能替代这些步骤。

应用独立标识仍为 `io.github.minggle.portweave`，Debug 使用 `.debug` 后缀，注册 `portweave://`。普通混合代理默认 `7891`；控制接口默认关闭，开启后监听 `127.0.0.1:9091`，未设置密钥时自动生成；订阅端口从 `18082` 起分配。专用模式关闭有效系统代理、TUN、控制接口与默认混合端口，保留保存值。首次使用可导入订阅或备份；备份中的显式端口不会被默认值覆盖。

当前使用方式见 [中文 README](README_zh_CN.md) / [English README](README.md)，详细限制与验证命令见 [PORT_ROUTING.md](PORT_ROUTING.md)，完整 Mac 历史与待验收项见 [MACOS_DEVELOPMENT.md](MACOS_DEVELOPMENT.md)。

## 历史：多订阅端口版 v0.9.3-ports.1

以下记录基于上游 v0.9.3 的 Windows x64 预发行版本。它让多个应用通过不同的本地端口，同时使用不同订阅的代理节点。包名、端口示例、提交和验证结果按当时版本保留；仓库链接使用更名后的地址。

- 历史功能基线：[`f2b03c06`](https://github.com/Minggle/PortWeave/tree/f2b03c06)（原 `feature/multi-subscription-ports`）
- 发布下载：[`v0.9.3-ports.1`](https://github.com/Minggle/PortWeave/releases/tag/v0.9.3-ports.1)
- 完整使用与开发说明：[PORT_ROUTING.md](PORT_ROUTING.md)

### 历史使用方法

1. 下载 `FlClash-0.9.3-ports.1-windows-amd64.zip`，完整解压后运行 `FlClash.exe`。不要只复制单个 EXE，压缩包中的 Core、DLL 和 data 目录都是运行所需文件。
2. 在原有配置页面导入订阅。
3. 打开 **工具 → 多订阅端口**，为每个应用添加绑定，选择订阅、端口，以及固定节点或区域关键词。
4. 开启 **专用多端口模式**，在应用自身的代理设置中填写对应地址。

| 示例 | 代理地址 | 节点选择 |
| --- | --- | --- |
| 应用 A | `http://127.0.0.1:18081` | 订阅 A 的固定节点 |
| 应用 B | `socks5h://127.0.0.1:18082` | 订阅 B 中匹配 `HK\|香港` 的节点 |
| 应用 C | `http://127.0.0.1:18083` | 订阅 A 中匹配 `JP\|日本` 的节点 |

如果应用将服务器和端口分开填写，服务器填 `127.0.0.1`，端口填绑定中设置的数字。同一个端口支持 HTTP、HTTPS CONNECT 和 SOCKS5 TCP。

右键点击绑定可以复制地址、立即更新订阅、调整自动更新周期或删除绑定。每个订阅默认每 5 分钟检查更新；同一订阅可供多个端口使用。

### 首版新增

- 多订阅、多本地端口同时运行，节点名称按订阅隔离。
- 固定节点和按区域关键词自动选择；自动选择依据延迟，区域依据节点名称。
- 订阅局部热更新、并发请求去重、失败保留旧节点和缓存。
- 固定节点消失或区域候选为空时拒绝新连接，不跨订阅回退或自动直连。
- 专用模式使用现有单一 Core，运行时关闭系统代理、TUN 和默认混合端口；退出后恢复原有配置语义。
- 配置持久化、备份恢复、七种语言文本和 Windows 发布流程。

### 首版适用范围与验证

首版提供 Windows x64 ZIP，监听范围仅为本机 `127.0.0.1`，不支持 UDP、局域网共享或按进程接管。订阅需包含独立节点；嵌套代理集、代理链和重复节点名会被拒绝。

Windows Release 构建、Flutter 分析、相关集成和回归测试已完成。本地独立 Core 测试验证了 HTTP/SOCKS5 出口分离，以及更新一个订阅时另一个订阅持续连接保持正常。**真实订阅与公网出口尚未验收，因此首版标记为预发行。** “已监听”只表示端口归属与代理握手通过。

上游现有 Windows 全量测试中的路径与文件锁问题、各次测试结果，以及后续开发命令见 [验证记录](PORT_ROUTING.md#本次验证记录)。

发布包附带 `SHA256SUMS`。可在解压前使用 PowerShell 校验：

```powershell
Get-FileHash .\FlClash-0.9.3-ports.1-windows-amd64.zip -Algorithm SHA256
```

### 首版模块提交与上游同步

| 提交 | 内容 |
| --- | --- |
| `acc1a30` | 端口模型、持久化、配置生成和端口检查 |
| `a5de4ed` | 专用运行模式、订阅局部更新和恢复 |
| `ec9f789` | Windows 管理界面 |
| `d3751fe` | 格式整理 |
| `5b85ad4` | 独立 fork 发布流程与开发说明 |

首版发布时功能保留在 `feature/multi-subscription-ports` 分支，`main` 维持上游基线；当时 mihomo 与 prism_ui 子模块保持原提交，未改写原生生命周期。该分支安排仅为历史记录，以上源码链接固定到提交，不依赖旧分支继续存在。预发行包和 ZIP 便携版通过发布页手动更新。
