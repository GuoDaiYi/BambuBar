# BambuBar

<p align="center">
  <img src="docs/zh/dashboard.png" width="360" alt="BambuBar 主面板">
</p>

<p align="center">
  <strong>原生 macOS 菜单栏拓竹打印机助手。</strong><br>
  实时进度、暂停/继续、四档调速、AMS 耗材和局域网摄像头。
</p>


BambuBar 常驻 macOS 菜单栏，直接连接拓竹云账号。菜单栏里就能看到当前打印进度，点击面板即可切换打印机、暂停/继续、调速、取消任务、查看温度、AMS 耗材和局域网摄像头画面。

界面支持 **简体中文 / 英文**，可在登录页右上角或设置中随时切换，选择会被记住。

---

## 功能

- **菜单栏进度环**：百分比、打印状态、在线状态一眼可见；图标为白色单色模板，自动适配菜单栏。
- **多打印机切换**：所有打印机在后台保持连接，在面板右上角切换菜单栏显示哪一台。
- **实时任务状态**：状态、进度、当前层/总层数、剩余时间、预计完成时间、速度档位、错误码。
- **打印控制**：暂停、继续、取消（取消前有确认弹窗）。
- **四档速度**：静音、标准、运动、狂暴。
- **温度与风扇**：查看喷嘴/热床/风扇；可调整喷嘴温度、热床温度和模型风扇。
- **AMS / AMS lite**：料盘颜色、材料、剩余百分比、当前槽位、湿度与温度。
- **局域网摄像头（可选）**：A1/P1 系列通过 TLS 6000 端口直连，支持大窗口查看。**没有手动填写 IP 时，摄像头 UI 不会显示**。
- **系统通知**：打印完成或异常时发送 macOS 通知。
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
- 摄像头：Mac 与打印机在同一局域网，并在打印机上开启 **LAN Liveview**

## 安装

### 下载安装

从 [Releases](https://github.com/GuoDaiYi/BambuBar/releases/latest) 下载 **BambuBar-1.1.0-macOS.dmg**，打开后把 **BambuBar** 拖进 **Applications**。安装包内含 Apple Silicon + Intel 通用二进制。

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
5. 在「设置」里切换语言、填写摄像头局域网 IP、开启通知和开机启动。

密码不会被保存。云端 Token 存在 macOS 钥匙串中（失败时回退到权限为 `0600` 的文件），并且只发送给拓竹官方云服务。

## 支持的机型

| 功能 | A1 / A1 mini | P1 系列 | X1 系列 |
| --- | :---: | :---: | :---: |
| 云端状态与控制 | ✅ | ✅（预期） | ✅（预期） |
| AMS 信息 | ✅ | ✅ | ✅ |
| 局域网摄像头（6000） | ✅（仅 A1；A1 mini 无摄像头） | ✅ | ❌（使用 RTSPS 322） |
| 云端远程摄像头 | ❌ | ❌ | ❌ |

BambuBar 主要针对 A1 系列开发。其他使用相同拓竹云 MQTT 数据结构的机型大概率可用，但尚未逐一验证。使用的云端接口并非官方公开 API，拓竹变更服务时可能需要更新。

## 工作原理

```
SwiftUI MenuBarExtra
        │
        ├── CloudAPI（URLSession）
        │     ├── 登录 / Token / 邮箱或短信验证码
        │     ├── GET /v1/iot-service/api/user/bind
        │     └── 中国区 / 国际区
        │
        ├── BambuCloud
        │     └── MQTT 3.1.1 over TLS 8883
        │           ├── device/{serial}/report
        │           ├── device/{serial}/request
        │           └── pause / resume / stop / print_speed / gcode_line
        │
        └── CameraClient
              └── TLS 6000 → 80 字节认证 → JPEG 帧
```

- MQTT 基于 `Network.framework` 从零实现（CONNECT / SUBSCRIBE / PUBLISH / PING，命令使用 QoS 1，自动重连），无第三方依赖。
- 云 MQTT 用户名 `u_{uid}`，密码为拓竹 Access Token。
- 摄像头使用打印机 8 位局域网访问码认证；打印机使用自签名证书，因此相机连接不校验证书链。

## 隐私

- 无统计、无遥测、无第三方后端。
- 不保存账号密码。
- Token 优先保存在 macOS 钥匙串；失败时保存在 `~/Library/Application Support/BambuBar/session.json`（仅当前用户可读）。
- 云端请求只发往 `api.bambulab.cn` / `api.bambulab.com` 和 `cn.mqtt.bambulab.com` / `us.mqtt.bambulab.com`。
- 摄像头数据只在局域网内直连打印机。

## 已知限制

- 云端远程摄像头使用拓竹私有 TUTK/Agora 协议，暂不支持；摄像头只在同一局域网可用。
- A1 mini 没有内置摄像头。
- 只有手动填写 IP 后才会显示摄像头 UI，这是刻意设计。
- X1 系列使用 RTSPS 322，不是 6000，暂未适配。
- 菜单栏面板为竖长方形；窗口高度固定。
- 与 Bambu Handy 同时修改设置时，拓竹云仍可能限流或断连；BambuBar 已使用 QoS 1、命令去重、重连退避，并把刷新按钮改为只请求状态，减少并发 HTTP 请求。
- App 未公证，下载后可能需要右键「打开」。

## 从源码构建

```bash
./build.sh      # 编译 x86_64 + arm64 通用 App
./release.sh    # 生成 DMG 和 ZIP 到 build/
```

## 免责声明

BambuBar 是独立社区项目，与拓竹科技（Bambu Lab）无隶属关系，也未获得其背书。Bambu Lab 及相关打印机名称归其各自所有者。云端接口并非官方公开 API，可能随时变化。使用本软件（尤其是向正在打印的机器发送控制命令）风险自负。

## 许可证

MIT，详见 [LICENSE](LICENSE)。

## 致谢

- [OpenBambuAPI](https://github.com/Doridian/OpenBambuAPI)：云端 HTTP/MQTT 与本地摄像头协议文档
- [Bambu Studio](https://github.com/bambulab/BambuStudio) 及社区逆向项目提供的协议细节
- 所有分享打印机 MQTT 数据的社区贡献者
