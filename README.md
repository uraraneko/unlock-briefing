# Unlock Briefing

独立 macOS 解锁简报应用（Swift + SwiftUI）。锁屏解锁后弹出今日待办和倒计时；`⌘⇧U` 打开主窗口，可编辑内容并通过 Git 同步 `content.json`。

不再依赖 [Hammerspoon](https://www.hammerspoon.org/)。旧 Lua 实现见 [`mac-unlock-briefing`](https://github.com/uraraneko/mac-unlock-briefing)。

## 要求

- macOS 13+
- Xcode（本地编译）
- 系统已安装 `git`（同步用本机凭证：SSH / osxkeychain）

## 运行

```bash
open UnlockBriefing.xcodeproj
```

或：

```bash
make open
```

应用不占 Dock。菜单栏有清单图标；也可按 `⌘⇧U` 打开主窗口。

首次使用：设置里填写私有 Git 仓库地址（仓内需有 `content.json`）。未配置仓库时主窗口为空并引导去设置。

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

## 测试

```bash
make test
```
