# 鼠标侧键

一个 macOS 菜单栏小工具，把鼠标侧键改成常见的“后退 / 前进”导航行为。

## 功能

- 鼠标后退侧键 -> `Command + [`，用于浏览器、Finder 等应用后退。
- 鼠标前进侧键 -> `Command + ]`，用于浏览器、Finder 等应用前进。
- 拦截部分鼠标驱动生成的桌面切换快捷键：
  - `Control + 左方向键` -> `Command + [`
  - `Control + 右方向键` -> `Command + ]`
- 可单独反转普通鼠标滚轮方向，触控板滚动保持系统方向。
- 以菜单栏 App 形式运行，不显示 Dock 图标。

## 环境要求

- macOS 13 或更新版本。
- Swift Package Manager。项目使用 `swift-tools-version: 6.3`，源码按 Swift 5 模式编译。

## 运行

推荐使用打包后的菜单栏 App：

```sh
scripts/package-app.sh
open -n dist/MouseBack.app
```

启动后，菜单栏会出现 `鼠标侧键`。菜单中可以查看运行状态和权限状态：

- `运行中`：事件监听已启动。
- `仅鼠标可用；需要输入监控`：鼠标侧键可用，但无法拦截 `Control + 左/右方向键`。
- `仅键盘可用；需要辅助功能`：键盘快捷键拦截可用，但无法拦截鼠标侧键。
- `需要权限`：两个事件监听都没有启动。
- `辅助功能: 已授权`：可以拦截鼠标侧键。
- `输入监控: 已授权`：可以拦截鼠标驱动生成的快捷键。
- `反转鼠标滚轮`：单独控制普通鼠标滚轮方向，关闭后不处理滚轮事件。

也可以直接用 SwiftPM 调试运行：

```sh
swift run MouseBack
```

## 权限设置

macOS 需要授权后，应用才能监听和改写全局输入事件。

如果菜单显示 `需要权限`，请打开：

```text
系统设置 > 隐私与安全性 > 辅助功能
系统设置 > 隐私与安全性 > 输入监控
```

在两个列表中都添加并开启：

```text
/Users/vital/Projects/mouse-back/dist/MouseBack.app
```

授权后，在菜单栏中点击 `重新检查权限`，或退出后重新打开 App。

菜单里的 `打开隐私设置` 会打开 macOS 隐私设置页面。由于系统设置只能定位到隐私入口，仍需要手动进入 `辅助功能` 和 `输入监控` 两个列表确认开关。

## 常见问题

### 设置里已经打开权限，但菜单仍显示未授权

开发阶段使用的是 ad-hoc 签名。每次重新打包后，macOS 可能会把它当成一个新的 App。解决方式：

1. 在 `辅助功能` 和 `输入监控` 里删除旧的 `MouseBack` / `鼠标侧键` 项。
2. 重新添加 `dist/MouseBack.app`。
3. 打开开关。
4. 重启 App 或点击 `重新检查权限`。

也可以先重置本项目的权限记录：

```sh
scripts/reset-permissions.sh
```

### 侧键方向反了

当前默认映射是：

- 鼠标按钮 `3` -> 后退
- 鼠标按钮 `4` -> 前进

如果你的鼠标方向相反，可以修改 `Sources/MouseBack/MouseBack.swift` 中 `keyCode(forMouseButton:)` 的 `case 3` 和 `case 4` 返回值。

### 鼠标和触控板滚动方向冲突

建议在系统设置中保持 `自然滚动` 开启，让触控板方向正常；然后在菜单中开启 `反转鼠标滚轮`。应用会放行带有触控板滚动阶段的事件，并把普通鼠标滚轮事件替换成反向滚动事件。

如果你的鼠标滚轮本身已经正常，或设备被识别不符合预期，可以在菜单中关闭 `反转鼠标滚轮`。这个开关会自动保存，下次启动仍保持上次状态。

如果开关打开后仍没有效果，优先检查菜单中的权限状态。重新打包会改变 ad-hoc 签名，macOS 可能要求重新添加 `辅助功能` 和 `输入监控` 权限。

### SwiftPM 直接运行和打包 App 的权限不一致

macOS 权限绑定到具体可执行程序或 App。`swift run MouseBack`、`.build/release/MouseBack` 和 `dist/MouseBack.app` 可能会被系统视为不同对象。日常使用建议以 `dist/MouseBack.app` 为准。

## 开发命令

```sh
swift build
```

编译调试版本，确认代码能通过 SwiftPM 构建。

当前没有测试目标。改动后至少运行 `swift build`；如果改了事件监听、权限或菜单行为，还需要重新打包并手动验证。

```sh
scripts/package-app.sh
```

构建 release 版本并生成：

```text
dist/MouseBack.app
```

```sh
scripts/reset-permissions.sh
```

重置 `local.mouseback.app` 的 macOS 权限记录。

## GitHub 自动发布

仓库包含两个 GitHub Actions 工作流：

- `.github/workflows/ci.yml`：push 到 `main` 或打开 pull request 时运行 `swift build`。
- `.github/workflows/release.yml`：推送 `v*` 标签时打包 `dist/MouseBack.app`，压缩为 `MouseBack.app.zip`，并上传到 GitHub Release。

发布流程会把 tag 版本写入 `CFBundleShortVersionString`，例如 `v0.1.0` 会生成版本号为 `0.1.0` 的 App。当前发布包使用 ad-hoc 签名，未做 Developer ID 签名和 Apple notarization；从 GitHub Release 下载后，macOS 可能需要用户手动允许打开。

发布新版本示例：

```sh
git tag v0.1.0
git push origin main --tags
```

## 项目结构

```text
.github/workflows/ci.yml
.github/workflows/release.yml
Package.swift
Sources/MouseBack/MouseBack.swift
scripts/package-app.sh
scripts/reset-permissions.sh
```

核心逻辑集中在 `Sources/MouseBack/MouseBack.swift`，包括菜单栏 UI、权限检测、事件监听和快捷键发送。

生成目录 `.build/`、`dist/` 和本地日志不属于源代码。
