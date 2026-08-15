# Unlock Briefing

[English](README.md) · **中文**

解锁 Mac 后弹出今日待办和关键日期倒计时。按 **⌘⇧U** 打开主窗口，可查看、编辑，并用 Git 同步 `content.json`。

标准 `.app`，不占 Dock。菜单栏默认有图标，可在设置里关掉。开机启动可选。

## 安装

1. 下载 **[UnlockBriefing-0.1.1.zip](https://github.com/uraraneko/unlock-briefing/releases/latest)**，解压得到 `UnlockBriefing.app`
2. 拖到「应用程序」后打开
3. 若提示无法验证开发者：**系统设置 → 隐私与安全性 → 仍要打开**
4. 打开设置（菜单栏或主窗口），粘贴私有 Git 仓库地址（仓内需有 `content.json`）并保存

需要 macOS 13+，以及本机已安装的 `git`（使用已有凭证：SSH / osxkeychain）。

可选：菜单栏开启 **开机启动**。

## 多设备同步（私有仓库）

待办和倒计时放在你的私有 Git 仓，不会进本公开仓库：

1. 在设置里填写仓库地址。应用会 clone 到 `~/Library/Application Support/UnlockBriefing/data/`，并读取其中的 `content.json`。
2. 按 **⌘⇧U** 打开窗口时，后台做双向同步（有改动则 `commit`，再 `git pull --rebase` & `git push`）。
3. 若拉取到新内容，窗口会刷新为最新数据。

未配置仓库时主窗口为空，并引导去设置。

## 配置

在主窗口点 **编辑**，或直接改数据仓里的 `content.json`：

```json
{
  "todos": ["完成报告初稿", "回复客户邮件"],
  "countdowns": [
    { "title": "项目上线", "date": "2026-12-31" }
  ]
}
```

倒计时：距离 ≥ 7 天显示「x 周 y 天」，否则「x 天 y 小时」，过期显示「已到期」。待办和倒计时都为空时显示「今天暂无特别安排，保持专注。」

应用设置（仓库地址、开机启动、菜单栏图标）在 `~/Library/Application Support/UnlockBriefing/settings.json`。

按 **⌘⇧U** 切换主窗口（关闭时打开，打开时关闭）。
