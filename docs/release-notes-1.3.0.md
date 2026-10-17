# BambuBar 1.3.0

## What's new

- **More rounded UI** — window corners, cards, tiles, segmented controls and buttons now share a larger corner radius.
- **Smaller main panel** — the landscape popover is now `590 × 450` (it expands only while a firmware warning is shown), removing the empty strip below the controls.
- **Tabler Icons** — the interface now uses the MIT-licensed Tabler line-icon font instead of the previous mixed SF Symbols style.
- **Larger language switch** — Chinese / English is a two-button segmented control with the same generous hit area as the speed selector.
- **Automatic update check** — the app checks GitHub Releases every few hours and shows a download badge when a newer version exists, plus a one-time notification.
- **Auto-hide main panel** — the dashboard retracts after 10 seconds without interaction, or when you switch to another window/app. Sign-in, sheets and Settings stay open until closed manually.
- **Monochrome notification image** — notifications now use a single-color printer thumbnail.
- **README cleanup** — removed the How it works, Project layout, Roadmap and Contributing sections from both language versions.
- **Code comments** — added documentation comments around cloud auth, MQTT state merging, command rejection handling, window behavior and update checks.

## Notes

- Newer Bambu firmware can still reject unsigned third-party pause / resume / cancel / speed commands (`mqtt message verify failed` / HMS `0500-0500-0001-0007`). BambuBar detects this and disables controls instead of retrying in a loop. LAN Only + Developer Mode is required for third-party control.
- Universal Apple Silicon + Intel build.

---

# BambuBar 1.3.0（中文）

## 本次更新

- **更多圆角**：窗口、卡片、温度块、分段控件和按钮统一使用更大的圆角。
- **主面板缩小**：横版面板改为 `590 × 450`（仅在显示固件警告时自动增高），去掉控制区下方多余空白。
- **Tabler 图标库**：界面改用 MIT 许可的 Tabler 线性图标字体。
- **更大的语言切换按钮**：中文 / 英文改为两段式按钮，整块可点击，触发面积与调速按钮一致。
- **自动检查更新**：每隔数小时检查 GitHub Release，有新版本时在菜单栏面板显示下载提示，并发送一次通知。
- **主面板自动收回**：10 秒无操作，或切换到其他窗口/应用时自动收起；登录页、弹出面板和设置窗口需要手动关闭。
- **单色通知图片**：通知使用单色打印机缩略图。
- **README 精简**：中英文 README 都删除了工作原理、项目结构、路线图和贡献指南。
- **代码注释**：为云端登录、MQTT 状态合并、命令拒绝处理、窗口行为和更新检查补充了注释。

## 说明

- 新版拓竹固件仍可能拒绝未签名的第三方暂停 / 继续 / 取消 / 调速命令（`mqtt message verify failed` / HMS `0500-0500-0001-0007`）。BambuBar 会识别并禁用控制，避免反复报错。需要第三方控制时，请使用 LAN Only + Developer Mode。
- Apple Silicon + Intel 通用构建。
