# BambuBar 1.2.0

## What's new

- **Compact landscape UI** — the main popover is now `620 × 470`. The camera, AMS and printer-status panels were removed.
- **Larger speed controls** — each speed segment is a full-size hit target; tapping anywhere in a segment changes the mode.
- **Download / unpack recognition** — while a cloud job is being transferred or prepared, the menu bar and panel show **Downloading** / **Unpacking** instead of a generic "Preparing".
- **Command rejection detection** — Bambu firmware now verifies MQTT control commands. If the printer returns `mqtt message verify failed` or HMS `0500-0500-0001-0007`, BambuBar shows an explanation and disables the controls instead of silently retrying.
- **Manual retry** — a Retry action re-enables controls after switching the printer to LAN Only + Developer Mode.
- **Removed features** — camera, AMS details and the printer-status card are gone, along with their code and settings.
- **Version 1.2.0** — universal Apple Silicon + Intel build.

## Important firmware limitation

Bambu's Authorization Control System blocks unsigned third-party pause / resume / cancel / speed commands in cloud mode and standard LAN mode. This is enforced by the printer, not by BambuBar. To use these controls, the printer must be in **LAN Only mode with Developer Mode** enabled; that disconnects it from Bambu Cloud and Bambu Handy. Otherwise, use Bambu Handy or Bambu Studio for control and BambuBar for monitoring.

## Install

Download `BambuBar-1.2.0-macOS.dmg`, open it, and drag **BambuBar** into **Applications**.

The app is ad-hoc signed but not notarized. If macOS blocks it, right-click the app and choose **Open**, or run:

```bash
xattr -dr com.apple.quarantine /Applications/BambuBar.app
```

---

# BambuBar 1.2.0（中文）

## 本次更新

- **紧凑横版界面**：主面板改为 `620 × 470`，删除摄像头、AMS 和打印机状态面板。
- **增大调速按钮触发面积**：四个速度档位整块可点击，不再只有文字区域生效。
- **识别下载 / 解压阶段**：云端任务传输和准备期间，菜单栏与面板显示「下载中 / 解压中」，不再只显示笼统的「准备中」。
- **识别命令被固件拒绝**：拓竹新固件会校验 MQTT 控制命令。如果打印机返回 `mqtt message verify failed` 或 HMS `0500-0500-0001-0007`，BambuBar 会显示原因并禁用控制按钮，不再静默重试。
- **手动重试**：切换到 LAN Only + Developer Mode 后，可点「重试」恢复控制。
- **移除功能**：摄像头、AMS 详情、打印机状态卡及其代码和设置全部删除。
- **版本 1.2.0**：Apple Silicon + Intel 通用构建。

## 重要固件限制

拓竹 Authorization Control System 会在云端模式和普通局域网模式下拒绝未授权的第三方暂停 / 继续 / 取消 / 调速命令。这是打印机固件的限制，不是 BambuBar 自身的问题。需要使用这些控制功能时，打印机必须使用 **LAN Only 模式并开启 Developer Mode**；这会使打印机断开拓竹云，Bambu Handy 也将不可用。否则请使用 Bambu Handy 或 Bambu Studio 控制，BambuBar 用于监控。

## 安装

下载 `BambuBar-1.2.0-macOS.dmg`，打开后把 **BambuBar** 拖进 **Applications**。

App 使用 ad-hoc 签名，未公证。如果 macOS 阻止打开，请右键选择「打开」，或执行：

```bash
xattr -dr com.apple.quarantine /Applications/BambuBar.app
```
