# Completed-Unseen Badge States

## Summary

Add two new badge states that indicate a tab has finished its work while the user wasn't looking at it. This helps users identify which tabs have completed activity and haven't been revisited yet.

## New Badge States

### `completedUnseen` (Claude tabs)

- **Trigger:** A Claude tab transitions from `thinking` → `waitingForInput` while `isTabFocused()` returns false.
- **Default color:** Vivid/bright purple — a more saturated version of the `waitingForInput` purple.
- **Cleared by:** Selecting the tab (instantly reverts to `waitingForInput`) or new activity starting (`thinking` overwrites it).

### `terminalCompletedUnseen` (Terminal tabs)

- **Trigger:** A terminal tab transitions from `terminalActive` → `terminalIdle` while `isTabFocused()` returns false.
- **Default color:** Vivid/bright teal — a more saturated version of the `terminalIdle` muted teal.
- **Cleared by:** Selecting the tab (instantly reverts to `terminalIdle`) or new activity starting (`terminalActive` overwrites it).

## State Transition Rules

1. **Active → idle while unfocused:** Set `completedUnseen` / `terminalCompletedUnseen` instead of the normal idle state.
2. **Tab selected (visited):** If tab is in a `completedUnseen` state, instantly revert to corresponding idle state (`waitingForInput` / `terminalIdle`).
3. **New activity starts:** Normal active state (`thinking` / `terminalActive`) overwrites the unseen state — no special handling needed.
4. **Active → idle while focused:** Normal idle state applies — no unseen state set.

## Settings Integration

- Both new states appear in the existing badge color tables in Settings (Claude section and Terminal section respectively).
- Each gets a color well (user-overridable, stored as `badgeColor.completedUnseen` / `badgeColor.terminalCompletedUnseen` in UserDefaults).
- Each gets an animation toggle (default: off — these are "done" states, not "busy" states).
- The "Reset to Defaults" button clears these along with all other badge colors.

## Default Colors

| State | Default Color | Rationale |
|-------|--------------|-----------|
| `completedUnseen` | Bright/vivid purple `(0.75, 0.45, 1.0)` | Brighter version of `waitingForInput` `(0.65, 0.4, 0.9)` |
| `terminalCompletedUnseen` | Bright/vivid teal `(0.3, 0.75, 0.73)` | More saturated version of `terminalIdle` `(0.35, 0.55, 0.54)` |

## Affected Files

| File | Change |
|------|--------|
| `Sources/Window/DeckardWindowController.swift` | Add enum cases, clear unseen on tab selection |
| `Sources/Window/SidebarViews.swift` | Add default colors, tooltips |
| `Sources/Window/TabBarViews.swift` | No changes needed (derives from BadgeState automatically) |
| `Sources/Detection/HookHandler.swift` | Set `completedUnseen` instead of `waitingForInput` when unfocused |
| `Sources/Window/SettingsWindow.swift` | Add entries to badge tables, update reset, update default animation set |

## Non-Goals

- No notification or sound when a tab enters `completedUnseen`. This is purely a visual badge state.
- No per-tab opt-out. The feature applies globally to all Claude and terminal tabs.
