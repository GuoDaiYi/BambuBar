# BambuBar 1.0.0

First public release of BambuBar, a native macOS menu bar companion for Bambu Lab printers.

## Highlights

- Native SwiftUI menu bar app for macOS 13 Ventura or later
- Universal binary for Apple Silicon and Intel Macs
- **English and Simplified Chinese** UI, switchable at runtime and remembered across launches
- Menu bar progress ring with white monochrome template icon
- Live print status: progress, layers, remaining time, ETA, speed mode, temperatures and error state
- Pause, resume and cancel with a confirmation dialog
- Four speed modes: Silent, Standard, Sport and Ludicrous
- Nozzle / bed temperature and part-cooling fan controls
- AMS / AMS lite spool colors, material, remaining percentage, humidity and active slot
- Opt-in LAN camera for A1/P1-class printers (TLS port 6000); hidden until you enter a printer IP
- Print completion and error notifications
- Multiple printers with a switcher in the header
- Optional launch at login
- Direct connection to Bambu Cloud (China / Global); no third-party backend

## Install

1. Download `BambuBar-1.0.0-macOS.dmg`
2. Open the DMG and drag **BambuBar** into **Applications**
3. Launch it from Applications and click the printer icon in the menu bar

The app is ad-hoc signed but not notarized. If macOS blocks it, right-click the app and choose **Open**, or run:

```bash
xattr -dr com.apple.quarantine /Applications/BambuBar.app
```

## Notes

- The Bambu Cloud API is unofficial and may change without notice.
- Cloud/remote camera streaming uses a proprietary TUTK/Agora protocol and is not supported; the camera only works over the local network.
- A1 mini has no built-in camera.
- The camera UI stays hidden until a LAN IP is entered in Settings.
- Tested primarily with A1-series printers.

---

# BambuBar 1.0.0（中文）

BambuBar 首个公开版本，一个原生 macOS 菜单栏拓竹打印机助手。

## 主要更新

- 原生 SwiftUI 菜单栏 App，支持 macOS 13 Ventura 及以上
- Apple Silicon + Intel 通用二进制
- **中文 / English** 双语界面，可在登录页或设置中切换并记忆
- 菜单栏进度环，白色单色模板图标
- 实时状态：进度、层数、剩余时间、预计完成时间、速度档位、温度、错误状态
- 暂停 / 继续 / 取消（取消前确认）
- 四档速度：静音、标准、运动、狂暴
- 喷嘴 / 热床温度与模型风扇控制
- AMS / AMS lite 料盘颜色、材料、剩余百分比、湿度、当前槽位
- 可选局域网摄像头（A1/P1 系列，TLS 6000）；未填写 IP 时隐藏摄像头 UI
- 打印完成 / 异常系统通知
- 多打印机切换
- 可选开机启动
- 直连拓竹云（中国区 / 国际区），无第三方后端

## 安装

1. 下载 `BambuBar-1.0.0-macOS.dmg`
2. 打开 DMG，把 **BambuBar** 拖进 **Applications**
3. 从启动台打开，点击菜单栏的打印机图标

App 使用 ad-hoc 签名，未公证。如果 macOS 阻止打开，请右键选择「打开」，或执行：

```bash
xattr -dr com.apple.quarantine /Applications/BambuBar.app
```

## 说明

- 拓竹云端接口并非官方公开 API，可能随时变化。
- 云端远程摄像头使用私有 TUTK/Agora 协议，暂不支持；摄像头仅在局域网可用。
- A1 mini 没有内置摄像头。
- 未在设置中填写局域网 IP 时，摄像头 UI 不会显示。
- 主要针对 A1 系列测试。
