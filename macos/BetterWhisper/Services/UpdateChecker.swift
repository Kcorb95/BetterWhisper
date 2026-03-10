import AppKit
import Foundation

/// Checks GitHub releases for newer versions of the app.
enum UpdateChecker {
    /// The GitHub repository to check for updates.
    /// Format: "owner/repo"
    static let repository = "Kcorb95/BetterWhisper"

    struct Release: Codable {
        let tagName: String
        let htmlUrl: String
        let name: String?

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlUrl = "html_url"
            case name
        }

        var version: String {
            tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        }
    }

    /// Returns the latest release if it's newer than the current version, or nil.
    static func checkForUpdate() async -> Release? {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            let release = try JSONDecoder().decode(Release.self, from: data)
            if isNewer(release.version, than: currentVersion) {
                return release
            }
            return nil
        } catch {
            return nil
        }
    }

    /// Open the release page in the user's browser.
    static func openReleasePage(_ release: Release) {
        if let url = URL(string: release.htmlUrl) {
            NSWorkspace.shared.open(url)
        }
    }

    /// The current app version from the bundle, or "1.0.0" as fallback.
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    // MARK: - Semantic Version Comparison

    private static func isNewer(_ version: String, than current: String) -> Bool {
        let v1 = version.split(separator: ".").compactMap { Int($0) }
        let v2 = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(v1.count, v2.count) {
            let a = i < v1.count ? v1[i] : 0
            let b = i < v2.count ? v2[i] : 0
            if a > b { return true }
            if a < b { return false }
        }
        return false
    }
}
