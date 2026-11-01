import Foundation
import Security

/// Keeps the Blackboard session (its cookies, never the password) in the Keychain, on this device only:
/// readable after the first unlock so a background sync can use it, and never in a backup.
struct SessionVault {
    var service = "io.github.k7ax.moeed.blackboard"

    func save(_ cookies: [HTTPCookie]) {
        let records = cookies.map { cookie -> [String: String] in
            var record = ["name": cookie.name, "value": cookie.value, "domain": cookie.domain, "path": cookie.path]
            if let expires = cookie.expiresDate { record["expires"] = String(expires.timeIntervalSince1970) }
            if cookie.isSecure { record["secure"] = "TRUE" }
            return record
        }
        guard let data = try? JSONEncoder().encode(records) else { return }
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    func load() -> [HTTPCookie] {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let records = try? JSONDecoder().decode([[String: String]].self, from: data)
        else { return [] }
        return records.compactMap { record in
            var properties: [HTTPCookiePropertyKey: Any] = [:]
            properties[.name] = record["name"]
            properties[.value] = record["value"]
            properties[.domain] = record["domain"]
            properties[.path] = record["path"]
            if let expires = record["expires"].flatMap(Double.init) { properties[.expires] = Date(timeIntervalSince1970: expires) }
            if record["secure"] != nil { properties[.secure] = "TRUE" }
            return HTTPCookie(properties: properties)
        }
    }

    func clear() {
        SecItemDelete(query as CFDictionary)
    }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "session"]
    }
}
