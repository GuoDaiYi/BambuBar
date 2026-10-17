# BambuBar 2.0.0

## Product repositioning

BambuBar is now a **read-only print progress monitor**. All printer control components have been removed.

- No pause / resume / cancel buttons
- No speed adjustment
- No temperature or fan adjustment
- No control MQTT writes; the app only subscribes to status reports
- Control remains in Bambu Handy or Bambu Studio

## What's new

- **Merged window** — Settings is now part of the same menu bar panel. Use the gear button to open it and Back to return to the monitor.
- **Quit button** — a power button in the header and a Quit action in Settings terminate the app completely.
- **Smaller monitor** — `590 × 340`, showing progress, layers, ETA, read-only temperatures and a refresh action.
- **Fixed window rendering** — removed the custom whole-window clipping that caused incorrect rounded-corner artifacts. Windows now use native macOS corners; cards and buttons keep their own rounded style.
- **Tabler Icons** — the interface uses the bundled MIT-licensed Tabler icon font.
- **Update checks** — GitHub Releases are checked periodically; a download badge appears in the panel.
- **Auto-hide** — the monitor retracts after 10 seconds of inactivity or when another window/app is activated. The merged Settings view stays open until you press Back or Quit.
- **Monochrome notification thumbnail** — notifications use a single-color printer image.

## Install

Download `BambuBar-2.0.0-macOS.dmg`, open it, and drag **BambuBar** into **Applications**.

The app is ad-hoc signed but not notarized. If macOS blocks it, right-click the app and choose **Open**, or run:

```bash
xattr -dr com.apple.quarantine /Applications/BambuBar.app
```

---

# BambuBar 2.0.0（中文）

## 产品定位调整

BambuBar 现在是一个 **只读打印进度监控器**，所有打印机控制组件已删除。

- 不再提供暂停 / 继续 / 取消按钮
- 不再提供调速
- 不再提供温度或风扇调节
- 不再发送控制类 MQTT 命令，只订阅状态
- 控制请继续使用 Bambu Handy 或 Bambu Studio

## 本次更新

- **窗口合并**：设置已并入同一个菜单栏面板，点击齿轮进入，点「返回」回到监控界面。
- **退出按钮**：顶部电源按钮和设置里的退出操作会彻底结束 App。
- **更小的监控器**：`590 × 340`，显示进度、层数、预计时间、只读温度和刷新按钮。
- **修复窗口渲染**：移除导致圆角显示错误的整窗裁剪，窗口使用 macOS 原生圆角，卡片和按钮保留自己的圆角样式。
- **Tabler 图标库**：使用内置的 MIT 许可 Tabler 图标字体。
- **更新检查**：定期检查 GitHub Release，有新版本时在面板中显示下载徽章。
- **自动收回**：主监控面板 10 秒无操作或切换到其他窗口/应用时收起；合并后的设置界面保持打开，直到点「返回」或「退出」。
- **单色通知缩略图**：通知附带单色打印机图片。

## 安装

下载 `BambuBar-2.0.0-macOS.dmg`，打开后把 **BambuBar** 拖进 **Applications**。

App 使用 ad-hoc 签名，未公证。如果 macOS 阻止打开，请右键选择「打开」，或执行：

```bash
xattr -dr com.apple.quarantine /Applications/BambuBar.app
```
