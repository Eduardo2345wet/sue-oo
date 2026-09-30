import Foundation

/// Guarda y lee los datos en el contenedor compartido (App Group) para que el widget los vea.
///
/// AltStore y SideStore le cambian el nombre al grupo al firmar con un Apple ID gratis
/// (le agregan tu Team ID), así que aquí se averigua el nombre real leyendo el perfil
/// de aprovisionamiento que viene dentro de la app.
enum SharedStore {
    static let baseGroupID = "group.com.eduardo.sueno"
    static let fileName = "sueno-datos.json"

    private static let resolved: (url: URL, groupID: String?) = resolve()

    static var isShared: Bool { resolved.groupID != nil }
    static var groupID: String? { resolved.groupID }
    static var dataURL: URL { resolved.url.appendingPathComponent(fileName) }

    // MARK: Leer y guardar

    static func load() -> AppData {
        guard let raw = try? Data(contentsOf: dataURL) else { return AppData() }
        if let data = decode(raw) { return data }
        // Archivo dañado: se aparta para no perderlo y se empieza de cero.
        let bad = resolved.url.appendingPathComponent("sueno-datos-danado-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: dataURL, to: bad)
        return AppData()
    }

    static func save(_ data: AppData) {
        guard let raw = encode(data) else { return }
        try? raw.write(to: dataURL, options: .atomic)
    }

    static func encode(_ data: AppData) -> Data? {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? e.encode(data)
    }

    static func decode(_ raw: Data) -> AppData? {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try? d.decode(AppData.self, from: raw)
    }

    // MARK: Encontrar el grupo compartido

    private static func resolve() -> (url: URL, groupID: String?) {
        for group in candidateGroupIDs() {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group),
               canWrite(in: url) {
                return (url, group)
            }
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return (docs, nil)
    }

    private static func candidateGroupIDs() -> [String] {
        var groups: [String] = []
        groups += groupsFromEmbeddedProfile().sorted { a, b in
            a.contains("sueno") && !b.contains("sueno")
        }
        if let alt = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] {
            groups += alt
        }
        groups.append(baseGroupID)
        var seen = Set<String>()
        return groups.filter { seen.insert($0).inserted }
    }

    /// Lee `embedded.mobileprovision` (un plist firmado) y saca los grupos que permite.
    private static func groupsFromEmbeddedProfile() -> [String] {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let raw = try? Data(contentsOf: url),
              let start = raw.range(of: Data("<?xml".utf8)),
              let end = raw.range(of: Data("</plist>".utf8), options: [], in: start.lowerBound..<raw.endIndex)
        else { return [] }
        let plistData = raw.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = (try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String]
        else { return [] }
        return groups
    }

    private static func canWrite(in folder: URL) -> Bool {
        let probe = folder.appendingPathComponent(".prueba-escritura")
        do {
            try Data("ok".utf8).write(to: probe, options: .atomic)
            try? FileManager.default.removeItem(at: probe)
            return true
        } catch {
            return false
        }
    }
}
