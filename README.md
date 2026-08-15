# Unlock Briefing

macOS 解锁简报：解锁后在屏幕中央弹出今日待办和倒计时；`⌘⇧U` 打开主窗口，可查看、编辑，并用 Git 同步 `content.json`。

标准 `.app`，不占 Dock。菜单栏默认有图标，可在设置里关掉。支持开机启动。

## 要求

- macOS 13+
- Xcode（本地编译）
- 系统已安装 `git`（同步使用本机已有凭证：SSH / osxkeychain）

## 运行

```bash
open UnlockBriefing.xcodeproj
```

或：

```bash
make open
```

- 解锁：约 0.8 秒后出现简报 HUD，约 8 秒自动消失；默认每个自然日只弹一次
- `⌘⇧U`：打开 / 关闭主窗口；打开时后台同步（有改动则 commit，再 `pull --rebase`、`push`）
- 菜单栏：打开窗口、立即同步、开机启动、设置、退出

首次使用：在设置里填写 Git 仓库地址（仓内需有 `content.json`）。未配置时主窗口为空，并引导去设置。

## 数据

| 用途 | 路径 |
|---|---|
| 设置 | `~/Library/Application Support/UnlockBriefing/settings.json` |
| 内容与 Git 工作副本 | `~/Library/Application Support/UnlockBriefing/data/` |

`content.json` 格式：

```json
{
  "todos": ["完成报告初稿"],
  "countdowns": [{ "title": "项目上线", "date": "2026-12-31" }]
}
```

倒计时：距离 ≥ 7 天显示「x 周 y 天」，否则「x 天 y 小时」，过期显示「已到期」。没有待办和倒计时时显示「今天暂无特别安排，保持专注。」

## 测试

```bash
make test
```
