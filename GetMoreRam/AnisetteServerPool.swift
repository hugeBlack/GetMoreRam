//
//  AnisetteServerPool.swift
//  GetMoreRam
//
//  Keeps a pool of anisette v3 servers so signing in doesn't depend on a
//  single (possibly overloaded or dead) server. The server list comes from
//  SideStore's public list, with a bundled fallback.
//

import Foundation

struct AnisetteServer: Codable, Hashable {
    let name: String
    let address: String
    let kind: Int

    var url: URL? { URL(string: address) }
}

struct AnisetteServerHealth: Identifiable {
    let server: AnisetteServer
    let latency: TimeInterval?
    let error: String?

    var id: String { server.address }
    var isHealthy: Bool { latency != nil }
}

final class AnisetteServerPool: @unchecked Sendable {
    static let shared = AnisetteServerPool()

    static let serverListURL = URL(string: "https://servers.sidestore.io/servers.json")!

    // Apple now refuses sign in with anisette from Android-based servers (kind 0)
    // with error -80045/-80046, so only servers backed by real Mac/Windows ADI
    // (kind 1 and 2) are used. They all speak the anisette v3 protocol.
    static let bundledServers: [AnisetteServer] = [
        AnisetteServer(name: "SideStore (New)", address: "https://new.ani.sidestore.io", kind: 2),
        AnisetteServer(name: "jkcoxson", address: "https://mac-ani.jkcoxson.com", kind: 2),
        AnisetteServer(name: "jkcoxson (ADI)", address: "https://ani.jkcoxson.com", kind: 1),
        AnisetteServer(name: "Lill q", address: "https://anisette.lillq.me", kind: 2),
        AnisetteServer(name: "SideStore (Windows ADI)", address: "https://win.ani.sidestore.io", kind: 1),
    ]

    // v2: earlier builds cached Android servers, which Apple now rejects
    private static let cachedServersKey = "AnisetteServerPool.cachedServers.v2"
    private static let lastGoodKey = "AnisetteServerPool.lastGoodURL.v2"
    private static let failuresKey = "AnisetteServerPool.failures"
    // Failures older than this no longer count against a server
    private static let failureWindow: TimeInterval = 60 * 60

    private let lock = NSLock()
    private let defaults = UserDefaults.standard
    private let probeSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 6
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private var _servers: [AnisetteServer]

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.cachedServersKey),
           let cached = try? JSONDecoder().decode([AnisetteServer].self, from: data),
           !cached.isEmpty {
            _servers = Self.merge(Self.bundledServers, cached.filter(Self.isUsable))
        } else {
            _servers = Self.bundledServers
        }
    }

    var servers: [AnisetteServer] {
        lock.lock(); defer { lock.unlock() }
        return _servers
    }

    var lastGoodURL: String? {
        get { defaults.string(forKey: Self.lastGoodKey) }
        set { defaults.set(newValue, forKey: Self.lastGoodKey) }
    }

    // MARK: - Server list

    /// Fetches SideStore's public server list. Silently keeps the cached/bundled list on failure.
    func refresh() async {
        do {
            var request = URLRequest(url: Self.serverListURL)
            request.timeoutInterval = 8
            let (data, _) = try await probeSession.data(for: request)

            struct ServerList: Decodable { let servers: [AnisetteServer] }
            // https only: get_headers sends the device's adi.pb, which must not travel in plain text
            let fetched = try JSONDecoder().decode(ServerList.self, from: data).servers.filter(Self.isUsable)
            guard !fetched.isEmpty else { return }

            defaults.set(try JSONEncoder().encode(fetched), forKey: Self.cachedServersKey)
            setServers(Self.merge(Self.bundledServers, fetched))
        } catch {
            print("Couldn't refresh anisette server list: \(error)")
        }
    }

    private static func isUsable(_ server: AnisetteServer) -> Bool {
        server.kind != 0 && server.url?.scheme == "https"
    }

    private func setServers(_ servers: [AnisetteServer]) {
        lock.lock(); defer { lock.unlock() }
        _servers = servers
    }

    private static func merge(_ a: [AnisetteServer], _ b: [AnisetteServer]) -> [AnisetteServer] {
        var seen = Set<String>()
        return (a + b).filter { seen.insert(normalize($0.address)).inserted }
    }

    static func normalize(_ address: String) -> String {
        var s = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    // MARK: - Health

    func probe(_ server: AnisetteServer) async -> AnisetteServerHealth {
        guard let url = server.url else {
            return AnisetteServerHealth(server: server, latency: nil, error: "Invalid URL")
        }
        let start = Date()
        do {
            let (data, response) = try await probeSession.data(from: url.appendingPathComponent("v3").appendingPathComponent("client_info"))
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["client_info"] != nil else {
                return AnisetteServerHealth(server: server, latency: nil, error: "HTTP \(status)")
            }
            return AnisetteServerHealth(server: server, latency: Date().timeIntervalSince(start), error: nil)
        } catch {
            return AnisetteServerHealth(server: server, latency: nil, error: error.localizedDescription)
        }
    }

    /// Probes every server concurrently and returns all of them, best first:
    /// healthy before unhealthy, then the last working one, then fewest recent
    /// failures, then list order (most compatible servers are listed first).
    func rankedServers() async -> [AnisetteServerHealth] {
        let servers = self.servers
        let results = await withTaskGroup(of: AnisetteServerHealth.self) { group in
            for server in servers {
                group.addTask { await self.probe(server) }
            }
            var results: [AnisetteServerHealth] = []
            for await result in group { results.append(result) }
            return results
        }

        let lastGood = lastGoodURL.map(Self.normalize)
        let priority = Dictionary(servers.enumerated().map { (Self.normalize($1.address), $0) }, uniquingKeysWith: { a, _ in a })
        return results.sorted { a, b in
            if a.isHealthy != b.isHealthy { return a.isHealthy }
            let aGood = Self.normalize(a.server.address) == lastGood
            let bGood = Self.normalize(b.server.address) == lastGood
            if aGood != bGood { return aGood }
            let aFail = recentFailures(a.server.address)
            let bFail = recentFailures(b.server.address)
            if aFail != bFail { return aFail < bFail }
            let aPriority = priority[Self.normalize(a.server.address)] ?? .max
            let bPriority = priority[Self.normalize(b.server.address)] ?? .max
            if aPriority != bPriority { return aPriority < bPriority }
            return (a.latency ?? .infinity) < (b.latency ?? .infinity)
        }
    }

    // MARK: - Reliability tracking

    func recordSuccess(_ address: String) {
        lastGoodURL = address
        lock.lock(); defer { lock.unlock() }
        var failures = loadFailures()
        failures[Self.normalize(address)] = nil
        saveFailures(failures)
    }

    func recordFailure(_ address: String) {
        lock.lock(); defer { lock.unlock() }
        let key = Self.normalize(address)
        var failures = loadFailures()
        failures[key, default: []].append(Date().timeIntervalSince1970)
        saveFailures(failures)
        if let lastGood = lastGoodURL, Self.normalize(lastGood) == key {
            lastGoodURL = nil
        }
    }

    func recentFailures(_ address: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return loadFailures()[Self.normalize(address)]?.count ?? 0
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        defaults.removeObject(forKey: Self.failuresKey)
        defaults.removeObject(forKey: Self.lastGoodKey)
    }

    // Callers must hold `lock`
    private func loadFailures() -> [String: [TimeInterval]] {
        let raw = defaults.dictionary(forKey: Self.failuresKey) as? [String: [TimeInterval]] ?? [:]
        let cutoff = Date().timeIntervalSince1970 - Self.failureWindow
        return raw.compactMapValues { times in
            let recent = times.filter { $0 > cutoff }
            return recent.isEmpty ? nil : recent
        }
    }

    private func saveFailures(_ failures: [String: [TimeInterval]]) {
        defaults.set(failures, forKey: Self.failuresKey)
    }
}
