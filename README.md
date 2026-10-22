# Chill Timer — 让久坐的人记得起身

macOS 菜单栏休息提醒工具。不是番茄钟：白领不缺专注，缺的是身体——太专注会忘了起身、伸展、远眺。

专注计时结束 → 气泡提醒倒计时 → 无操作自动进入全屏休息 → 每个动作配参考插画与分步指引。

## 安装

1. 从 [Releases](https://github.com/iAcc01/chill-timer/releases) 下载 `ChillTimer-<版本>.dmg`（或按下文自行构建）
2. 打开 DMG，把 **Chill Timer** 拖进 **Applications**
3. 首次打开：应用未经 Apple 公证，需在 Finder 中**右键 → 打开 → 打开**；
   若提示"已损坏"，在终端执行 `xattr -dr com.apple.quarantine "/Applications/Chill Timer.app"`

要求 macOS 14 及以上，Apple 芯片与 Intel 均支持。应用不在 Dock 显示，入口是菜单栏的计时器图标。开机自启：「系统设置 → 通用 → 登录项」添加 Chill Timer。

## 构建

需要 Xcode 15+（Swift 6 工具链）。

```bash
./Scripts/build.sh          # 产出 dist/Chill Timer.app（通用二进制）
./Scripts/package_dmg.sh    # 在上一步基础上产出 dist/ChillTimer-<版本>.dmg
```

## 功能

**菜单栏浮窗**：环形倒计时 + 周期圆点 + 阶段标签；底部重置 / 主按钮（START · PAUSE · RESUME · BREAK · END）/ 设置。设置在浮窗内切换，不另开窗口。

**气泡提醒**：专注结束弹出，倒计时结束自动进入休息；可「休息」立即开始，或 × 跳过本轮。

**全屏休息**：覆盖所有显示器；按休息时长自动编排动作（起身类优先，用眼类收尾），每个动作有参考插画、分步说明和单动作倒计时；结束保护期后可点 END 或按 Esc 提前结束，结束后直接进入下一轮专注。

**设置**

| 分组 | 内容 |
|---|---|
| 时长 | 专注 / 短休息 / 长休息 / 长休间隔（可手动输入，带 4 个常用值） |
| 提醒 | 气泡倒计时、结束保护（可设置）、提示音、立即休息 |
| 行为 | 外观（系统 / 浅色 / 深色）、自动开始休息、自动开始下一轮、休息时全屏、承诺模式 |
| 关于 | 今天 / 近 7 天 / 累计休息次数、版本（检查与安装更新）、退出 |

## 自动更新

- 启动 5 秒后检查一次，之后每 6 小时检查一次 GitHub 最新正式发布
- 有新版本时，菜单栏图标、浮窗齿轮、设置「关于」标签和「版本」行出现红点
- 点「版本」行弹窗：**立即更新**＝下载 DMG、校验 Bundle ID 与版本号、替换当前应用并自动重启（失败自动回滚）；**稍后提醒**＝24 小时内不再显示红点，期间若发布了更新的版本则立即提示
- 应用不在可写位置（如直接从 DMG 运行）时，会打开安装包让用户手动拖入

**发布新版本**（更新通道依赖以下约定）：

```bash
# 1. 改 Resources/Info.plist 的 CFBundleShortVersionString，如 0.2.0
./Scripts/package_dmg.sh                       # 产出 dist/ChillTimer-0.2.0.dmg
gh release create v0.2.0 dist/ChillTimer-0.2.0.dmg --title "v0.2.0" --notes "更新说明"
```

tag 必须是 `v<版本号>`、附件名必须是 `ChillTimer-<版本号>.dmg`，且与包内 Info.plist 版本一致，否则客户端会拒绝安装。

## 默认节奏

| 项 | 默认 |
|---|---|
| 专注时长 | 30 分钟 |
| 气泡倒计时 | 30 秒 |
| 短休息 | 3 分钟 |
| 长休息 | 15 分钟，每 4 轮一次 |
| 结束保护 | 10 秒 |

## 动作内容

12 个微动作：起身走动、颈部侧屈、颈部回旋、肩部绕环、扩胸展背、站立体前屈、站起侧伸展、手腕伸展、手指张握、20-20-20 远眺、眼球放松、腹式深呼吸。

内容约定：文案中写明的秒数之和等于该动作时长；以「直到倒计时结束」收尾的动作用于吸收凑整秒数，保证一次休息的动作总时长严格等于设置值。

## 结构

```
Sources/ChillTimer/
  ChillTimerApp.swift    App 入口、菜单栏、AppDelegate
  TimerEngine.swift      状态机（idle / running / paused / waitingBreak / resting / waitingWork + 周期）
  Models.swift           动作内容库 + 编排算法（平台无关，可复用到 Windows 端）
  WindowManager.swift    气泡面板 / 每屏一个全屏休息窗口
  UpdateChecker.swift    版本巡检、红点、稍后提醒、下载安装与重启
  Theme.swift            设计令牌（随外观切换的语义色）+ 环形进度 / 圆形按钮 / 胶囊按钮
  TimerCardView.swift    计时卡片
  MenuView.swift         菜单栏浮窗（卡片 ⇄ 设置）
  SettingsWindow.swift   设置页（时长 / 提醒 / 行为 / 关于 + 步进子页）
  BubbleView.swift       气泡提醒
  BreakOverlayView.swift 全屏休息界面
  AppSettings.swift      UserDefaults 配置
  StatsStore.swift       按天记录休息次数（仅本机）
Resources/
  Info.plist
  Actions/<动作 id>.png  动作参考插画
Scripts/
  build.sh               构建 .app
  package_dmg.sh         构建 .dmg 安装包
```

## 隐私

零权限：不读取屏幕、不用摄像头与辅助功能权限，所有数据只存在本机。唯一的网络访问是检查更新时请求 GitHub（不上传任何数据）。
