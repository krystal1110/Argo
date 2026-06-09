# 顶部时间命令入口实现计划

> **给 agentic workers：** 必须使用子技能：推荐 `superpowers:subagent-driven-development`，也可以使用 `superpowers:executing-plans` 按任务逐项执行。本计划使用 checkbox（`- [ ]`）跟踪进度。

**目标：** 把顶部玻璃栏里的宽版命令面板入口替换成“无背景时段图标 + 当前时间 + Open Command Palette + 当前真实快捷键”的内嵌胶囊按钮。

**架构：** 把可测试的时段判断、时间格式化、命令面板快捷键展示文本放到一个小型支持文件中，SwiftUI 顶部栏只负责渲染和派发原有 `toggleCommandPalette` 动作。UI 不改命令面板弹层、不改命令列表、不引入定位、日出日落 API 或额外权限。命令面板默认快捷键改为 `⇧⌘P`，避免 `⌘P` 和快速打开/搜索语义混淆。

**技术栈：** Swift、SwiftUI、Foundation `Calendar`/`Date`、XCTest、Xcode filesystem-synchronized groups。

---

## 文件结构

- 新建 `Argo/Support/TimeCommandPaletteSupport.swift`
  - 负责时段枚举、小时区间判断、`HH:mm` 时间文本格式化、命令面板快捷键文案。
- 新建 `Tests/TimeCommandPaletteSupportTests.swift`
  - 覆盖早上、下午、日落、夜间 fallback 的时段边界、两位数 24 小时时间格式，以及默认/自定义/禁用快捷键文案。
- 修改 `Argo/UI/MainWindowView.swift`
  - 用新的时间命令胶囊替换现有宽版 `Command Palette` 按钮 label。
  - 增加分钟级时间刷新状态。
  - 图标去掉背景，只用时段颜色；胶囊改成暗色内嵌槽效果。
  - 保留原来的 `store.dispatch(.toggleCommandPalette)`、`accessibilityLabel` 和 `help`。

不改动：

- `Argo/UI/Components/CommandPaletteView.swift`
- `Argo/App/WorkspaceStore.swift`
- `Argo/Support/WorkspaceCommands.swift`
- 命令面板弹层、命令列表、命令执行逻辑

## 精修补充：跟随真实快捷键和内嵌视觉

**Files:**
- Modify: `Argo/Support/TimeCommandPaletteSupport.swift`
- Modify: `Tests/TimeCommandPaletteSupportTests.swift`
- Modify: `Argo/UI/MainWindowView.swift`

- [x] **Step 1: 先写失败测试**

新增测试覆盖：

- 默认设置下显示 `Open Command Palette (⇧⌘P)`。
- 用户把命令面板快捷键改成 `⇧⌘K` 后，顶部文案跟随显示 `Open Command Palette (⇧⌘K)`。
- 用户禁用命令面板快捷键后，只显示 `Open Command Palette`。

RED 结果：聚焦测试编译失败，错误为 `cannot find 'TimeCommandPaletteCommandDisplay' in scope`。

- [x] **Step 2: 实现快捷键文案支持**

在 `TimeCommandPaletteSupport.swift` 中新增 `TimeCommandPaletteCommandDisplay`，从 `ArgoKeyboardShortcuts.effectiveShortcut(for: .toggleCommandPalette, in:)` 读取当前真实快捷键；禁用时不显示括号。

- [x] **Step 3: 精修 SwiftUI 视觉**

在 `TimeCommandPaletteButtonLabel` 中：

- 去掉图标圆形渐变背景和外发光。
- 日落时段使用红色 `sunset.fill`。
- 文案改成 `HH:mm – Open Command Palette (快捷键)`。
- 胶囊改成暗色内嵌槽，弱描边和顶部内阴影，不再使用突出键帽。

## 快捷键修正：命令面板默认改为 `⇧⌘P`

**Files:**
- Modify: `Argo/Domain/AppSettings.swift`
- Modify: `Tests/QuickCommandSupportTests.swift`
- Modify: `Tests/TimeCommandPaletteSupportTests.swift`

- [x] **Step 1: 先写失败测试**

新增或更新测试覆盖：

- `TimeCommandPaletteCommandDisplay` 默认显示 `Open Command Palette (⇧⌘P)`。
- `ArgoKeyboardShortcuts.effectiveShortcut(for: .toggleCommandPalette, in:)` 默认返回 `⇧⌘P`。
- `⌘P` 默认不匹配 `toggleCommandPalette`。
- `⇧⌘P` 默认匹配 `toggleCommandPalette`。
- 把 `⇧⌘P` 分配给其他动作会禁用命令面板，证明冲突处理仍然生效。

RED 结果：上述聚焦测试失败，旧实现仍返回和匹配 `⌘P`。

- [x] **Step 2: 实现默认快捷键修正**

在 `ArgoShortcutAction.toggleCommandPalette.defaultShortcut` 中把默认值从 `StoredShortcut(key: "p", command: true, shift: false, option: false, control: false)` 改为 `StoredShortcut(key: "p", command: true, shift: true, option: false, control: false)`。

## Task 1: 写时段和时间格式的失败测试

**Files:**
- Create: `Tests/TimeCommandPaletteSupportTests.swift`

- [ ] **Step 1: 新建失败测试文件**

创建 `Tests/TimeCommandPaletteSupportTests.swift`，内容如下：

```swift
//
//  TimeCommandPaletteSupportTests.swift
//  ArgoTests
//
//  Author: krystal
//

import XCTest
@testable import Argo

final class TimeCommandPaletteSupportTests: XCTestCase {
    func testPhaseUsesMorningAfternoonSunsetAndNightFallbackRanges() {
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: 5), .morning)
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: 11), .morning)
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: 12), .afternoon)
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: 16), .afternoon)
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: 17), .sunset)
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: 19), .sunset)
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: 20), .night)
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: 4), .night)
    }

    func testPhaseNormalizesOutOfRangeHours() {
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: 29), .morning)
        XCTAssertEqual(TimeCommandPalettePhase.phase(forHour: -1), .night)
    }

    func testTimeTextUsesTwoDigitTwentyFourHourClock() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try XCTUnwrap(DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 8,
            hour: 9,
            minute: 4
        ).date)

        XCTAssertEqual(TimeCommandPaletteClock.timeText(for: date, calendar: calendar), "09:04")
    }

    func testPhaseUsesCalendarHourFromDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try XCTUnwrap(DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 8,
            hour: 18,
            minute: 48
        ).date)

        XCTAssertEqual(TimeCommandPaletteClock.phase(for: date, calendar: calendar), .sunset)
    }
}
```

- [ ] **Step 2: 运行聚焦测试确认 RED**

运行：

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/TimeCommandPaletteSupportTests \
  test
```

预期：编译失败，错误包含 `cannot find 'TimeCommandPalettePhase' in scope` 或 `cannot find 'TimeCommandPaletteClock' in scope`。

## Task 2: 实现可测试的时间命令支持逻辑

**Files:**
- Create: `Argo/Support/TimeCommandPaletteSupport.swift`
- Test: `Tests/TimeCommandPaletteSupportTests.swift`

- [ ] **Step 1: 新建支持文件**

创建 `Argo/Support/TimeCommandPaletteSupport.swift`，内容如下：

```swift
//
//  TimeCommandPaletteSupport.swift
//  Argo
//
//  Author: krystal
//

import Foundation

enum TimeCommandPalettePhase: Equatable {
    case morning
    case afternoon
    case sunset
    case night

    static func phase(forHour hour: Int) -> TimeCommandPalettePhase {
        let normalizedHour = ((hour % 24) + 24) % 24
        switch normalizedHour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<20:
            return .sunset
        default:
            return .night
        }
    }
}

enum TimeCommandPaletteClock {
    static func phase(for date: Date, calendar: Calendar = .current) -> TimeCommandPalettePhase {
        TimeCommandPalettePhase.phase(forHour: calendar.component(.hour, from: date))
    }

    static func timeText(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return String(format: "%02d:%02d", hour, minute)
    }
}
```

- [ ] **Step 2: 运行聚焦测试确认 GREEN**

运行：

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/TimeCommandPaletteSupportTests \
  test
```

预期：`TimeCommandPaletteSupportTests` 全部通过。

- [ ] **Step 3: 提交测试和支持逻辑**

运行：

```sh
git add Argo/Support/TimeCommandPaletteSupport.swift Tests/TimeCommandPaletteSupportTests.swift
git commit -m "test: cover time command palette display"
```

## Task 3: 接入顶部玻璃栏按钮

**Files:**
- Modify: `Argo/UI/MainWindowView.swift`
- Test: `Tests/TimeCommandPaletteSupportTests.swift`

- [ ] **Step 1: 在 `MainWindowView` 添加当前时间状态**

在 `MainWindowView` 的状态属性附近，把：

```swift
    @State private var layoutState = MainWindowLayoutState()
```

替换为：

```swift
    @State private var layoutState = MainWindowLayoutState()
    @State private var commandPaletteClockDate = Date()
```

- [ ] **Step 2: 替换顶部命令面板按钮 label**

在 `topGlassChrome` 中找到现有命令面板按钮：

```swift
            Button {
                store.dispatch(.toggleCommandPalette)
            } label: {
                GlassToolbarGroup(horizontalPadding: 16, spacing: 8) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ArgoTheme.danger.opacity(0.95))
                    Text(localized("menu.view.commandPalette"))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(ArgoTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(minWidth: 230, idealWidth: 320, maxWidth: 360)
            }
```

替换为：

```swift
            Button {
                store.dispatch(.toggleCommandPalette)
            } label: {
                TimeCommandPaletteButtonLabel(date: commandPaletteClockDate)
            }
```

保留按钮后面的：

```swift
            .buttonStyle(.plain)
            .scaleEffect(uiScale)
            .accessibilityLabel(localized("menu.view.commandPalette"))
            .help(localized("menu.view.commandPalette"))
```

- [ ] **Step 3: 添加分钟级刷新**

在 `body` 末尾的 modifier 链中，保留现有 `.task`，并在它后面添加 `.onReceive`：

```swift
        .task {
            await store.refreshHAPIIntegrationStatus()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
            commandPaletteClockDate = date
        }
```

如果当前位置已经有 `.onReceive(NotificationCenter.default.publisher(...))`，把新的 timer `.onReceive` 放在 `.task` 后、通知 `.onReceive` 前，保持 modifier 顺序清晰。

- [ ] **Step 4: 添加私有 SwiftUI label view**

在 `private var toolbarMenuActionAssociationKey: UInt8 = 0` 之前添加：

```swift
private struct TimeCommandPaletteButtonLabel: View {
    let date: Date

    private var phase: TimeCommandPalettePhase {
        TimeCommandPaletteClock.phase(for: date)
    }

    private var timeText: String {
        TimeCommandPaletteClock.timeText(for: date)
    }

    private var iconSystemName: String {
        switch phase {
        case .morning:
            return "sunrise.fill"
        case .afternoon:
            return "sun.max.fill"
        case .sunset:
            return "sunset.fill"
        case .night:
            return "moon.stars.fill"
        }
    }

    private var iconGradientColors: [Color] {
        switch phase {
        case .morning:
            return [Color(red: 1.0, green: 0.88, blue: 0.52), Color(red: 1.0, green: 0.62, blue: 0.24)]
        case .afternoon:
            return [Color(red: 0.99, green: 0.95, blue: 0.45), Color(red: 0.22, green: 0.74, blue: 0.97)]
        case .sunset:
            return [Color(red: 0.98, green: 0.44, blue: 0.52), Color(red: 0.96, green: 0.62, blue: 0.08), Color(red: 0.19, green: 0.18, blue: 0.51)]
        case .night:
            return [Color(red: 0.36, green: 0.42, blue: 0.72), Color(red: 0.12, green: 0.16, blue: 0.29)]
        }
    }

    var body: some View {
        GlassToolbarGroup(horizontalPadding: 10, spacing: 8) {
            Image(systemName: iconSystemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.92))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: iconGradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: iconGradientColors.first?.opacity(0.22) ?? .clear, radius: 10, y: 4)

            Text(timeText)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(ArgoTheme.tertiaryText)
                .monospacedDigit()
                .frame(minWidth: 42, alignment: .leading)

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: 18)

            Text("Open command")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ArgoTheme.secondaryText)

            Text("P")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(ArgoTheme.tertiaryText)
                .padding(.horizontal, 6)
                .frame(height: 21)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        }
    }
}
```

- [ ] **Step 5: 运行聚焦测试确认支持逻辑仍然 GREEN**

运行：

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ArgoTests/TimeCommandPaletteSupportTests \
  test
```

预期：`TimeCommandPaletteSupportTests` 全部通过。

- [ ] **Step 6: 运行 Debug 构建确认 SwiftUI 接入可编译**

运行：

```sh
xcodebuild \
  -project Argo.xcodeproj \
  -scheme Argo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build
```

预期：构建成功。

- [ ] **Step 7: 提交 UI 接入**

运行：

```sh
git add Argo/UI/MainWindowView.swift
git commit -m "feat: add time command palette toolbar entry"
```

## Task 4: 手动冒烟验证与收尾

**Files:**
- No code changes expected

- [ ] **Step 1: 启动应用或使用本地 Debug 构建进行视觉检查**

运行当前团队常用的本地启动方式，或从 Xcode/Debug 构建产物启动 `Argo.app`。

检查：

- 顶部中间不再显示宽版 `Command Palette` 文案。
- 顶部中间显示一个玻璃胶囊，内容为时段图标、当前时间、`Open command`、`P`。
- 时间数字是两位小时和两位分钟，例如 `09:04`、`18:48`。
- 默认 UI 缩放下，工作区胶囊、时间命令胶囊、右侧工具组、外部编辑器胶囊之间没有重叠。

- [ ] **Step 2: 验证命令面板交互不变**

手动点击时间命令胶囊。

预期：

- 第一次点击打开现有 `CommandPaletteView`。
- 再次点击胶囊或按 Escape 可以关闭命令面板。
- 命令面板搜索框、上下选择、回车执行仍然按原行为工作。

- [ ] **Step 3: 查看最终 diff**

运行：

```sh
git status --short
git log --oneline -5
```

预期：

- `git status --short` 没有未提交改动。
- 最近提交包含支持逻辑测试提交和 UI 接入提交。
