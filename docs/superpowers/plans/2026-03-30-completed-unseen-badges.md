# Completed-Unseen Badge States Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two new badge states (`completedUnseen`, `terminalCompletedUnseen`) that show vivid colors when a tab finishes work while unfocused, clearing when the user visits the tab.

**Architecture:** Extend the existing `BadgeState` enum with two new cases. Intercept the idle-transition points (hook handler for Claude, process monitor for terminals) to check focus and set the unseen state instead. Clear the unseen state when the user selects a tab.

**Tech Stack:** Swift, AppKit, UserDefaults

---

### Task 1: Add new BadgeState enum cases

**Files:**
- Modify: `Sources/Window/DeckardWindowController.swift:24-34`

- [ ] **Step 1: Add two new cases to BadgeState**

In `Sources/Window/DeckardWindowController.swift`, add two new cases to the `BadgeState` enum (after `terminalError`):

```swift
enum BadgeState: String {
    case none
    case idle             // grey - connected but no activity yet
    case thinking
    case waitingForInput
    case needsPermission
    case error
    case terminalIdle     // muted teal - terminal at prompt
    case terminalActive   // teal pulsing - terminal foreground process has activity
    case terminalError    // red - terminal process exited with error
    case completedUnseen        // vivid purple - Claude finished while tab unfocused
    case terminalCompletedUnseen // vivid teal - terminal finished while tab unfocused
}
```

- [ ] **Step 2: Build to verify no compiler errors**

Run: `xcodebuild -project Deckard.xcodeproj -scheme Deckard -configuration Debug build 2>&1 | tail -5`

The build will fail because the new enum cases aren't handled in the `switch` in `tooltipForBadge`. That's expected and will be fixed in the next task.

- [ ] **Step 3: Commit**

```bash
git add Sources/Window/DeckardWindowController.swift
git commit -m "feat: add completedUnseen and terminalCompletedUnseen badge states"
```

---

### Task 2: Add default colors and tooltips for new states

**Files:**
- Modify: `Sources/Window/SidebarViews.swift:146-178`

- [ ] **Step 1: Add tooltip cases**

In `Sources/Window/SidebarViews.swift`, in the `tooltipForBadge` method (line 146), add cases for the two new states before the closing brace:

```swift
static func tooltipForBadge(_ state: TabItem.BadgeState, activity: ProcessMonitor.ActivityInfo? = nil) -> String {
    switch state {
    case .none: return ""
    case .idle: return "Idle"
    case .thinking: return "Thinking..."
    case .waitingForInput: return "Waiting for input"
    case .needsPermission: return "Needs permission"
    case .error: return "Error"
    case .terminalIdle: return "Idle"
    case .terminalActive: return activity?.description ?? "Running"
    case .terminalError: return "Error"
    case .completedUnseen: return "Done (unvisited)"
    case .terminalCompletedUnseen: return "Done (unvisited)"
    }
}
```

- [ ] **Step 2: Add default colors**

In `Sources/Window/SidebarViews.swift`, add entries to the `defaultBadgeColors` dictionary (line 160):

```swift
static let defaultBadgeColors: [TabItem.BadgeState: NSColor] = [
    .idle: .systemGray,
    .thinking: NSColor(red: 0.85, green: 0.65, blue: 0.2, alpha: 1.0),
    .waitingForInput: NSColor(red: 0.65, green: 0.4, blue: 0.9, alpha: 1.0),
    .needsPermission: .systemOrange,
    .error: .systemRed,
    .terminalIdle: NSColor(red: 0.35, green: 0.55, blue: 0.54, alpha: 1.0),
    .terminalActive: NSColor(red: 0.45, green: 0.72, blue: 0.71, alpha: 1.0),
    .terminalError: NSColor(red: 0.85, green: 0.3, blue: 0.3, alpha: 1.0),
    .completedUnseen: NSColor(red: 0.75, green: 0.45, blue: 1.0, alpha: 1.0),
    .terminalCompletedUnseen: NSColor(red: 0.3, green: 0.75, blue: 0.73, alpha: 1.0),
]
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -project Deckard.xcodeproj -scheme Deckard -configuration Debug build 2>&1 | tail -5`

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add Sources/Window/SidebarViews.swift
git commit -m "feat: add default colors and tooltips for completed-unseen badges"
```

---

### Task 3: Set completedUnseen state for Claude tabs

**Files:**
- Modify: `Sources/Detection/HookHandler.swift:24-29`
- Modify: `Sources/Window/DeckardWindowController.swift:1043-1050`

The key insight: when a Claude tab transitions to `waitingForInput` and the tab is not focused, we should set `completedUnseen` instead. However, the initial `hook.session-start` should always use `waitingForInput` (not mark as unseen on first connect). The `hook.notification` non-permission case should also not trigger unseen (it's informational, not "work finished").

The cleanest approach: add a method `updateBadgeWithUnseenCheck` that conditionally substitutes the unseen state.

- [ ] **Step 1: Add `updateBadgeWithUnseenCheck` to DeckardWindowController**

In `Sources/Window/DeckardWindowController.swift`, add this method right after the existing `updateBadge` method (after line 1050):

```swift
/// Like updateBadge, but substitutes completedUnseen/terminalCompletedUnseen
/// when the tab transitions to an idle state while unfocused.
func updateBadgeToIdleOrUnseen(forSurfaceId surfaceIdStr: String, isClaude: Bool) {
    guard let tab = tabForSurfaceId(surfaceIdStr) else { return }
    let wasBusy = isClaude ? (tab.badgeState == .thinking) : (tab.badgeState == .terminalActive)
    let focused = isTabFocused(surfaceIdStr)
    let idleState: TabItem.BadgeState = isClaude ? .waitingForInput : .terminalIdle
    let unseenState: TabItem.BadgeState = isClaude ? .completedUnseen : .terminalCompletedUnseen
    let newState = (wasBusy && !focused) ? unseenState : idleState
    DiagnosticLog.shared.log("badge",
        "updateBadgeToIdleOrUnseen: surfaceId=\(surfaceIdStr) wasBusy=\(wasBusy) focused=\(focused) -> \(newState)")
    tab.badgeState = newState
    rebuildSidebar()
    rebuildTabBar()
}
```

- [ ] **Step 2: Update HookHandler to use unseen check for `hook.stop`**

In `Sources/Detection/HookHandler.swift`, change the `hook.stop` / `hook.stop-failure` case (line 24-29) from:

```swift
        case "hook.stop", "hook.stop-failure":
            // Claude finished responding (or hit a limit/error) — waiting for user input
            if let surfaceId = message.surfaceId {
                windowController?.updateBadge(forSurfaceId: surfaceId, state: .waitingForInput)
            }
```

to:

```swift
        case "hook.stop", "hook.stop-failure":
            // Claude finished responding — mark as unseen if tab isn't focused
            if let surfaceId = message.surfaceId {
                windowController?.updateBadgeToIdleOrUnseen(forSurfaceId: surfaceId, isClaude: true)
            }
```

Note: `hook.session-start` and `hook.notification` keep using `updateBadge` directly — session start is not "completed work" and notifications are informational.

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -project Deckard.xcodeproj -scheme Deckard -configuration Debug build 2>&1 | tail -5`

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add Sources/Detection/HookHandler.swift Sources/Window/DeckardWindowController.swift
git commit -m "feat: set completedUnseen badge when Claude finishes while tab unfocused"
```

---

### Task 4: Set terminalCompletedUnseen state for terminal tabs

**Files:**
- Modify: `Sources/Window/DeckardWindowController.swift:905-934`

- [ ] **Step 1: Update `applyTerminalBadgeStates` to check focus**

In `Sources/Window/DeckardWindowController.swift`, modify `applyTerminalBadgeStates` (line 905). The logic change: when a terminal tab transitions from `terminalActive` to idle and the tab is not focused, use `terminalCompletedUnseen` instead of `terminalIdle`. Also, if the tab is currently `terminalCompletedUnseen` and still idle, keep it as `terminalCompletedUnseen`.

Replace the method body (lines 905-934) with:

```swift
    private func applyTerminalBadgeStates(_ states: [UUID: ProcessMonitor.ActivityInfo]) {
        var changed = false
        for project in projects {
            for tab in project.tabs where !tab.isClaude {
                let activity = states[tab.id] ?? ProcessMonitor.ActivityInfo()

                // Require 2 consecutive active polls to transition to terminalActive.
                // This filters single-poll spikes from process changes or scheduler noise.
                let streak = (terminalActiveStreak[tab.id] ?? 0)
                let newStreak = activity.isActive ? streak + 1 : 0
                terminalActiveStreak[tab.id] = newStreak
                let confirmedActive = newStreak >= 2

                let newBadge: TabItem.BadgeState
                if confirmedActive {
                    newBadge = .terminalActive
                } else if tab.badgeState == .terminalActive {
                    // Transitioning from active to idle — check focus
                    let focused = isTabFocused(tab.id.uuidString)
                    newBadge = focused ? .terminalIdle : .terminalCompletedUnseen
                } else if tab.badgeState == .terminalCompletedUnseen {
                    // Stay unseen until tab is visited (cleared elsewhere)
                    newBadge = .terminalCompletedUnseen
                } else {
                    newBadge = .terminalIdle
                }

                terminalActivity[tab.id] = activity
                if tab.badgeState != newBadge {
                    if newBadge == .terminalActive {
                        DiagnosticLog.shared.log("processmon",
                            "badge -> terminalActive: project=\(project.path) tab=\"\(tab.name)\"")
                    }
                    tab.badgeState = newBadge
                    changed = true
                }
            }
        }
        if changed {
            rebuildSidebar()
            rebuildTabBar()
        }
    }
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project Deckard.xcodeproj -scheme Deckard -configuration Debug build 2>&1 | tail -5`

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add Sources/Window/DeckardWindowController.swift
git commit -m "feat: set terminalCompletedUnseen badge when terminal finishes while unfocused"
```

---

### Task 5: Clear unseen state when tab is visited

**Files:**
- Modify: `Sources/Window/DeckardWindowController.swift:755-772`

When the user selects a tab (via `selectTabInProject` or `switchToTab`), if the tab is in a `completedUnseen` or `terminalCompletedUnseen` state, instantly revert to the corresponding idle state.

- [ ] **Step 1: Add a helper method to clear unseen state**

In `Sources/Window/DeckardWindowController.swift`, add this method right before `selectTabInProject` (before line 755):

```swift
    /// If the tab is in a completedUnseen state, revert to the normal idle state.
    private func clearUnseenIfNeeded(_ tab: TabItem) {
        switch tab.badgeState {
        case .completedUnseen:
            tab.badgeState = .waitingForInput
            rebuildSidebar()
            rebuildTabBar()
        case .terminalCompletedUnseen:
            tab.badgeState = .terminalIdle
            rebuildSidebar()
            rebuildTabBar()
        default:
            break
        }
    }
```

- [ ] **Step 2: Call `clearUnseenIfNeeded` from `selectTabInProject`**

In `Sources/Window/DeckardWindowController.swift`, modify `selectTabInProject` (line 755) to clear unseen after switching:

```swift
    func selectTabInProject(at tabIndex: Int) {
        guard let project = currentProject else { return }
        guard tabIndex >= 0, tabIndex < project.tabs.count else { return }
        project.selectedTabIndex = tabIndex
        clearUnseenIfNeeded(project.tabs[tabIndex])
        rebuildTabBar()
        showTab(project.tabs[tabIndex])
    }
```

- [ ] **Step 3: Call `clearUnseenIfNeeded` from `switchToTab`**

In `Sources/Window/DeckardWindowController.swift`, modify `switchToTab` (line 766) to clear unseen after switching:

```swift
    /// Switch to a tab without rebuilding the tab bar.
    /// Called from HorizontalTabView.mouseDown so the terminal switch
    /// is not lost if an async rebuild destroys the view before mouseUp.
    func switchToTab(at tabIndex: Int) {
        guard let project = currentProject else { return }
        guard tabIndex >= 0, tabIndex < project.tabs.count else { return }
        guard tabIndex != project.selectedTabIndex else { return }
        project.selectedTabIndex = tabIndex
        clearUnseenIfNeeded(project.tabs[tabIndex])
        showTab(project.tabs[tabIndex])
    }
```

- [ ] **Step 4: Clear unseen when switching projects too**

In `Sources/Window/DeckardWindowController.swift`, in `selectProject(at:)` (line 547), the currently selected tab of the target project should also be cleared. Add after line 561 (`rebuildTabBar()`):

```swift
    func selectProject(at index: Int, autoExpandFolder: Bool = true) {
        guard index >= 0, index < projects.count else { return }
        selectedProjectIndex = index

        let project = projects[index]

        // Auto-expand folder if the selected project is inside a collapsed one
        if autoExpandFolder {
            for folder in sidebarFolders where folder.isCollapsed && folder.projectIds.contains(project.id) {
                folder.isCollapsed = false
                rebuildSidebar()
            }
        }

        rebuildTabBar()

        if project.tabs.isEmpty {
            currentTerminalView = nil
            showEmptyState()
        } else {
            // Always clamp for safe array access, even during restore
            let safeIdx = max(0, min(project.selectedTabIndex, project.tabs.count - 1))
            clearUnseenIfNeeded(project.tabs[safeIdx])
            showTab(project.tabs[safeIdx])
        }
```

- [ ] **Step 5: Build to verify**

Run: `xcodebuild -project Deckard.xcodeproj -scheme Deckard -configuration Debug build 2>&1 | tail -5`

Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: Commit**

```bash
git add Sources/Window/DeckardWindowController.swift
git commit -m "feat: clear completed-unseen badge when tab is visited"
```

---

### Task 6: Add new states to Settings UI

**Files:**
- Modify: `Sources/Window/SettingsWindow.swift:684-696`

- [ ] **Step 1: Add entries to badge tables**

In `Sources/Window/SettingsWindow.swift`, add the new state to the `claudeBadgeEntries` array (line 684) and `terminalBadgeEntries` array (line 692):

```swift
    private static let claudeBadgeEntries: [(state: TabItem.BadgeState, label: String)] = [
        (.idle, "Idle"),
        (.thinking, "Thinking"),
        (.waitingForInput, "Ready"),
        (.needsPermission, "Needs Permission"),
        (.error, "Error"),
        (.completedUnseen, "Done (Unvisited)"),
    ]

    private static let terminalBadgeEntries: [(state: TabItem.BadgeState, label: String)] = [
        (.terminalIdle, "Idle"),
        (.terminalActive, "Busy"),
        (.terminalError, "Error"),
        (.terminalCompletedUnseen, "Done (Unvisited)"),
    ]
```

No other changes needed in Settings — the `resetBadgeColors` method already iterates `claudeBadgeEntries + terminalBadgeEntries`, so it will automatically include the new states. The `makeBadgeColorGrid` function builds the UI from these arrays, so the new rows appear automatically. The `defaultBadgeAnimated` set does not include these states, so animation defaults to off — correct behavior.

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project Deckard.xcodeproj -scheme Deckard -configuration Debug build 2>&1 | tail -5`

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add Sources/Window/SettingsWindow.swift
git commit -m "feat: add completed-unseen badge states to Settings UI"
```

---

### Task 7: Handle edge case — also check `needsPermission` as a busy state

**Files:**
- Modify: `Sources/Window/DeckardWindowController.swift` (the `updateBadgeToIdleOrUnseen` method from Task 3)

The `needsPermission` state means Claude asked for permission (which is a form of "busy/active"). If the user grants permission from the notification and Claude finishes while the tab is unfocused, `tab.badgeState` would be `.needsPermission` at the moment `hook.stop` fires. The `wasBusy` check should include `.needsPermission` too.

- [ ] **Step 1: Expand the wasBusy check**

Update the `updateBadgeToIdleOrUnseen` method. Change:

```swift
    let wasBusy = isClaude ? (tab.badgeState == .thinking) : (tab.badgeState == .terminalActive)
```

to:

```swift
    let wasBusy = isClaude
        ? (tab.badgeState == .thinking || tab.badgeState == .needsPermission)
        : (tab.badgeState == .terminalActive)
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project Deckard.xcodeproj -scheme Deckard -configuration Debug build 2>&1 | tail -5`

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add Sources/Window/DeckardWindowController.swift
git commit -m "fix: treat needsPermission as busy state for completed-unseen detection"
```
