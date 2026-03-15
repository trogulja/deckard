import Foundation

/// Persisted state for Deckard — saved to ~/Library/Application Support/Deckard/state.json
struct DeckardState: Codable {
    var version: Int = 1
    var masterSessionId: String?
    var claudeTabCounter: Int = 0
    var terminalTabCounter: Int = 0
    var defaultWorkingDirectory: String?
    var tabs: [TabState] = []
    var selectedTabIndex: Int = 0
}

struct TabState: Codable {
    var id: String           // UUID string
    var sessionId: String?   // Claude Code session ID for resumption
    var name: String
    var nameOverride: Bool
    var isMaster: Bool
    var isClaude: Bool
    var workingDirectory: String?
}

/// Manages saving and loading Deckard state.
class SessionManager {
    static let shared = SessionManager()

    private let stateURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let deckardDir = appSupport.appendingPathComponent("Deckard")
        try? FileManager.default.createDirectory(at: deckardDir, withIntermediateDirectories: true)
        return deckardDir.appendingPathComponent("state.json")
    }()

    private var autosaveTimer: Timer?

    func save(_ state: DeckardState) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(state) else {
            print("Failed to encode state")
            return
        }
        do {
            try data.write(to: stateURL, options: .atomic)
        } catch {
            print("Failed to write state: \(error)")
        }
    }

    func load() -> DeckardState? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? JSONDecoder().decode(DeckardState.self, from: data)
    }

    /// Start periodic autosave every 8 seconds.
    func startAutosave(provider: @escaping () -> DeckardState) {
        autosaveTimer?.invalidate()
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            self?.save(provider())
        }
    }

    func stopAutosave() {
        autosaveTimer?.invalidate()
        autosaveTimer = nil
    }
}
