#!/usr/bin/env swift
import Foundation

struct Catalog: Decodable {
    let sourceLanguage: String?
    let strings: [String: Entry]
}

struct Entry: Decodable {
    let localizations: [String: Localization]
}

struct Localization: Decodable {
    let stringUnit: StringUnit?
}

struct StringUnit: Decodable {
    let state: String?
    let value: String?
}

enum CheckError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case decodeFailed(String)
    case issuesFound(Int)

    var description: String {
        switch self {
        case .fileNotFound(let p): return "File not found: \(p)"
        case .decodeFailed(let r): return "Failed to decode xcstrings: \(r)"
        case .issuesFound(let n): return "Localization issues found: \(n)"
        }
    }
}

@discardableResult
func main() throws -> Int32 {
    let path = CommandLine.arguments.dropFirst().first ?? "LaunchOne/Localizable.xcstrings"
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw CheckError.fileNotFound(url.path)
    }

    let data = try Data(contentsOf: url)
    let any = try JSONSerialization.jsonObject(with: data, options: [])
    guard let root = any as? [String: Any] else {
        throw CheckError.decodeFailed("root not object")
    }
    guard let strings = root["strings"] as? [String: Any] else {
        throw CheckError.decodeFailed("missing 'strings'")
    }

    var issueCount = 0
    let placeholderRegex = try! NSRegularExpression(pattern: "%(@|\\d*\\$?[@dfDuU])")

    // Union of all locales in the catalog
    var allLocales = Set<String>()
    for (_, v) in strings {
        guard let entry = v as? [String: Any],
              let locs = entry["localizations"] as? [String: Any] else { continue }
        allLocales.formUnion(locs.keys)
    }

    for key in strings.keys.sorted() {
        guard let entry = strings[key] as? [String: Any] else { continue }
        let locs = (entry["localizations"] as? [String: Any]) ?? [:]
        // Missing locales
        let locales = Set(locs.keys)
        let missing = allLocales.subtracting(locales)
        if !missing.isEmpty {
            issueCount += missing.count
            print("[MISSING] key=\(key) missing locales: \(missing.sorted().joined(separator: ", "))")
        }

        // Empty/untranslated & placeholder consistency
        var baselinePlaceholders: [String: Int]? = nil
        for locale in allLocales.sorted() {
            guard let loc = locs[locale] as? [String: Any],
                  let unit = loc["stringUnit"] as? [String: Any] else { continue }
            let value = (unit["value"] as? String) ?? ""
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issueCount += 1
                print("[EMPTY] key=\(key) locale=\(locale) is empty")
            }
            let matches = placeholderRegex.matches(in: value, range: NSRange(value.startIndex..<value.endIndex, in: value))
            var counts: [String: Int] = [:]
            for m in matches {
                if let r = Range(m.range, in: value) {
                    let token = String(value[r])
                    counts[token, default: 0] += 1
                }
            }
            if baselinePlaceholders == nil { baselinePlaceholders = counts }
            else if baselinePlaceholders! != counts {
                issueCount += 1
                print("[PLACEHOLDER_MISMATCH] key=\(key) locale=\(locale) counts=\(counts) expected=\(baselinePlaceholders!)")
            }
        }
    }

    if issueCount > 0 {
        throw CheckError.issuesFound(issueCount)
    }

    print("Localization check passed: no issues found. (\(strings.count) keys, locales: \(allLocales.sorted().joined(separator: ", ")))\nPath: \(url.path)")
    return 0
}

do {
    exit(try main())
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}


