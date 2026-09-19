import Foundation

/// The library's opening page, kept on disk so a relaunch opens on the rows the cook
/// saw last instead of on a loader. A recipe changes rarely: the page written last
/// time is almost always the page the server is about to send, and a row one session
/// old is worth incomparably more than an empty screen. The cached page draws first,
/// the server's answer replaces it a moment later.
///
/// One file per tab — the notebook and the coffee tab hold different libraries — in
/// the caches directory, which the system may reclaim at will: that is precisely what
/// a cache is for, and losing it costs one loader. Only the page a tab *opens* on is
/// written: a sorted or filtered library is a question the cook asked, not what to
/// draw on the next launch.
struct LibraryCache: Sendable {
    /// Bump whenever `LibraryRecipe` changes shape. An older file is then ignored
    /// instead of decoded into something that no longer means the same thing — a
    /// deliberate miss rather than an accidental one.
    private static let version = 1

    /// Which tab's library this file holds, named after the recipe types it reads —
    /// the one thing that tells the notebook's library from the coffee tab's.
    private let name: String

    init(types: [RecipeType]) {
        name = types.map(\.rawValue).sorted().joined(separator: "-")
    }

    private var file: URL {
        URL.cachesDirectory.appending(path: "library-\(name).json")
    }

    /// The rows of the last visit, or `nil` when there is no usable file: a first
    /// launch, a cache the system reclaimed, or a file written by an older shape. An
    /// empty file reads as nothing too — an empty library must show its first-run
    /// nudge, not a list that is briefly empty for a different reason.
    func read() -> [LibraryRecipe]? {
        guard let data = try? Data(contentsOf: file),
              let stored = try? JSONDecoder().decode(Stored.self, from: data),
              stored.version == Self.version,
              !stored.items.isEmpty
        else { return nil }
        return stored.items
    }

    /// Overwrite the file with what is on screen. A failure is swallowed on purpose:
    /// a cache that cannot be written costs a loader on the next launch, nothing more,
    /// and there is nothing for the cook to do about it.
    func write(_ items: [LibraryRecipe]) {
        guard let data = try? JSONEncoder().encode(Stored(version: Self.version, items: items))
        else { return }
        try? data.write(to: file, options: .atomic)
    }

    /// Forget every tab's library. Called when the session ends — a sign-out, an
    /// account deletion: whoever opens the app next must not read the previous cook's
    /// rows before the server has said a word.
    static func clear() {
        for types in [RecipeType.cooking, [.coffee]] {
            try? FileManager.default.removeItem(at: LibraryCache(types: types).file)
        }
    }

    private struct Stored: Codable {
        let version: Int
        let items: [LibraryRecipe]
    }
}
