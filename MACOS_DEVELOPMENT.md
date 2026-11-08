# Mac 版本开发计划与进度

更新日期：2026-11-08。基线：`feature/multi-subscription-ports`，`f2b03c0`，应用版本 `0.9.3+2026110401`。

## 当前进度

上游已具备 macOS Runner、菜单栏、窗口、系统代理、DNS 恢复、Core 生命周期及 ARM64/Intel 构建配置。
当前分支已实现多订阅独立端口的模型、配置生成、局部订阅更新、失败回退、管理页面和 Windows ZIP 发布。
`PORT_ROUTING.md` 的测试记录来自 Windows；不能视为 Mac 验收记录。

本轮已补齐 Mac 工具页入口与 `lsof` 监听归属查询，修复原先 Mac 空归属表导致的端口冲突误报。
状态检查现在区分查询失败、无监听与其他进程占用，并丢弃停机或较新检查之后到达的旧结果。
窗口恢复和可见窗口的定时检查会更新状态；隐藏期间继续订阅更新。另已加入 ARM64/Intel DMG 构建流程。

当前主机为 Apple Silicon，已在临时目录准备 Flutter 3.47.6、Dart 3.13.5、Go 1.27.1、Rust 1.99.0。
仅有 Command Line Tools，缺少完整 Xcode，本机 Release 命令已确认因此不能编译。
工作区存在大量 CRLF/LF 差异及文件模式差异；开发保留这些原有变更，只提交本任务相关修改。

## 开发顺序与验收

| 阶段 | 任务 | 完成标准 | 状态 |
| --- | --- | --- | --- |
| M0 | 核对源码、历史与工具链，记录开发计划 | 区分已有功能、移植缺口与验证阻塞 | 已完成 |
| M1 | Mac 多端口入口与监听归属检查 | Mac 可进入管理页；解析实际监听 PID；拒绝其他进程占用；保留 Windows 行为 | 已实现，专项测试通过 |
| M2 | 状态恢复与 Mac 回归 | 检查失败显示可靠状态；停机/重启不显示过期结果；系统代理、TUN、DNS 保存值保持可恢复 | 已实现，自动化回归通过；系统实机验收待完成 |
| M3 | fork 的 Mac 构建交付 | ARM64、Intel 分别测试与 Release 构建，输出 DMG 和各自校验文件；保留 Intel Impeller 配置 | 流程已实现，等待 CI 构建 |
| M4 | 使用文档与完整验收记录 | 操作入口、安装/更新、验证命令和未验收范围清晰；记录实际执行结果 | 已更新，随构建结果补充 |

先完成 M1，再连续推进 M2—M4。以以上验收条件收敛本轮工作；后续新功能另列待办，不以无限增加功能代替完成。

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
- [x] 多端口、配置/备份、HTTP、DNS、桌面 Core 及页面测试：259 项通过，含 Mac 实际回环监听 PID 检查。
- [x] `test/widgets/` 与 `test/lint/`：1,021 项通过（`tool/test.dart` 调用 `flutter test`）。
- [x] `CGO_ENABLED=0 go test -C core . -run '^TestPortRoutingWire$' -count=1`
- [x] `CGO_ENABLED=0 go vet -C core . ./cmd/...`
- [x] 新 workflow 的 `actionlint` 和打包脚本的 `bash -n`。
- [ ] Mac ARM64 Release 编译、产物内容和 DMG 检查
- [ ] Mac Intel Release 编译和运行验收
- [ ] 安全模式 GUI：菜单入口、表单、复制地址、窗口恢复
- [ ] 测试环境：真实订阅、两个应用的出口隔离、睡眠唤醒、网络切换、退出后的系统状态恢复

完整 Xcode 是本机 Flutter macOS 原生编译的外部前提。未通过的检查保持未勾选，并记录具体原因。
