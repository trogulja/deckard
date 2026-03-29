import AppKit

enum FullDiskAccessChecker {
    /// Probes known FDA-protected paths.  Returns `true` when any path is
    /// readable (i.e. FDA has been granted).  The probe itself causes macOS
    /// to register Deckard in System Settings > Full Disk Access.
    static func hasFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let protectedPaths = [
            home + "/Library/Safari/Bookmarks.plist",
            home + "/Library/Safari/CloudTabs.db",
            home + "/Library/Mail",
        ]
        return protectedPaths.contains {
            FileManager.default.isReadableFile(atPath: $0)
        }
    }

    /// Opens System Settings directly to the Full Disk Access pane.
    static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
    }
}
