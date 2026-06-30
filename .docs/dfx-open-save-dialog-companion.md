# 抄 Default Folder X 核心功能自研 App 调研文档

## 目标

自研一个 macOS app，复刻 Default Folder X（下文简称 DFX）里最核心的 Open / Save dialog 增强体验：

- 在系统原生 Open / Save dialog 周边贴一个额外 UI。
- UI 提供 Favorites、Recent Folders、Finder Windows 等快捷入口。
- 用户点击入口后，当前 Open / Save dialog 跳转到对应目录。
- 不替换 Finder，不替换系统 dialog，不关闭 SIP，不做进程注入。

这个文档先描述 DFX 现有功能和 UI，再给出自研 MVP 的功能范围、技术原理、权限需求和风险。

## DFX 现有能力描述

资料来源：

- Default Folder X 官网：https://www.stclairsoft.com/DefaultFolderX/
- 官网截图：`AnnotatedOpenDialog.png`、`DialogClick.png`、`FinderMenu.png`、`PrefsGeneral.png`
- Apple `NSSavePanel` / `NSOpenPanel` 文档
- Apple System Integrity Protection 文档

### 产品定位

DFX 不是 Finder replacement。它是一个全局文件工作流增强工具，重点增强：

- Open / Save dialog
- Finder toolbar / menu bar 快捷入口
- 最近文件夹和收藏文件夹导航
- 当前 Finder 窗口跳转
- Quick Search
- 保存/打开时的辅助信息和 metadata 操作

官网核心表述是：

- “Turbocharge Open and Save dialogs”
- “Quick access to your files and folders in every app”
- “Go faster in the Finder”

### 分发与授权

DFX 不是 Mac App Store 分发。

官网显示：

- 官网单独下载。
- 30 天免费试用。
- 单用户授权价：39.95 USD。
- 支持 macOS 10.13 through 26.5。
- Intel 和 Apple Silicon 原生运行。

这类工具需要 Accessibility、Automation、全局窗口辅助 UI 等能力，通常不适合 App Store sandbox 路线。

## 从官网 UI 图片观察到的 DFX 交互

### 1. Open / Save dialog 右侧工具条

`AnnotatedOpenDialog.png` 显示：DFX 在系统原生 Open dialog 右侧贴了一个半透明竖向工具条。

右侧工具条包含这些 icon / menu：

- Utility Menu
- Computer Menu
- Favorite Menu
- Recent Folder Menu
- Recent File Menu
- Finder Window Menu

视觉结构大致是：

```text
┌────────────── Open / Save dialog ──────────────┐┌──── DFX right strip ────┐
│                                                ││ Utility Menu             │
│  原生 sidebar / 文件列表 / Open Save 按钮        ││ Computer Menu            │
│                                                ││ Favorite Menu            │
│                                                ││ Recent Folder Menu       │
│                                                ││ Recent File Menu         │
│                                                ││ Finder Window Menu       │
└────────────────────────────────────────────────┘└─────────────────────────┘
```

判断：DFX 很可能不是把控件真正插入系统 dialog，而是在 dialog 外部贴一个 companion overlay window。视觉上像 dialog 的一部分，但技术上应是独立窗口。

### 2. Finder / toolbar 菜单

`FinderMenu.png` 显示：Finder 窗口工具栏里可以加入 DFX 菜单按钮。点击后弹出菜单：

```text
Computer >
Favorites >
Recent Folders >
Recent Files >
Finder Windows >
Quick Search    ⌘Space
```

这说明 DFX 不只在 Open / Save dialog 出现，也能作为 Finder toolbar 或 menu bar 的快速导航入口。

### 3. 点击 Finder 窗口跳转

`DialogClick.png` 显示：Open dialog 打开时，用户可以点击屏幕上的 Finder 窗口。点击后出现一个小菜单，菜单项类似：

```text
Desktop Pictures >
Downloads >
```

这表明 DFX 能读取用户点击的 Finder window / Finder tab / Finder location，并把这些位置作为 Open / Save dialog 的跳转目标。

这个能力比“列出 Finder windows 给用户选”更进一步：它把桌面上现有 Finder window 变成了 dialog 的导航目标。

### 4. 左侧 Drag Zone / drawer

`AnnotatedOpenDialog.png` 显示：Open dialog 左侧还有一个半透明区域，标注为 Drag Zone。

观察到的内容：

- 文件夹图标
- 图片缩略图
- 文档缩略图

推测作用：

- 临时 shelf / drawer。
- 用户可以把文件或文件夹拖进去暂存。
- 后续在 Open / Save dialog 里快速访问或拖回。

这个不是我们 MVP 的核心需求，可以后置。

### 5. 偏传统的设置窗口

`PrefsGeneral.png` 显示设置窗口顶部有 tab：

```text
General
Folders
Menus
Recent
Open & Save
Shortcuts
Options
```

General 页可见设置：

- Start at login
- Show icon
- Customize Menu
- Add menu to Finder toolbars
- Add drawer button to Finder toolbars
- Quick Search shortcut
- Buy Upgrade / Enter License

这说明 DFX 是一个常驻后台 app，有登录启动、菜单栏入口、Finder toolbar integration、快捷键配置、授权系统。

## DFX 核心功能拆解

### Open / Save dialog 导航增强

用户在任意 app 的 Open / Save dialog 里，可以通过 DFX UI 快速跳转：

- Computer
- Favorites
- Recent Folders
- Recent Files
- Finder Windows
- Quick Search

价值：绕过系统 Open / Save dialog 自带的低效目录导航。

### 当前 Finder 窗口跳转

DFX 能将已经打开的 Finder windows 当成跳转目标。

用户价值：如果用户已经在 Finder 里打开了目标目录，就不用复制路径、不用手动 `Command+Shift+G`，直接从 DFX UI 或 Finder window 进入该目录。

### Favorites / Recent Folders

DFX 管理常用目录和最近目录。

用户价值：保存、打开、上传、导出文件时，常用目录可直接选，不需要反复层层点击。

### Finder toolbar / menu bar integration

DFX 可以把菜单加到 Finder toolbar，也可以显示 menu bar icon。

用户价值：不只在 dialog 里用，也能作为 Finder 工作流入口。

### Quick Search

DFX 提供 Quick Search 快捷键。官网截图显示 General 设置页里 Quick Search 默认快捷键区域，另一个菜单截图显示 `Quick Search ⌘Space`。

用户价值：用键盘快速搜索文件、文件夹、app，跳转比点菜单更快。

### Open / Save dialog 辅助信息

官网描述还有：

- Open / Save dialog 下方 preview / info panels。
- 保存时添加 tags、comments、permissions。
- 记录 recently used files / folders。
- 每个 app 可以有默认文件夹。

这些属于高级增强，不是第一版 MVP 必需。

## Apple 提供的相关 API 与限制

### 当前 app 自己能控制自己的 Open / Save panel

Apple AppKit 提供：

- `NSOpenPanel`
- `NSSavePanel`
- `NSSavePanel.directoryURL`

`directoryURL` 文档说明是：

```text
The current directory shown in the panel.
```

也就是说，如果是我们自己的 app 弹出 Open / Save panel，可以直接：

```swift
panel.directoryURL = URL(fileURLWithPath: "/Users/yi/Downloads")
```

### 外部工具不能直接拿到别人 app 的 panel 对象

如果是 Chrome、Preview、Photoshop、VS Code 等别的 app 弹出 Open / Save dialog，我们的 app 拿不到它进程里的 `NSSavePanel` / `NSOpenPanel` 对象。

不存在公开 API 可以这样做：

```text
set current directory of frontmost foreign save panel to /some/path
```

### macOS 10.15 之后 Open / Save panel 被单独进程绘制

Apple 文档说明：macOS 10.15 之后，Open panel 和 Save panel 总是在单独进程里显示，不管宿主 app 是否 sandboxed。

影响：

- 系统文件对话框隔离更强。
- 外部 app 更不可能直接改别的 app 的 panel。
- 第三方工具应走 Accessibility / Automation 辅助路线，而不是注入或私有 API。

### Finder Sync 不适合这个核心需求

Apple Finder Sync 能做：

- Finder 右键菜单。
- Finder toolbar button。
- 文件 badge / label。
- 监控指定 folder。

但 Apple 文档明确说 Finder Sync is not intended as a general tool for modifying Finder UI。

它不适合做全局 Open / Save dialog companion UI。

## 自研 MVP 方案

### MVP 目标

第一版只复刻 DFX 最核心的 Open / Save dialog 贴边导航能力：

1. 检测任意 app 是否打开标准 Open / Save dialog。
2. 在 dialog 右侧贴一个小型竖向 floating UI。
3. UI 提供：Favorites、Finder Windows、Recent Folders、Clipboard Path。
4. 用户点击某个目录后，当前 Open / Save dialog 跳转到该目录。
5. 不关闭 SIP，不注入进程，不替换系统 dialog。

### MVP 不做

第一版不做：

- 左侧 Drag Zone。
- Recent Files。
- Computer menu。
- Finder toolbar integration。
- menu bar 完整菜单。
- 点击屏幕上的 Finder window 直接跳转。
- Quick Search 完整搜索。
- 每个 app 默认文件夹。
- Save dialog metadata panel。
- App Store 分发。

原因：这些会显著增加窗口跟踪、事件处理、权限、UI 状态同步复杂度。第一版只先验证核心闭环。

## MVP 用户体验

### 场景 1：保存文件到收藏目录

```text
用户在任意 app 里打开 Save dialog
→ app 检测到 Save dialog
→ 右侧贴出我们的工具条
→ 用户点击 Favorite Menu
→ 选择 ~/Documents/code/project-a
→ Save dialog 跳转到该目录
```

### 场景 2：打开文件时跳到当前 Finder 窗口

```text
用户 Finder 已打开 ~/Downloads/assets
→ 用户在 Preview / Photoshop / Browser 里打开 Open dialog
→ 右侧工具条出现
→ 用户点击 Finder Windows Menu
→ 选择 Downloads/assets
→ Open dialog 跳转到该目录
```

### 场景 3：粘贴板里已有路径

```text
用户复制了 /Users/yi/Desktop/export
→ Open / Save dialog 出现
→ 工具条显示 Clipboard Path
→ 用户点击 Clipboard Path
→ dialog 跳转到该路径
```

## MVP UI 设计

第一版右侧贴边工具条：

```text
┌────────────── Open / Save dialog ──────────────┐┌───┐
│                                                ││ 📋 │ Clipboard Path / Utility
│                                                ││ 🖥 │ Finder Windows
│                                                ││ ★ │ Favorites
│                                                ││ ↺ │ Recent Folders
└────────────────────────────────────────────────┘└───┘
```

点击 icon 弹出原生风格菜单：

```text
Favorites
  Documents/code
  Downloads
  Desktop/Screenshots

Finder Windows
  project-a        /Users/yi/Documents/code/project-a
  Downloads        /Users/yi/Downloads
  assets           /Users/yi/Desktop/assets

Recent Folders
  export           /Users/yi/Desktop/export
  temp             /tmp
```

视觉原则：

- 半透明材质，接近 macOS floating panel 风格。
- 默认贴在 dialog 右侧。
- 右侧空间不足时可贴左侧或下方。
- 不遮挡 Open / Save 的 Cancel / Open / Save 按钮。
- 尽量不抢键盘焦点。

## MVP 技术原理

### 整体架构

```text
Menu bar app / background agent
  ├─ DialogDetector
  │   └─ 通过 Accessibility 监控前台 app 和窗口
  ├─ OverlayController
  │   └─ 创建并定位 NSPanel，贴在 Open / Save dialog 边缘
  ├─ FolderSource
  │   ├─ FavoritesStore
  │   ├─ RecentsStore
  │   ├─ FinderWindowProvider
  │   └─ ClipboardPathProvider
  ├─ DialogJumper
  │   └─ 通过 Accessibility / CGEvent 驱动 Go to Folder
  └─ SettingsStore
      └─ 保存 favorites、recent、权限状态、UI 偏好
```

### 1. 检测 Open / Save dialog

使用 Accessibility API 和 `NSWorkspace`：

- 监听前台 app 切换。
- 获取 frontmost app 的窗口列表。
- 获取 focused window。
- 读取窗口 role / subrole / title / size / children。
- 判断是否出现标准 Open / Save panel。

可能使用的 API / attribute：

- `NSWorkspace.didActivateApplicationNotification`
- `AXUIElementCreateApplication(pid)`
- `kAXWindowsAttribute`
- `kAXFocusedWindowAttribute`
- `kAXRoleAttribute`
- `kAXSubroleAttribute`
- `kAXTitleAttribute`
- `kAXPositionAttribute`
- `kAXSizeAttribute`
- `AXObserver`

判断策略：

- role 是 window / dialog / sheet。
- title 或按钮包含 Open、Save、Cancel。
- 子树包含标准文件浏览控件。
- 子树包含 name field / search field / file browser。

注意：这不是 Apple 提供的稳定语义 API，需要做兼容和 fallback。

### 2. 贴边 overlay UI

使用 `NSPanel`：

- borderless 或 custom chrome。
- floating level。
- 不进入 Dock。
- 可以设置 `hidesOnDeactivate` 行为。
- 根据目标 dialog 的 frame 计算位置。
- 监听 dialog move / resize 后重新布局。
- dialog 关闭或前台 app 切换后隐藏。

定位逻辑：

```text
toolbar.x = dialog.maxX + spacing
toolbar.y = dialog.midY - toolbar.height / 2
```

如果右侧空间不足：

```text
fallback: dialog.minX - toolbar.width - spacing
fallback: dialog.maxY + spacing
fallback: dialog.minY - toolbar.height - spacing
```

### 3. 获取 Favorites

本地维护 favorites。

第一版可用 JSON 或 SQLite。自用 JSON 足够：

```json
[
  {
    "path": "/Users/yi/Documents/code",
    "displayName": "code",
    "createdAt": "2026-06-22T00:00:00Z",
    "lastUsedAt": "2026-06-22T00:00:00Z"
  }
]
```

Favorites 初始管理方式：

- 设置页手动添加。
- 菜单项里提供 “Add Current Folder to Favorites”。
- 可后续支持拖拽添加。

### 4. 获取 Recent Folders

第一版不追求读取系统全量 recent。

只记录本 app 执行过的跳转：

```text
用户通过本 app 跳转到 /foo/bar
→ 记录 path、frontmost app bundle id、timestamp、use count
→ 下次显示在 Recent Folders
```

可选增强：

- 按 app 过滤 recent。
- 全局 recent 和 per-app recent 分开。
- 自动清理不存在路径。

### 5. 获取 Finder Windows 路径

推荐使用 AppleScript / ScriptingBridge，而不是只靠 Accessibility。

原因：Accessibility 能拿 Finder window 数量、标题、frame，但完整 filesystem path 不稳定。

AppleScript 示例：

```applescript
tell application "Finder"
    set xs to {}
    repeat with w in windows
        set end of xs to POSIX path of (target of w as alias)
    end repeat
    return xs
end tell
```

需要权限：

```text
Privacy & Security → Automation → OurApp → Finder
```

可返回：

```text
/Users/yi/Downloads/
/Users/yi/Documents/code/project-a/
/Users/yi/Desktop/assets/
```

### 6. 获取 Clipboard Path

读取系统 pasteboard：

- 如果剪贴板是 text，检查是否为有效 POSIX path。
- 如果剪贴板是 file URL，读取 URL path。
- 如果路径存在且是目录，显示为 Clipboard Path。
- 如果路径存在且是文件，显示其 parent directory 或提供 “Reveal containing folder”。

第一版行为建议：

```text
clipboard 是目录 → 跳目录
clipboard 是文件 → 跳 parent directory
clipboard 不是 path → 不显示 Clipboard Path
```

### 7. 驱动 Open / Save dialog 跳转

核心方式：自动化系统标准 `Go to Folder`。

流程：

```text
用户点击菜单目录
→ 记录目标 app / target dialog
→ 隐藏或降低 overlay 焦点
→ 激活目标 app / focused dialog
→ 发送 Command+Shift+G
→ 等待 Go to Folder sheet 或短暂延迟
→ 输入目标 path
→ Return
→ 记录 Recent Folder
```

技术选择：

- `CGEvent` 发送快捷键。
- Accessibility 设置文本框值。
- 或初版直接使用 pasteboard + Command+V。

更稳的第一版可以使用 pasteboard：

```text
保存当前剪贴板
→ 设置剪贴板为 path
→ Command+Shift+G
→ Command+V
→ Return
→ 恢复剪贴板
```

但这会短暂污染剪贴板。更干净但更复杂的做法是：

```text
Command+Shift+G
→ 用 AX 找到 Go to Folder text field
→ AXSetAttributeValue 设置文本
→ AXPress Return / click Go
```

建议第一版：先 pasteboard 方案验证闭环，再做 AX text field 直写优化。

## 权限需求

### Accessibility：必需

用途：

- 观察前台 app 和窗口。
- 判断 Open / Save dialog 是否出现。
- 读取 dialog frame。
- 发送快捷键 / 鼠标事件。
- 让 overlay 跟随 dialog。

系统路径：

```text
System Settings → Privacy & Security → Accessibility
```

### Automation → Finder：强烈推荐 / 实际必需

用途：

- 获取 Finder windows 的真实 path。
- 获取 Finder front window path。
- 后续可获取 Finder selection path。

系统路径：

```text
System Settings → Privacy & Security → Automation → OurApp → Finder
```

### Input Monitoring：可选

第一版不需要。

后续如果做：

- 监听全局鼠标点击 Finder window。
- 更底层键盘事件监听。

可能需要 Input Monitoring。

### Screen Recording：避免

第一版不应使用截图或窗口图像识别，因此不需要 Screen Recording。

### Full Disk Access：一般不需要

第一版只处理用户显式选择的路径，不扫描全盘，不读文件内容，不需要 Full Disk Access。

## MVP 风险和边界

### 风险 1：没有官方跨进程 set directory API

我们不能直接控制别的 app 的 `NSSavePanel.directoryURL`。

应对：使用 `Command+Shift+G` 作为稳定用户入口。

### 风险 2：Open / Save dialog 检测不完全稳定

不同 app 可能使用：

- 标准 AppKit Open / Save panel。
- 自定义 Electron / web dialog。
- 老式 Carbon / private dialog。
- 沙盒 app 的系统 panel。

MVP 只支持标准系统 Open / Save dialog。非标准 dialog 不显示 overlay。

### 风险 3：overlay 焦点干扰 dialog

用户点击 overlay 菜单时，前台 app / dialog 可能失焦。

应对：

- 点击菜单项前记录 target dialog。
- 菜单项执行时重新激活 target app。
- overlay 选择 nonactivating panel 或尽量减少焦点抢夺。
- 操作完成后隐藏菜单，恢复目标 app。

### 风险 4：时序问题

`Command+Shift+G` 后 Go to Folder sheet 不是立即出现。

应对：

- 延迟 50-150ms。
- 或用 AXObserver 等待 text field 出现。
- 超时后给出失败提示。

### 风险 5：路径异常

可能出现：

- 路径不存在。
- 网络盘未挂载。
- iCloud placeholder。
- 权限不足。
- 文件路径而非目录路径。

应对：

- 菜单显示前验证路径。
- 不存在路径灰掉或隐藏。
- 文件路径默认跳 parent directory。
- 跳转失败时显示短提示。

## MVP 成功标准

第一版可认为成功，如果能做到：

1. 在 Preview / TextEdit / Safari / Chrome 等常见 app 的标准 Open / Save dialog 中自动显示右侧工具条。
2. 工具条能跟随 dialog 移动和关闭。
3. Favorites 菜单能跳转当前 dialog。
4. Finder Windows 菜单能列出当前 Finder 窗口路径并跳转。
5. Recent Folders 能记录本 app 触发过的跳转。
6. Clipboard Path 能识别有效路径并跳转。
7. 全程不关闭 SIP，不注入进程。
8. Accessibility 和 Automation 权限缺失时给出明确引导。

## 后续路线

### Phase 2：更像 DFX 的日常体验

- Quick Search。
- Per-app recent folders。
- Per-app default folder。
- 收藏夹管理 UI。
- 菜单项排序和隐藏。
- 跳转时不污染剪贴板，用 AX 直接填写 Go to Folder 输入框。

### Phase 3：DFX 高级交互

- 点击屏幕上的 Finder window，让 dialog 跳到该 Finder window。
- 左侧 Drag Zone / shelf。
- Finder toolbar / menu bar integration。
- Recent Files。
- Computer menu。
- Save dialog tags / comments / info panel。

### Phase 4：产品化

- 自动更新。
- 直接分发 DMG。
- Notarization。
- 权限 onboarding。
- 崩溃日志和诊断信息。
- 多 macOS 版本兼容测试。

## 技术决策建议

### 推荐技术栈

- Swift + AppKit。
- SwiftUI 可用于设置页，但 overlay 建议 AppKit `NSPanel` 控制。
- Accessibility API：AXUIElement / AXObserver。
- AppleScript 或 ScriptingBridge 获取 Finder paths。
- 本地 JSON 或 SQLite 存 favorites / recents。
- 直接分发，不走 App Store。

### MVP 最小闭环

```text
检测 Open / Save dialog
→ 贴右侧 NSPanel
→ 展示 Favorites / Finder Windows / Recents / Clipboard
→ 点击路径
→ Command+Shift+G
→ 填 path
→ Return
→ 记录 recent
```

这个闭环能证明核心价值。

### 不建议路线

- 不做 Finder 注入。
- 不要求关闭 SIP。
- 不尝试修改系统 dialog 内部 view。
- 不用私有 API。
- 不把第一版做成 Finder replacement。

## 一句话总结

DFX 的核心不是替换 Open / Save dialog，而是在系统 dialog 周边贴一个 companion UI，并把 Favorites、Recent Folders、Finder Windows 等高频路径来源接入当前 dialog。自研版可以用 Accessibility 检测和定位 dialog，用 `NSPanel` 画贴边 UI，用 AppleScript / ScriptingBridge 获取 Finder paths，再通过 `Command+Shift+G` 自动化驱动 dialog 跳转。第一版完全可行，关键是接受“overlay + UI automation”这条非注入路线，而不是寻找不存在的跨进程 `setDirectoryURL` 官方 API。

---

## 补充意见：MVP 收敛和实现风险

### 核心判断

这个方向可行，但它本质上不是系统级 file panel extension，而是：

```text
Accessibility watcher
+ companion NSPanel
+ folder source aggregator
+ UI automation jumper
```

也就是说，它不是“控制系统 dialog”，而是“观察系统 dialog，然后像用户一样操作它”。Apple 没有提供给第三方 app 跨进程调用当前 `NSOpenPanel` / `NSSavePanel` 的稳定公开 API，所以不要追求优雅的官方 hook。第一版应该追求可恢复、可解释、失败时不烦人的 automation。

### MVP 应该先砍到最小闭环

原 MVP 里包含 Favorites、Finder Windows、Recent Folders、Clipboard Path。建议第一轮进一步收敛，只验证最危险的闭环：

```text
检测 Open / Save dialog
→ 贴边显示 NSPanel
→ 一个按钮：Jump to Clipboard Folder
→ 通过 Command+Shift+G 跳转
```

原因：这个闭环会同时验证三个最高风险点：

- dialog 检测是否靠谱。
- overlay 定位是否靠谱。
- 跳转 automation 是否靠谱。

Favorites、Finder Windows、Recents 本质都是 folder source。核心闭环不稳时，folder source 做得再完整也没有意义。

建议阶段顺序：

```text
P0: Clipboard Path only
P1: Favorites
P2: Finder Windows
P3: Recent Folders / per-app recents
P4: AX text field direct write，替代 pasteboard
```

### Pasteboard 方案只能作为 prototype transport

`Command+Shift+G` + pasteboard + paste + restore clipboard 适合快速验证，但不适合作为长期生产路径。

风险：

- 用户剪贴板可能包含敏感内容。
- 跳转失败时可能没恢复。
- 用户同时复制内容时会产生 race。
- clipboard manager 会记录临时 path。
- 用户感知上比较脏。

更稳的长期方案是：打开 Go to Folder sheet 后，通过 Accessibility 找到输入框，优先 `AXUIElementSetAttributeValue` 写入 path；失败时再 fallback 到键盘输入或 pasteboard。

结论：

```text
Prototype: pasteboard transport
Production: AX direct write first, pasteboard fallback only
```

### Open / Save dialog 检测必须保守

误显示 overlay 比漏显示更烦。第一版不要为了多支持几个 app，把识别逻辑写得太激进。

建议只在 frontmost app 的 focused window 满足以下特征时显示：

- window role / subrole 像 dialog、sheet、system dialog 或标准 window。
- 有 Cancel 按钮。
- 有 Open / Save / Choose / Export 等确认按钮，标题只作为辅助信号。
- 子树里存在 file panel 常见元素，例如 browser、outline、table、path control、search field、filename text field。
- frame 尺寸接近标准 file panel。

需要注意中文系统和其他语言环境。不要只依赖按钮标题。标题可以参与评分，但不应该是唯一判断。

建议策略：

```text
宁可漏掉非标准 dialog
不要在普通 app modal / settings / login / export wizard 上误显示
```

后续可以加 allowlist / denylist：

```text
allowlist examples:
- TextEdit
- Preview
- Safari
- Chrome
- Finder-triggered native panels
- VS Code using native dialog

denylist examples:
- custom Electron dialog
- web page fake file picker
- app internal modal
```

### Overlay 应使用 nonactivating NSPanel

overlay 不应该被当成普通 app window。窗口管理建议用 AppKit `NSPanel`，SwiftUI 可以只负责 panel 内部 view。

推荐属性方向：

```text
NSPanel
- borderless
- nonactivatingPanel
- floating 或接近 modalPanel 的 window level
- collectionBehavior: canJoinAllSpaces / transient / fullScreenAuxiliary 视情况选择
- ignoresMouseEvents = false
```

点击 overlay 菜单项前必须保存：

- target app pid。
- target AX window element。
- target window frame。

执行跳转前重新激活 target app，并确认 focused window 仍然是之前捕获的 file dialog。否则快捷键可能发给 companion app 自己，或者发给错误窗口。

### Finder Windows 获取路径：AppleScript / ScriptingBridge 是现实路线

Finder window title 不等于可靠路径。Accessibility 只能拿到窗口结构和标题，不能稳定拿到语义路径。获取 Finder 当前窗口目录，AppleScript / ScriptingBridge 的 `target of window` 更现实。

需要处理两个产品问题。

#### 权限体验

第一次访问 Finder 会触发 Automation 权限。如果用户拒绝，Finder Windows menu 不能直接坏掉，应显示明确状态：

```text
Finder Windows unavailable
Grant Automation permission to read Finder window paths.
```

#### Finder window 语义

Finder 里可能存在：

- normal Finder window。
- search result window。
- smart folder。
- network folder。
- iCloud folder。
- unavailable volume。

FinderWindowProvider 不应该只返回 string，建议返回结构：

```text
displayName
path
exists
isDirectory
source
error?
```

菜单只显示可跳转目录，异常项灰掉并提供原因。

### Recents 先只记录本工具成功跳转过的目录

不要第一版读取系统 recent。系统 recent 语义复杂，也有隐私问题。

第一版只记录本 app 成功触发过的跳转：

```text
path
lastUsedAt
useCount
bundleIdentifier
displayName cache
```

后续再做 per-app recents：

```text
Chrome save dialog 常用 Downloads/export
Xcode open dialog 常用 repo root
Photoshop open dialog 常用 assets
```

per-app recent 比全局 recent 更接近 DFX 的实际价值。

### 最大风险是时序，不是 API

跳转流程里每一步都可能慢半拍：

```text
activate target app
send Command+Shift+G
wait Go to Folder sheet
fill path
press Return
wait directory changes
```

不要依赖固定 sleep。固定 50-150ms 可以用于 prototype，但日用版本应该是状态机：

```text
Idle
→ TargetCaptured
→ SendingGoToFolder
→ WaitingForGoToFolderField
→ FillingPath
→ Confirming
→ VerifyingOrTimeout
→ Done / Failed
```

失败要能解释：

```text
Could not find Go to Folder input.
Path does not exist.
Target dialog disappeared.
Accessibility permission missing.
Automation permission missing.
```

用户能理解失败原因，就不会觉得 app 随机抽风。

### 推荐重新定义第一版

#### P0：技术验证版

只做：

```text
menu bar app
Accessibility permission check
detect standard Open / Save panel
show right-side NSPanel
button: Clipboard Folder
jump via Command+Shift+G
simple failure toast / log
```

验收标准：

```text
TextEdit Save 可用
Preview Open 可用
Safari Upload/Open 可用
Chrome Save/Open 可用
dialog move / resize 时 overlay 跟随
dialog close 后 overlay 消失
```

#### P1：可自用版

增加：

```text
Favorites JSON
Favorites menu
successful jump recents
basic settings
permission onboarding
```

#### P2：接近 DFX 核心体验

增加：

```text
Finder Windows menu
per-app recents
AX direct write Go to Folder field
更完整失败提示
```

### 最担心的坑

#### 坑 1：误把普通 modal 当 file dialog

例如 app 自己的设置窗口、导出窗口、登录窗口。解决方式是宁可漏掉，也别乱显示。

#### 坑 2：overlay 抢焦点后快捷键发给自己

点击前 capture target，执行前重新 activate target app，并确认 focused window 还是目标 dialog。

#### 坑 3：Go to Folder sheet 找不到

不同 macOS 版本、系统语言、app 状态下 AX 树可能不同。不要只按 title 匹配。应按 role、focused text field、sheet 层级和可编辑状态综合判断。

#### 坑 4：多语言系统

Open / Save / Cancel / Choose 这些标题会本地化。结构特征应该优先，标题只辅助。

#### 坑 5：安全感和权限解释

这个工具需要 Accessibility 和 Finder Automation 权限，用户会敏感。产品文案必须透明：

```text
We use Accessibility only to detect file dialogs and send standard keyboard shortcuts.
We use Finder Automation only to read open Finder window paths.
We do not read file contents.
We do not upload anything.
```

## 补充调研结果：暂无可信开源免费替代品

围绕“必须增强其他 App 的系统 Open / Save dialog”继续搜索后，暂未找到可信的开源免费程序可以直接替代自研。

明确满足核心需求的成熟产品仍然是 Default Folder X，但它是闭源付费软件。Hammerspoon 可以脚本化 `Command+Shift+G` 跳转，Peekaboo 可以作为 dialog automation 技术参考，但二者都不是 DFX-style 常驻 companion UI。mq-dir、Forklift、Marta、Commander One、OpenInTerminal 等属于 file manager / Finder workflow 工具，不增强其他 App 已经弹出的 Open / Save dialog，因此不满足首要核心需求。

结论：

```text
如果目标是立刻解决个人效率问题：买 Default Folder X。
如果目标是开源免费且必须增强 Open / Save dialog：目前没找到现成可用替代品。
如果目标是做 DFX-lite：自研仍然有必要，且第一版应只打穿 dialog 检测、overlay、path jump 这条闭环。
```
