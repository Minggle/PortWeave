# PortWeave（端流）Mac 开发计划与进度

更新日期：2026-11-23。当前主工作区为仓库根目录 `.`，开发分支 `main`，交付构建提交 `ac80b820`；升级起点为 `486b5c9b`。源码版本 `0.9.4+2026110401`，Flutter `3.50.0`。

## 当前进度

0.9.4 两项兼容修复与本地验证已完成：脚本模式旧规则在数据库迁移和旧备份恢复后继续禁用；脚本出口随订阅／文件配置更新时间变化而失效重算，并覆盖旧计算仍在等待时发生刷新的竞态。依赖解析、代码生成、静态分析、全套 5,214 项 Flutter 测试及 PortRouting／PriorityPolicy Go wire 测试通过。

`ac80b820` 的 ARM64 包已完成全套测试、打包、下载后 SHA256／DMG／身份／ARM64 架构／bundle 签名检查，并安装为本机 `PortWeave.app` 0.9.4。旧 0.9.3 应用备份位于 `dist/installed-backups/PortWeave-0.9.3.app`，未启动普通模式，真实网络由用户测试。CI 跟进提交 `a0a35b73` 只修复历史标签获取和 Helper 测试隔离，不改变已安装包的应用代码。

2026-11-23 的 GitHub API 查询返回 `private:false`，仓库当前为公开状态。早期私有化记录保留在 M7 历史段落中。Mac 继续通过 Actions 手动下载，artifact 按 GitHub 要求登录并具有读取权限；仓库公开不改变应用的手动更新策略。

远程已成功更名为 `Minggle/PortWeave`，`origin` 已更新为 `https://github.com/Minggle/PortWeave.git`。工作已整合回原主工作区，`ac80b820` 已提交并推送到 `main`；临时升级工作区已删除，本地及 origin 的开发分支仅保留 `main`。原有修改的 stash 备份保留，未应用或删除。内部 Bundle ID `io.github.minggle.portweave` 保持不变。

## 历史开发基线（2026-11-10）

以下保留此前开发进度。原 `feature/multi-subscription-ports` 基线固定到 [`f2b03c06`](https://github.com/Minggle/PortWeave/tree/f2b03c06)，应用版本 `0.9.3+2026110401`；本页后续 M0—M9 的通过项均指所列旧提交。

上游已具备 macOS Runner、菜单栏、窗口、系统代理、DNS 恢复、Core 生命周期及 ARM64/Intel 构建配置。
当前分支已实现多订阅独立端口的模型、配置生成、局部订阅更新、失败回退和管理页面。
Mac 已独立命名为 PortWeave（端流），主代理默认 7891；本页记录 Mac 验证，Windows 的历史记录见 `PORT_ROUTING.md`。

此前已补齐 Mac 工具页入口与 `lsof` 监听归属查询，修复原先 Mac 空归属表导致的端口冲突误报。
状态检查现在区分查询失败、无监听与其他进程占用，并丢弃停机或较新检查之后到达的旧结果。
窗口恢复和可见窗口的定时检查会更新状态；隐藏期间继续订阅更新。另已加入 ARM64/Intel DMG 构建流程。

当时开发主机为 Apple Silicon，已在临时目录准备 Flutter 3.47.6、Dart 3.13.5、Go 1.27.1、Rust 1.99.0。
当时仅有 Command Line Tools，缺少完整 Xcode，本机 Release 命令已确认因此不能编译；这项历史阻塞不作为当前工具链状态的结论。
原始工作区存在大量 CRLF/LF 和文件模式差异；后续开发在独立 worktree `codex/macos-subscription-ports` 完成，原始工作区变更保留。

## 开发顺序与验收

| 阶段 | 任务 | 完成标准 | 状态 |
| --- | --- | --- | --- |
| M0 | 核对源码、历史与工具链，记录开发计划 | 区分已有功能、移植缺口与验证阻塞 | 已完成 |
| M1 | Mac 多端口入口与监听归属检查 | Mac 可进入管理页；解析实际监听 PID；拒绝其他进程占用；保留 Windows 行为 | 已实现，专项测试通过 |
| M2 | 状态恢复与 Mac 回归 | 检查失败显示可靠状态；停机/重启不显示过期结果；系统代理、TUN、DNS 保存值保持可恢复 | 已实现，自动化回归通过；系统实机验收待完成 |
| M3 | fork 的 Mac 构建交付 | ARM64、Intel 分别测试与 Release 构建，输出 DMG 和各自校验文件；保留当时 Intel Impeller 配置 | 两架构测试、Release 编译、DMG 打包和上传均通过 |
| M4 | 使用文档与完整验收记录 | 操作入口、安装/更新、验证命令和未验收范围清晰；记录实际执行结果 | 已完成本轮开发记录；人工验收范围见清单 |
| M5 | PortWeave 独立 Mac 品牌 | 应用、包名、Bundle ID、网址协议、图标及数据独立；完成两架构重新构建 | 已完成，双架构构建与下载后验收通过 |
| M6 | 测试版默认监听端口错开原版 | 主代理 7891、控制接口 9091、多端口绑定起点 18082；重置入口和配置提示一致 | 已完成，4,912 项全套测试及双架构验收通过 |
| M7 | 私有仓库更新与个人分发（历史） | 当时仓库为 Private；Mac 手动下载入口需登录；不自动请求匿名 Release API | 当时已完成；4,917 项测试、双架构构建/包校验、ARM64 安全启动通过；当前仓库已公开 |
| M8 | 多订阅聚合与原策略绑定 | 原规则空间隔离、关键词多选来源、保存失败保留表单、REALITY short-id 原文保留 | 4,928 项 Flutter 测试、Core 回环、真实配置解析及两架构构建通过 |
| M9 | 普通配置策略优先级 | 保留底稿分流规则；自建主用与多个动态订阅备用可排序；订阅更新自动重算候选 | 已完成；4,943 项测试、双架构构建/包校验及 ARM64 安全启动通过 |
| M10 | 0.9.4 升级与整合（2026-11-23） | Flutter 3.50.0；迁移和脚本出口修复；PortWeave 文档／仓库入口；工作整合到 main；最新包验收 | 已完成；ARM64 安装，a0a35b73 通用 CI、Windows 和 Mac 双架构构建通过 |

M0—M9 保留此前自动化与打包验收记录；其中真实配置解析不等于真实公网流量验收，安全模式启动不等于用户安装验收。M10 单独记录本轮未完成项。历史出现的 bundle 签名校验只检查当时包的完整性，不代表 Developer ID 签名或 Apple 公证。

## 实现约束

- 复用单一 Core、已有 PortRoutingAction 和配置合成；桌面进程始终由 `lib/core/desktop/` 管理。
- 多端口只监听 IPv4 回环，支持 HTTP、HTTPS CONNECT、SOCKS5 TCP；固定节点丢失或区域候选为空时拒绝连接。
- 专用模式继续关闭有效系统代理、TUN、DNS 改写和默认混合端口，保留用户设置。
- GUI 在开发主机上只使用 `SAFE_MODE=true`；真实流量通过独立 Core 回环测试验证。完整公网及系统接管验收由用户在测试环境运行。
- 代码修改遵循 `core-platform`、`ui-work` 技能。模型/provider 定义变化后运行生成器；生成文件不手改。
- Mac 包未经过签名、公证或真实安装验证前，明确标为测试构建；不宣称正式发布。

## 历史验证清单（M7，非 0.9.4）

- [x] `flutter pub get`：使用原锁文件，未升级依赖。
- [x] `flutter analyze --no-fatal-infos`
- [x] 当时本地全套 Flutter 测试：4,917 项通过，含模型、provider、页面、Core、插件、widget 和 lint（`tool/test.dart` 调用 `flutter test`）。
- [x] 当时私有更新入口专项测试：50 项；中英文关于页截图渲染检查通过。
- [x] `CGO_ENABLED=0 go test -C core . -run '^TestPortRoutingWire$' -count=1`
- [x] `CGO_ENABLED=0 go vet -C core . ./cmd/...`
- [x] 新 workflow 的 `actionlint` 和打包脚本的 `bash -n`。
- [x] Mac ARM64 Release 编译、产物内容和 DMG 检查：云端构建成功；下载后 SHA256、DMG 完整性、GUI/Core/Rust/SQLite 的 ARM64 架构及 bundle 签名均通过。
- [x] Mac Intel Release 编译、签名/架构检查和 DMG 打包：云端构建通过；下载后 SHA256、DMG 完整性及 GUI/Core/Rust/SQLite 的 x86_64 架构检查通过，确认 `FLTEnableImpeller=false`；Intel 硬件的运行体验待人工验收。
- [x] ARM64 安全模式启动：`f814efe` 的 `io.github.minggle.portweave.debug` 应用及 Core IPC 成功启动；启动和退出前后系统代理/DNS 快照一致，Core 无 TCP 监听，无匿名更新错误；记录 PID 后结束测试，GUI/Core 均退出。
- [ ] 安全模式 GUI 点击验收：早期检查时 Mac 锁屏，后续界面读取工具超时；菜单入口和表单已有自动化 widget 测试通过。
- [ ] 测试环境：真实订阅、两个应用的出口隔离、睡眠唤醒、网络切换、退出后的系统状态恢复

完整 Xcode 是本机 Flutter macOS 原生编译的外部前提。未通过的检查保持未勾选，并记录具体原因。

## 应用身份与历史交付

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

- 开发分支：`codex/macos-subscription-ports`；[草稿 PR #1](https://github.com/Minggle/PortWeave/pull/1)。
- [完整跨平台 CI](https://github.com/Minggle/PortWeave/actions/runs/42575216818) 在 `37d171d` 上通过，包含 Dart 全套、插件、Go、Rust、Android 单元测试和三桌面平台 Debug 编译。
- [Mac 双架构构建](https://github.com/Minggle/PortWeave/actions/runs/42620141996) 产出独立 DMG、`SHA256SUMS-macos-*` 和单独的 ARM64 安全模式调试包。
- 本机产物保存在 `dist/portweave-f814efe/arm64/`、`dist/portweave-f814efe/amd64/` 和 `dist/portweave-f814efe/safe-mode/`；验收日志与中英文截图位于 `dist/portweave-f814efe/validation/`；这些构建输出不提交 Git。
- 当时构建是开发测试包，应用数字版本为 `0.9.3`，该轮未创建或发布版本标签；当前源码已为 `0.9.4`，最新包另行验证。
- Developer ID 签名、公证、Gatekeeper 首次安装、Intel 实机运行、真实订阅公网出口以及睡眠/网络切换验收尚未完成。
- 后续优先级：先完成上述实机验收及签名分发，再基于大量绑定/订阅下的实际测量优化状态列表和后台能耗；不预先更换 Core 生命周期或重写现有 UI。
- 仓库在 2026-11-09 曾设为 **PRIVATE**，当时 GitHub 读取确认 `isPrivate=true`，该阶段只向此私有仓库推送。2026-11-23 最新读取为 `private:false`，旧记录不再描述当前可见性。
- 因当时私有仓库无法匿名查询更新，M7 将 Mac 关于页改为“下载测试版本”，通过浏览器登录 GitHub 下载构建，并关闭自动查询入口。应用不存储 GitHub 令牌；该手动下载策略沿用至当前公开仓库。

M7 验证：依赖锁文件未变化，代码与本地化生成器运行成功，静态分析、50 项专项测试及全套 4,917 项测试通过。Mac 更新策略由 `lib/common/app_update.dart` 统一提供；关于页、自动查询和设置入口复用同一策略。ARM64/Intel 最终包的 SHA256、DMG 完整性、Bundle ID/协议、GUI/Core/各框架架构、签名和全部 25 个图标资源验证通过。ARM64 安全模式启动通过，见上述清单。当时私有仓库分支推送时完整跨平台 CI 按既有规则跳过；该轮使用本地全套测试和双 Mac CI 验证，没有将跳过视为通过。

## 下一阶段实机验收

| 场景 | 操作 | 通过条件 |
| --- | --- | --- |
| 并行安装 | 将对应架构的 `PortWeave.app` 拖入 Applications，保留原 FlClash；首次启动检查网络设置 | 应用、图标和数据独立；普通混合代理默认 7891；旧备份的显式端口需自行检查或重置 |
| 两个订阅出口 | 在 PortWeave 导入两个真实订阅，分别绑定空闲的 18082、18083 并开启专用模式；两个客户端分别连接对应端口 | 两个客户端使用各自选择的节点；修改一条绑定不改变另一条的订阅归属 |
| 订阅刷新 | 保持一个客户端连接，更新另一条绑定对应的订阅，再检查节点消失和空候选情况 | 固定／关键词局部更新不关闭其他订阅连接，空候选拒绝连接；原策略更新需重应用配置，允许短暂重连并保留原规则的直连行为 |
| 睡眠和网络切换 | 连接后睡眠/唤醒、切换 Wi-Fi，再显示应用窗口 | 状态重新检查，归属正确；无旧检查结果覆盖新结果，定时订阅更新恢复 |
| 退出恢复 | 专用模式下退出 PortWeave，对照启动前记录检查系统代理/DNS，并确认原 FlClash 仍可使用 | PortWeave Core 与监听退出，原应用的代理/DNS设置保持一致 |
| Actions 下载 | 按 GitHub artifact 下载要求登录，打开“关于 → 下载测试版本” | 进入构建列表，选择目标提交的成功构建并下载对应架构；当前仓库公开，应用仍不自动查询 Releases |

以上真实网络和安装操作由用户在测试环境执行。Developer ID 签名及公证需要 Apple Developer 分发身份，待提供后单独验收 Gatekeeper 首次安装行为。

## M8 用户反馈修订

本机三个订阅节点经同版本 Core 解析均可用；应用系统日志没有保留具体表单失败内容。只读复现确认 `auto-config.yaml` 中一个未加引号的 REALITY short-id 被 Dart YAML 当作科学计数法并溢出，导致 JSON 编码失败。现按 YAML 标量原文保留 short-id，覆盖前导零、指数形状和非有限值。用户订阅和凭据仅用于本机临时解析，未提交。

新增绑定默认“沿用原有策略”；关键词模式可多选订阅，匹配计数和预览包含来源。原策略与跨订阅聚合已用用户三个来源在本地合成并经 Core 解析，包含 145 个节点/组和 3 套规则空间。固定/关键词更新仍局部加载；原策略更新重应用配置并支持失败恢复。保存成功才关闭表单，失败保留输入，日志仅记录操作、来源数量和错误类别。

M8 验证：依赖解析未改锁文件，代码/本地化生成及静态分析通过，全套 4,928 项 Flutter 测试、Core 回环 `TestPortRoutingWire` 与 Go vet 通过。原策略/双来源关键词表单做了中文深色截图检查。旧单来源绑定可读取，聚合绑定备份恢复时重映射全部来源；缺失来源时丢弃整条绑定，不悄悄改变候选范围。

M8 应用提交为 `e3adfaa`，[双架构构建](https://github.com/Minggle/PortWeave/actions/runs/42645186035)。ARM64 编译及本机 DMG/标识/架构/签名/图标检查通过；新包保存在 `dist/portweave-e3adfaa/arm64/`，截图与验收日志在 `dist/portweave-e3adfaa/validation/`。ARM64 安全模式已连接 Core IPC，Core 无 TCP 监听，代理/DNS 保持一致，测试 App/Core 退出。Intel 编译/打包、下载后 SHA256、DMG 完整性、独立应用身份、x86_64 架构、签名、Impeller 设置和图标资源检查全部通过，新包位于 `dist/portweave-e3adfaa/amd64/`。

## M9 普通配置策略优先级

入口为“工具 → 策略优先级”。先选择普通标准配置作为底稿，为已有业务策略组添加有序层级：本地层引用底稿中的组/节点，订阅层多选来源并设置包含/排除关键词（`|` 分隔、忽略大小写；包含留空匹配全部）。层级越靠上优先级越高，右键或长按可上移、下移、删除。新增策略默认沿用业务组的首个候选作为主用，可编辑。不会自动写入用户正在使用的配置。

编译仅替换目标业务组，规则保持原目标名。层级间使用 fallback，订阅层内用 url-test；每 60 秒探测，较高优先级恢复后后续新连接回切。未测量/过期探测状态需要收敛，不能承诺一次失败请求无缝重试；探测可用不等于业务账号、地区限制验证。DIRECT 只有作为明确层级或底稿原规则存在时才生效。

策略设置单独持久化，删除后恢复源组定义。需在“配置”页选中底稿并使用规则模式；本功能作用于普通混合代理/正常运行路径，多端口工作区保持原行为。引用中的来源不可删除，备份恢复校验并重映射全部来源。来源更新先校验节点，更新被引用订阅后重新应用当前底稿，候选增删无需重新设置策略。配置加载失败时恢复先前策略；不得用旧手动组选项固定住优先级链。

用户个人配置、订阅地址、节点凭据禁止上传，包括私有仓库、云端测试和 Bark。M9 测试及截图只使用本地虚构来源和节点，不保存个人配置副本到仓库。

M9 本地验证：依赖锁文件未变化；代码/本地化生成、静态分析、全套 4,943 项 Flutter 测试通过。新增 Core 主备回环测试覆盖自建优先、备用逐级回退、恢复回切、动态来源匹配消失/新增和全失败不直连。宽/窄中文深色布局采用虚构节点渲染验证，未读取个人配置生成测试附件。

M9 应用提交为 `26bc633`，[双架构 CI](https://github.com/Minggle/PortWeave/actions/runs/42744296620) 已通过。ARM64 包的 SHA256、DMG 完整性、应用标识、架构、签名与图标资源校验通过；安全模式启动 Core IPC 正常，无 Core TCP 监听，代理/DNS 保持一致，App/Core 测试进程已退出。安装包与虚构数据截图存放在 `dist/portweave-26bc633/`；Intel 包已通过 SHA256、DMG 完整性、独立应用标识、x86_64 架构、签名、`FLTEnableImpeller=false` 和 25 个图标资源一致性校验。应用代码保持 `26bc633`，后续验收文档提交不改变包内容。

### M9 保存时异步 Ref 释放修复

收到保存失败截图后，使用内存数据库延迟查询复现 `UnmountedRefException`。原因是优先级依赖在数据库查询之后才 `ref.watch`，而未观察的异步 provider 可在查询期间被释放；查询期间的优先级变化也未及时触发重建。修复将此依赖读取与订阅移到第一次异步等待之前。新增测试分别覆盖自动释放后完成、等待期间修改优先级后仅发布新状态，以及撤回优先级。修复前两项均失败，修复后通过；Mac CI 已加入该测试套件。不读取或上传个人配置。

该修复本地全套 4,945 项 Flutter 测试、静态分析、格式和 actionlint 通过。应用提交 `e176c6f` 的 Intel CI 与下载验收通过；ARM64 首次因 hosted runner 容量不足、未分配 runner 而取消。打包矩阵的 ARM64 改用 `macos-15`（Apple Silicon，已核对包含 Xcode 26.3/26.2），应用代码不变；Intel 仍使用 `macos-15-intel`。

修复版构建提交 `97bbe54` 的 ARM64 在 `macos-15` 上通过分析、包含新增异步时序测试的回归、Release 打包及安全模式构建。下载后的 SHA256、DMG 完整性、Bundle ID/URL协议、各二进制 ARM64 架构、签名和 25 个图标资源一致性通过。安全模式 Core IPC 连接成功、无 TCP 监听、代理/DNS 未变化，测试 App/Core 均按记录 PID 退出。文件在 `dist/portweave-97bbe54/arm64/`，验收日志在同级 `validation/`；此提交相对 `e176c6f` 仅更改 CI 镜像和文档，应用修复相同。

最终 [修复版双架构 CI](https://github.com/Minggle/PortWeave/actions/runs/42840587707) 在 `97bbe54` 上全部成功；Intel 同样完成下载后 SHA256、完整性、Bundle ID/协议、x86_64、签名、Impeller 设置与图标资源校验。当时两份修复包位于 `dist/portweave-97bbe54/{arm64,amd64}/`。版本号为 0.9.3，安装时以此构建目录区分旧包。个人配置未读取、未上传；该轮回归只使用内存数据库与虚构策略。

## M10：2026-11-23 本地验证完成，交付进行中

源码版本 `0.9.4+2026110401`，Flutter `3.50.0`，升级起点为 `486b5c9b`。本轮已修复并通过回归：

- 脚本模式旧附加规则在数据库迁移及旧备份恢复后保持禁用，避免升级后意外叠加到脚本结果。
- 脚本出口 provider 观察订阅／文件配置的更新时间，刷新后重新计算出口及 MATCH 目标；旧计算尚在等待时发生刷新，旧结果不会覆盖新状态。

本地验证：`flutter pub get`、`dart run build_runner build --delete-conflicting-outputs`、`flutter analyze --no-fatal-infos` 通过；`dart run tool/test.dart` 调用 Flutter 执行的全套 **5,214 项测试全部通过**；Go `TestPortRoutingWire` 与 `TestPriorityPolicyWire` 通过。构建及 CI 后续状态单独记录如下。

工作已合并回原主工作区并以 `ac80b820` 推送 `main`，临时升级工作区已删除。本地与 origin 开发分支清理后仅保留 `main`，原有修改仍保留在 stash 备份中。远程已更名为 `Minggle/PortWeave`，`origin` 同步更新，仓库保持公开（`private:false`）。文档和下载入口使用新地址，内部标识 `io.github.minggle.portweave` 不改。

workflows 已更新为 `PortWeave - macOS`／`PortWeave - Windows`，支持 `main` 推送、`v*` 标签和手动触发。macOS 手动输入 `safe_mode` 默认 `false`，启用后额外构建 ARM64 安全模式包。每个平台只保留最新 run 的 Actions artifact，保存一天；上传预算合计 450 MB，其中 macOS ARM64 为 250 MB（含可选安全模式包），macOS Intel、Windows 各 100 MB。各 job 及产物验证状态分别记录，不将单个 job 成功视作整套 workflow 通过。

### 今日 CI 与产物状态（ac80b820）

| 范围 | 已确认结果 | 当前状态 |
| --- | --- | --- |
| macOS ARM64 | job 成功，全套 5,214 项 Flutter 测试通过，打包产物 63.3 MB 已上传 | 下载后校验完成，已安装供用户测试 |
| macOS Intel | Release 与打包完成 | `a0a35b73` 双架构 workflow 通过 |
| 通用 Dart changelog 检查 | 初次 CI 缺少上游历史 tag | `a0a35b73` 在 CI 补取缺失上游标签；通用 CI 全部通过 |
| Windows 模拟 Helper 测试 | 初次模拟客户端读取真实 Registry，触发 Rust 未初始化 | `a0a35b73` 固定模拟服务地址；Windows 测试与 Release 打包通过 |

以上失败修复后远端重跑已通过；当前安装包的应用代码不受这两项 CI 修复影响。`a0a35b73` 的三份最新 artifact 总计约 194.8 MB，低于 500 MB 配额。

### 本轮验收清单

源码核对：外部控制接口默认关闭，开启后仅监听 `127.0.0.1:9091`，密钥为空时自动生成。macOS 工程的最低部署目标为 `12.0`，分 Apple Silicon／Intel 构建；该配置不等于全部系统版本与设备均已实测。

- [x] 两项修复及数据库／备份／脚本出口回归通过，包含订阅、文件与 pending 竞态场景。
- [x] 依赖解析、代码生成、静态分析通过，全套 Flutter 测试 5,214 项通过，PortRouting／PriorityPolicy Go wire 通过。
- [x] 整合回原主工作区并推送 `main`；删除临时升级工作区，清理本地及 origin 其他开发分支，保留原有 stash 备份。
- [x] 远程更名为 `Minggle/PortWeave`，更新 `origin`，仓库保持公开。
- [x] 更新 macOS／Windows workflow 名称、触发条件、安全模式选项与 artifact 保留／容量规则。
- [ ] 集成后验证应用下载入口与 Actions 执行结果。
- [x] `ac80b820` ARM64 job 完成全套 5,214 项 Flutter 测试、Release 打包及 63.3 MB 产物上传。
- [x] Intel job 完成，Release 和 DMG 构建通过。
- [x] 通用 Dart changelog 历史标签问题修复后通过 CI。
- [x] Windows 模拟 Helper Registry／Rust 初始化问题修复后通过回归。
- [x] ARM64 包完成 SHA256、DMG、应用身份、主要二进制架构及 bundle 签名校验，安装为本机 0.9.4。
- [ ] Intel 成功产物下载后完成同等校验。
- [ ] 安全模式启动，记录 PID，确认系统代理／DNS 不变且 Core 不开放 TCP 监听。
- [ ] 用户启动已安装的最新包，验收真实订阅、双应用出口隔离、睡眠／网络切换及退出恢复。
- [ ] Developer ID 签名、Apple 公证与 Gatekeeper 首次安装验收。

以下为开发验证命令；本轮已执行结果以上方记录为准，未勾选项不代表通过：

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test test/database/migration_v1_to_v2_test.dart test/common/backup_task_test.dart test/providers/script_outbounds_test.dart test/providers/setup_state_test.dart
flutter test test/common/port_routing_test.dart test/providers/port_routing_action_test.dart test/views/port_routing_test.dart
flutter test test/common/priority_policy_test.dart test/providers/priority_policy_action_test.dart test/views/priority_policy_test.dart
CGO_ENABLED=0 go test -C core . -run '^Test(PortRouting|PriorityPolicy)Wire$' -count=1
CGO_ENABLED=0 go vet -C core . ./cmd/...
```

全套 Flutter 测试使用 `dart run tool/test.dart`，模型／provider／数据库修改后执行 `dart run build_runner build --delete-conflicting-outputs`。ARM64 构建示例：

```bash
FLUTTER_MACOS_ARM64_ONLY=true flutter build macos --release --build-name=0.9.4 --dart-define=APP_ENV=pre
bash tool/package_macos.sh 0.9.4-ports.1 arm64
```

Intel 在 Intel Mac 上构建，不设置 ARM64 专用变量，打包参数使用 `amd64`。Flutter 3.50 已默认在 Intel Mac 启用 Impeller，旧记录的 `FLTEnableImpeller=false` 不作为当前要求；SDK 相关约束见 [.agents/flutter-upgrade.md](.agents/flutter-upgrade.md)。版本后缀只是示例，不能据此推断已发布标签或产物。

共享主机的 GUI 调试仅使用 `flutter run -d macos --dart-define-from-file=env.json --dart-define=SAFE_MODE=true`。安全模式不开放代理端口，真实流量由用户在测试环境验证。M10 ARM64 包已完成本机安装，未启动普通模式。

## M11：独立端口页面与聚合代理

桌面“代理”下按绑定显示子页面，普通代理商与聚合代理各自拥有监听端口。聚合端口保留底稿规则，业务组主用／备用链存储在 `PortBinding.policies`，每个端口按绑定 ID 隔离节点、组和子规则。同一订阅可以用于不同端口，而不同端口的优先级和手动组选项互不覆盖。切换子页面会退出上一端口的编辑路由。

旧普通混合端口优先级入口保留在聚合总览内，可复制到聚合端口，复制后独立保存。普通混合端口与专用模式互斥；代理商端口与聚合端口同时运行。中英文 README 已补齐 `7891`、`18082`、`18084` 和控制端口 `9091` 的区别与切换步骤。

本地验证：代码／七语言本地化生成、静态分析通过；全套测试通过仓库 runner 的单文件重跑规则完成，编辑器测试的共享 isolate 初始化冲突在独立运行后通过。新增编译、备份引用、来源刷新、侧栏和表单测试通过；桌面导航 30 项通过。Core 回环覆盖聚合独立监听、主备回退与恢复、代理商端口隔离。虚构数据的中文深色页面已渲染检查。最终构建和安装结果待随后补记。

应用提交 `4c5a4272` 的通用跨平台 CI 和 Windows Release 构建通过。macOS ARM64 job 因 hosted runner 容量不足，排队后未获 runner 而取消；ARM64 镜像改为 `macos-26`，已核对官方镜像包含 Xcode 26.3/26.2，Intel 保持 `macos-15-intel`。该跟进不改变应用代码。

最终测试跟进提交 `b33f5804` 为 Core 回环断言等待首轮健康检查，连续 20 次通过；应用代码仍为 `4c5a4272`。该提交的[通用 CI](https://github.com/Minggle/PortWeave/actions/runs/45200552354)及 [Windows 构建](https://github.com/Minggle/PortWeave/actions/runs/45200551968)通过。[Mac 构建](https://github.com/Minggle/PortWeave/actions/runs/45200551951)的 ARM64 已通过完整测试、Release、DMG 打包和上传；Intel 首次在 Rust 下载时 DNS 失败，已单独重试。此前 `d4369032` 的 Mac 双架构构建均成功，应用代码一致。

新增功能专项 59 项、导航回归 30 项通过。实际 Dart 编译出的虚构聚合配置交给同版本 Core 解析成功，包含两个独立监听。中文深色截图和验证日志保存在 `dist/portweave-4c5a4272/validation/`。

最新 ARM64 包及 SHA256 位于 `dist/portweave-b33f5804/arm64/`，已通过下载后校验、DMG 完整性、Bundle ID/协议、GUI/Core/Flutter/App/Rust 的 ARM64 架构及 bundle 签名检查；可安装的 app 准备在 `dist/portweave-b33f5804/PortWeave.app`。用户正在运行此前安装的 PortWeave，因此没有替换或结束该进程；需用户退出后再安装此聚合代理版本。普通模式启动和真实网络验收由用户完成。
