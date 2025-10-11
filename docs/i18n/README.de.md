# LaunchOne

**Sprachen**: [English](../../README.md) | [中文](../../README.zh.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Français](README.fr.md) | [Español](README.es.md) | [Deutsch](README.de.md) | [Русский](README.ru.md) | [हिन्दी](README.hi.md) | [Tiếng Việt](README.vi.md)

## 📥 Download

**[Hier herunterladen](https://github.com/mamahuhu-io/LaunchOne/releases/latest)** - Holen Sie sich die neueste Version

⭐ Geben Sie [LaunchOne](https://github.com/mamahuhu-io/LaunchOne) und besonders dem Originalprojekt [LaunchNext](https://github.com/RoversX/LaunchNext) einen Stern!

| | |
|:---:|:---:|
| ![](../assets/main.webp) | ![](../assets/setting-general.webp) |
| ![](../assets/setting-appearance.webp) | ![](../assets/setting-apptitle.webp) |

macOS Tahoe hat das Launchpad entfernt, und es ist so schwer zu bedienen, es nutzt nicht Ihre Bio-GPU. Bitte Apple, gebt den Leuten wenigstens eine Option, zurückzuwechseln. Bis dahin ist hier LaunchOne.

*Basierend auf [LaunchNext](https://github.com/RoversX/LaunchNext) von RoversX - vielen Dank an das ursprüngliche Projekt! Ich hoffe, diese erweiterte Version kann in das ursprüngliche Repository zurückgeführt werden*

*LaunchNext hat die GPL 3 Lizenz gewählt. LaunchOne folgt denselben Lizenzbedingungen.*

### Was LaunchOne bietet
- ✅ **Ein-Klick-Import vom alten System-Launchpad** - liest direkt Ihre native Launchpad SQLite-Datenbank (`/private$(getconf DARWIN_USER_DIR)com.apple.dock.launchpad/db/db`) um Ihre bestehenden Ordner, App-Positionen und Layout perfekt zu recreieren
- ✅ **Klassische Launchpad-Erfahrung** - funktioniert genau wie die geliebte ursprüngliche Schnittstelle
- ✅ **Mehrsprachige Unterstützung** - vollständige Internationalisierung mit Englisch, Chinesisch, Japanisch, Französisch, Spanisch, Deutsch und Russisch
- ✅ **Icon-Labels verstecken** - saubere, minimalistische Ansicht, wenn Sie App-Namen nicht benötigen
- ✅ **Benutzerdefinierte Icon-Größen** - passen Sie Icon-Dimensionen an Ihre Vorlieben an
- ✅ **Intelligente Ordnerverwaltung** - erstellen und organisieren Sie Ordner wie zuvor
- ✅ **Sofortsuche und Tastaturnavigation** - finden Sie Apps schnell

### Was wir in macOS Tahoe verloren haben
- ❌ Keine benutzerdefinierte App-Organisation
- ❌ Keine benutzerdefinierten Ordner
- ❌ Keine Drag-and-Drop-Anpassung
- ❌ Keine visuelle App-Verwaltung
- ❌ Erzwungene kategorische Gruppierung

## Funktionen

### 🎯 **Sofortiger App-Start**
- Doppelklick zum direkten Starten von Apps
- Vollständige Tastaturnavigations-Unterstützung
- Blitzschnelle Suche mit Echtzeit-Filterung

### 📁 **Erweiterte Ordnersystem**
- Erstellen Sie Ordner durch Ziehen von Apps zusammen
- Benennen Sie Ordner mit Inline-Bearbeitung um
- Benutzerdefinierte Ordner-Icons und Organisation
- Ziehen Sie Apps nahtlos hinein und heraus

### 🔍 **Intelligente Suche**
- Echtzeit-Fuzzy-Matching
- Suche über alle installierten Anwendungen
- Tastenkürzel für schnellen Zugriff

### 🎨 **Modernes Interface-Design**
- **Liquid Glass Effect**: regularMaterial mit eleganten Schatten
- Vollbild- und Fenster-Anzeige-Modi
- Sanfte Animationen und Übergänge
- Saubere, responsive Layouts

### 🔄 **Nahtlose Datenmigration**
- **Ein-Klick-Launchpad-Import** aus nativer macOS-Datenbank
- Automatische App-Erkennung und -Scannung
- Persistente Layout-Speicherung über SwiftData
- Null Datenverlust während System-Updates

### ⚙️ **Systemintegration**
- Native macOS-Anwendung
- Multi-Monitor-bewusste Positionierung
- Funktioniert neben Dock und anderen System-Apps
- Hintergrund-Klick-Erkennung (intelligente Schließung)

## Technische Architektur

### Gebaut mit modernen Technologien
- **SwiftUI**: Deklaratives, performantes UI-Framework
- **SwiftData**: Robuste Datenpersistenz-Schicht
- **AppKit**: Tiefe macOS-Systemintegration
- **SQLite3**: Direkte Launchpad-Datenbanklesung

### Datenspeicherung
Anwendungsdaten werden sicher gespeichert in:
```
~/Library/Application Support/LaunchOne/Data.store
```

### Native Launchpad-Integration
Liest direkt aus der System-Launchpad-Datenbank:
```bash
/private$(getconf DARWIN_USER_DIR)com.apple.dock.launchpad/db/db
```

## Installation

### Anforderungen
- macOS 26 (Tahoe) oder später
- Apple Silicon oder Intel-Prozessor
- Xcode 26 (für Build aus Quellcode)

### Build aus Quellcode

1. **Repository klonen**
   ```bash
   clone git@github.com:mamahuhu-io/LaunchOne.git
   cd LaunchOne
   ```

2. **In Xcode öffnen**
   ```bash
   open LaunchOne.xcodeproj
   ```

3. **Bauen und ausführen**
   - Wählen Sie Ihr Zielgerät
   - Drücken Sie `⌘+R` zum Bauen und Ausführen
   - Oder `⌘+B` nur zum Bauen

### Kommandozeilen-Build

**Regulärer Build:**
```bash
xcodebuild -project LaunchOne.xcodeproj -scheme LaunchOne -configuration Release
```

**Universal Binary Build (Intel + Apple Silicon):**
```bash
xcodebuild -project LaunchOne.xcodeproj -scheme LaunchOne -configuration Release ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO clean build
```

## Verwendung

### Erste Schritte
1. **Erster Start**: LaunchOne scannt automatisch alle installierten Anwendungen
2. **Auswählen**: Klicken zum Auswählen von Apps, Doppelklick zum Starten
3. **Suchen**: Tippen zum sofortigen Filtern von Anwendungen
4. **Organisieren**: Ziehen Sie Apps, um Ordner und benutzerdefinierte Layouts zu erstellen

### Ihr Launchpad importieren
1. Öffnen Sie Einstellungen (Zahnrad-Icon)
2. Klicken Sie **"Import Launchpad"**
3. Ihr bestehendes Layout und Ordner werden automatisch importiert

### Ordnerverwaltung
- **Ordner erstellen**: Ziehen Sie eine App auf eine andere
- **Ordner umbenennen**: Klicken Sie auf den Ordnernamen
- **Apps hinzufügen**: Ziehen Sie Apps in Ordner
- **Apps entfernen**: Ziehen Sie Apps aus Ordnern heraus

### Anzeigemodi
- **Fenster**: Schwebendes Fenster mit abgerundeten Ecken
- **Vollbild**: Vollbild-Modus für maximale Sichtbarkeit
- Modi in Einstellungen wechseln

## Bekannte Probleme

> **Aktueller Entwicklungsstand**
> - 🔄 **Scroll-Verhalten**: Kann in bestimmten Szenarien instabil sein, besonders bei schnellen Gesten
> - 🎯 **Ordnererstellung**: Drag-and-Drop-Hit-Erkennung für das Erstellen von Ordnern manchmal inkonsistent
> - 🛠️ **Aktive Entwicklung**: Diese Probleme werden aktiv in kommenden Releases behoben

## Fehlerbehebung

### Häufige Probleme

**F: App startet nicht?**
A: Stellen Sie macOS 26.0+ sicher und prüfen Sie Systemberechtigungen.

**F: Import-Button fehlt?**
A: Überprüfen Sie, dass SettingsView.swift die Import-Funktionalität enthält.

**F: Suche funktioniert nicht?**
A: Versuchen Sie Apps neu zu scannen oder App-Daten in Einstellungen zurückzusetzen.

**F: Performance-Probleme?**
A: Prüfen Sie Icon-Cache-Einstellungen und starten Sie die Anwendung neu.

## Warum LaunchOne wählen?

### vs. Apples "Applications"-Interface
| Funktion | Applications (Tahoe) | LaunchOne |
|---------|---------------------|------------|
| Benutzerdefinierte Organisation | ❌ | ✅ |
| Benutzer-Ordner | ❌ | ✅ |
| Drag & Drop | ❌ | ✅ |
| Visuelle Verwaltung | ❌ | ✅ |
| Bestehende Daten importieren | ❌ | ✅ |
| Performance | Langsam | Schnell |

### vs. Andere Launchpad-Alternativen
- **Native Integration**: Direkte Launchpad-Datenbanklesung
- **Moderne Architektur**: Gebaut mit neuesten SwiftUI/SwiftData
- **Null Abhängigkeiten**: Reines Swift, keine externen Bibliotheken
- **Aktive Entwicklung**: Regelmäßige Updates und Verbesserungen
- **Liquid Glass Design**: Premium-Visualeffekte

## Mitwirken

Wir begrüßen Beiträge! Bitte:

1. Repository forken
2. Feature-Branch erstellen (`git checkout -b feature/amazing-feature`)
3. Änderungen committen (`git commit -m 'Add amazing feature'`)
4. Branch pushen (`git push origin feature/amazing-feature`)
5. Pull Request öffnen

### Entwicklungsrichtlinien
- Swift-Stil-Konventionen befolgen
- Sinnvolle Kommentare für komplexe Logik hinzufügen
- Auf mehreren macOS-Versionen testen
- Rückwärtskompatibilität beibehalten

## Die Zukunft der App-Verwaltung

Da Apple sich von anpassbaren Schnittstellen entfernt, repräsentiert LaunchOne das Engagement der Community für Benutzerkontrolle und Personalisierung. Wir glauben, dass Benutzer entscheiden sollten, wie sie ihren digitalen Arbeitsplatz organisieren.

**LaunchOne** ist nicht nur ein Launchpad-Ersatz—es ist ein Statement, dass Benutzerauswahl wichtig ist.


---

**LaunchOne** - Erobern Sie Ihren App-Launcher zurück 🚀

*Gebaut für macOS-Benutzer, die sich weigern, bei der Anpassung Kompromisse einzugehen.*

## Entwicklungstools

Dieses Projekt wurde mit Unterstützung entwickelt von:

- Claude Code
- Cursor
- Cursor Cli