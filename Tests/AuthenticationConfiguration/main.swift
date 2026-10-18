import Foundation

func expectInvalid(_ server: String = "https://ani.sidestore.io", client: String = AuthenticationConfiguration.defaultClientInfo, agent: String = AuthenticationConfiguration.defaultUserAgent) {
    do {
        _ = try AuthenticationConfiguration(server: server, clientInfo: client, userAgent: agent)
        fatalError("Accepted invalid configuration")
    } catch {}
}

let config = try AuthenticationConfiguration(server: " https://ani.sidestore.io/ ", clientInfo: AuthenticationConfiguration.defaultClientInfo, userAgent: " akd/1.0 CFNetwork/808.1.4 ")
precondition(config.serverURL.absoluteString == "https://ani.sidestore.io/")
precondition(config.clientInfo == "<PC> <Windows;6.2(0,0);9200> <com.apple.AuthKit/1 (com.apple.iTunes/12.12.4.1)>")
precondition(config.userAgent == "akd/1.0 CFNetwork/808.1.4")
expectInvalid("ftp://example.com")
expectInvalid("https://")
expectInvalid("https://user:password@example.com")
expectInvalid("https://example.com?query=1")
expectInvalid("https://example.com#fragment")
expectInvalid(client: "   ")
expectInvalid(agent: "a\r\nInjected: header")
expectInvalid(client: "a\0b")
expectInvalid(agent: "a\tb")
print("Authentication configuration checks passed")
