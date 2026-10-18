import Foundation

struct AuthenticationConfiguration {
    static let defaultClientInfo = "<PC> <Windows;6.2(0,0);9200> <com.apple.AuthKit/1 (com.apple.iTunes/12.12.4.1)>"
    static let defaultUserAgent = "akd/1.0 CFNetwork/808.1.4"

    let serverURL: URL
    let clientInfo: String
    let userAgent: String

    init(server: String, clientInfo: String, userAgent: String) throws {
        guard let url = URL(string: server.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else {
            throw ConfigurationError.invalidServer
        }
        self.serverURL = url
        self.clientInfo = try Self.header(clientInfo, name: "Client Info")
        self.userAgent = try Self.header(userAgent, name: "User Agent")
    }

    private static func header(_ value: String, name: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.unicodeScalars.allSatisfy({ (32...126).contains($0.value) }) else {
            throw ConfigurationError.invalidHeader(name)
        }
        return trimmed
    }

    enum ConfigurationError: LocalizedError {
        case invalidServer
        case invalidHeader(String)

        var errorDescription: String? {
            switch self {
            case .invalidServer:
                return "Enter an HTTP or HTTPS Anisette server URL without credentials, a query, or a fragment."
            case .invalidHeader(let name):
                return "\(name) must contain a nonempty, single line of printable ASCII text."
            }
        }
    }
}
