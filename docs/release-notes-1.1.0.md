# BambuBar 1.1.0

## What's new

- **Landscape redesign** — the main popover is now a wide two-column layout (`784 × 500`). Print controls live on the left; camera, AMS and printer status live on the right.
- **Landscape sign-in and settings** — both windows were rebuilt to match the new horizontal layout.
- **Fixed popover animation** — the entrance animation now runs only when BambuBar's own menu bar panel appears. Opening or closing the Settings window no longer replays it.
- **Language-specific documentation** — the English README now contains only English screenshots; the Chinese README contains only Chinese screenshots.
- **GitHub release workflow as a project skill** — `.opencode/skills/bambubar-github-release` documents versioning, sanitization, universal builds, DMG creation, browser-only PAT handling and release cleanup.
- **Version 1.1.0** — universal binary for Apple Silicon and Intel.

All 1.0.0 features remain: menu bar progress, multiple printers, pause/resume/cancel, four speed modes, temperatures and fan control, AMS details, optional LAN camera, notifications and launch at login.

## Install

Download `BambuBar-1.1.0-macOS.dmg`, open it, and drag **BambuBar** into **Applications**.

The app is ad-hoc signed but not notarized. If macOS blocks it, right-click the app and choose **Open**, or run:

```bash
xattr -dr com.apple.quarantine /Applications/BambuBar.app
```

The first launch may show a one-time Keychain prompt after upgrading. Choose **Always Allow** so BambuBar can read its saved cloud session.

---

# BambuBar 1.1.0（中文）

## 本次更新

- **横版重新设计**：主面板改为 `784 × 500` 的横向两栏布局。左侧是打印进度与控制，右侧是摄像头、AMS 和打印机状态。
- **横版登录页与设置页**：两个窗口都重新排成横向布局。
- **修复弹出动画**：现在只有 BambuBar 自己的菜单栏面板出现时才播放动画；打开或关闭设置窗口不会再重复播放。
- **README 语言拆分**：英文 README 只使用英文截图，中文 README 只使用中文截图。
- **GitHub 发布流程 Skill**：新增 `.opencode/skills/bambubar-github-release`，记录版本号、脱敏检查、通用构建、DMG、浏览器授权和 Token 清理流程。
- **版本 1.1.0**：Apple Silicon + Intel 通用二进制。

1.0.0 的全部功能保留：菜单栏进度、多打印机切换、暂停/继续/取消、四档调速、温度与风扇、AMS、可选局域网摄像头、通知和开机启动。

## 安装

下载 `BambuBar-1.1.0-macOS.dmg`，打开后把 **BambuBar** 拖进 **Applications**。

App 使用 ad-hoc 签名，未公证。如果 macOS 阻止打开，请右键选择「打开」，或执行：

```bash
xattr -dr com.apple.quarantine /Applications/BambuBar.app
```

从旧版本升级后第一次打开可能弹出一次钥匙串授权，选择「始终允许」即可读取已保存的云端登录态。
