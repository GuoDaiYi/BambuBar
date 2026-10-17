# BambuBar

<p align="center">
  <img src="docs/zh/dashboard.png" width="360" alt="BambuBar 主面板">
</p>

<p align="center">
  <strong>原生 macOS 菜单栏拓竹打印机助手。</strong><br>
  实时进度、层数、预计时间与温度显示，一个只读的菜单栏监控器。
</p>


BambuBar 常驻 macOS 菜单栏，直接连接拓竹云账号，只负责显示进度、层数、预计时间和温度；控制仍交给 Bambu Handy 或 Bambu Studio。

界面支持 **简体中文 / 英文**，可在登录页右上角或设置中随时切换，选择会被记住。

---

## 功能

- **菜单栏进度环**：百分比、打印状态、在线状态一眼可见；图标为白色单色模板，自动适配菜单栏。
- **多打印机切换**：所有打印机在后台保持连接，在面板右上角切换菜单栏显示哪一台。
- **实时任务状态**：状态、进度、当前层/总层数、剩余时间、预计完成时间、速度档位、错误码。
- **下载 / 解压阶段**：打印开始前识别并显示「下载中 / 解压中」。
- **只读温度**：显示喷嘴、热床和模型风扇，不发送任何控制命令。
- **速度状态**：显示打印机当前处于静音 / 标准 / 运动 / 狂暴档位。
- **设置合并到主面板**：账号、语言、通知、开机启动、检查更新和退出都在同一个面板里。
- **中英文切换**：登录页和主面板都使用大尺寸分段按钮，整块可点击。
- **更新检测**：自动检查 GitHub Release，有新版本时显示下载提示。
- **主窗口自动收回**：主面板 10 秒无操作，或点击其他窗口/应用时自动收起；登录页和设置页面需要手动关闭。
- **系统通知**：打印完成或异常时发送 macOS 通知，并附带单色打印机图片。
- **Tabler 图标库**：内置 MIT 许可的线性图标。
- **开机启动**：可选 `SMAppService` 登录项。
- **无 Dock 图标、无第三方服务器**：SwiftUI + AppKit 原生实现。

## 截图

### 简体中文

| 主面板 | 登录 | 设置 |
| :---: | :---: | :---: |
| <img src="docs/zh/dashboard.png" width="250"> | <img src="docs/zh/login.png" width="250"> | <img src="docs/zh/settings.png" width="290"> |

## 系统要求

- macOS 13 Ventura 或更高版本（Apple Silicon / Intel）
- 一个已绑定打印机的拓竹账号（中国区或国际区）

## 安装

### 下载安装

从 [Releases](https://github.com/GuoDaiYi/BambuBar/releases/latest) 下载 **BambuBar-2.0.0-macOS.dmg**，打开后把 **BambuBar** 拖进 **Applications**。安装包内含 Apple Silicon + Intel 通用二进制。

App 使用本地 ad-hoc 签名，未经过公证。如果 macOS 阻止打开，请右键 App 选择「打开」，或执行：

```bash
xattr -dr com.apple.quarantine /Applications/BambuBar.app
```

### 从源码编译

```bash
git clone https://github.com/GuoDaiYi/BambuBar.git
cd BambuBar
./build.sh
open build/BambuBar.app
```

需要安装 Xcode Command Line Tools（`xcode-select --install`）。

### 第一次使用

1. 点击菜单栏里的打印机图标。
2. 选择「中国区」或「国际区」，输入拓竹账号和密码。
3. 如果拓竹发送验证码，输入邮箱或短信里的 6 位验证码。
4. 登录后会自动读取已绑定的打印机；用面板右上角「切换」选择菜单栏显示哪一台。
5. 在「设置」里切换语言、开启通知和开机启动。

密码不会被保存。云端 Token 存在 macOS 钥匙串中（失败时回退到权限为 `0600` 的文件），并且只发送给拓竹官方云服务。

## 支持的机型

| 功能 | A1 / A1 mini | P1 系列 | X1 系列 |
| --- | :---: | :---: | :---: |
| 云端状态监控 | ✅ | ✅（预期） | ✅（预期） |
| 本地 / 远程控制 | 请使用 Bambu Handy 或 Studio | 请使用 Bambu Handy 或 Studio | 请使用 Bambu Handy 或 Studio |

BambuBar 主要针对 A1 系列开发。其他使用相同拓竹云 MQTT 数据结构的机型大概率可用，但尚未逐一验证。使用的云端接口并非官方公开 API，拓竹变更服务时可能需要更新。

## 隐私

- 无统计、无遥测、无第三方后端。
- 不保存账号密码。
- Token 优先保存在 macOS 钥匙串；失败时保存在 `~/Library/Application Support/BambuBar/session.json`（仅当前用户可读）。
- 云端请求只发往 `api.bambulab.cn` / `api.bambulab.com` 和 `cn.mqtt.bambulab.com` / `us.mqtt.bambulab.com`。

## 已知限制

- **只读监控**：BambuBar 不发送暂停、继续、取消、调速或温度控制命令；控制请使用 Bambu Handy 或 Bambu Studio。
- 新版拓竹固件对第三方 MQTT 写入有 Authorization Control System；只读监控可以避免 HMS `0500-0500-0001-0007` 错误。
- 不包含摄像头和 AMS 面板。
- App 未公证，下载后可能需要右键「打开」。

## 从源码构建

```bash
./build.sh      # 编译 x86_64 + arm64 通用 App
./release.sh    # 生成 DMG 和 ZIP 到 build/
```

## 免责声明

BambuBar 是独立社区项目，与拓竹科技（Bambu Lab）无隶属关系，也未获得其背书。Bambu Lab 及相关打印机名称归其各自所有者。云端接口并非官方公开 API，可能随时变化。使用本软件风险自负。

## 许可证

MIT，详见 [LICENSE](LICENSE)。

## 致谢

- [OpenBambuAPI](https://github.com/Doridian/OpenBambuAPI)：云端 HTTP/MQTT 协议文档
- [Tabler Icons](https://tabler.io/icons)（MIT）：界面图标库
- [Bambu Studio](https://github.com/bambulab/BambuStudio) 及社区逆向项目提供的协议细节
- 所有分享打印机 MQTT 数据的社区贡献者
