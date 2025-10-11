#!/usr/bin/env swift
import Foundation

let targetPath = CommandLine.arguments.dropFirst().first ?? "LaunchOne/Localizable.xcstrings"
let url = URL(fileURLWithPath: targetPath)
guard FileManager.default.fileExists(atPath: url.path) else {
    fputs("File not found: \(url.path)\n", stderr)
    exit(1)
}

func loadJSON(_ url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    let any = try JSONSerialization.jsonObject(with: data, options: [])
    guard let obj = any as? [String: Any] else { throw NSError(domain: "json", code: 1) }
    return obj
}

func saveJSON(_ obj: [String: Any], to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url)
}

do {
    var root = try loadJSON(url)
    guard var strings = root["strings"] as? [String: Any] else {
        fputs("Missing 'strings' dictionary in catalog\n", stderr)
        exit(1)
    }

    // Determine full locale set from existing entries, with a preferred default set
    var allLocales = Set(["en", "zh-Hans", "fr", "es", "de", "ja", "ko", "ru", "vi"])
    for (_, anyEntry) in strings {
        if let entry = anyEntry as? [String: Any], let locs = entry["localizations"] as? [String: Any] {
            allLocales.formUnion(locs.keys)
        }
    }

    var updatedCount = 0
    var createdCount = 0

    for key in strings.keys.sorted() {
        guard var entry = strings[key] as? [String: Any] else { continue }
        var locs = (entry["localizations"] as? [String: Any]) ?? [:]

        // baseline value: English value if present, else use key
        let keyTrimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        var baselineValue: String = keyTrimmed.isEmpty ? "N/A" : key
        if let en = locs["en"] as? [String: Any], let unit = en["stringUnit"] as? [String: Any], let v = unit["value"] as? String, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            baselineValue = v
        } else if keyTrimmed.isEmpty {
            baselineValue = "N/A"
        }

        for locale in allLocales {
            var unitDict: [String: Any]
            if let existing = locs[locale] as? [String: Any], let unit = existing["stringUnit"] as? [String: Any] {
                let current = (unit["value"] as? String) ?? ""
                if current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    var newUnit = unit
                    newUnit["value"] = baselineValue
                    var newLoc = existing
                    newLoc["stringUnit"] = newUnit
                    locs[locale] = newLoc
                    updatedCount += 1
                }
            } else {
                unitDict = [
                    "state": "translated",
                    "value": baselineValue
                ]
                locs[locale] = [
                    "stringUnit": unitDict
                ]
                createdCount += 1
            }
        }

        entry["localizations"] = locs
        strings[key] = entry
    }

    root["strings"] = strings
    try saveJSON(root, to: url)
    print("Filled missing/empty localizations. created=\(createdCount), updated=\(updatedCount). File: \(url.path)")
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}


