# ToDo.md — Obsidian Kanban ToDo-App (Android)

Eine leichtgewichtige, schnell startende Android-App, die eine **Obsidian
`ToDo.md` im Kanban-Plugin-Format** direkt im Vault liest und bearbeitet — ohne
jedes Mal die schwergewichtige Obsidian-App öffnen zu müssen.

Voll kompatibel zum [Obsidian Kanban Plugin](https://github.com/mgmeyers/obsidian-kanban):
Lanes, Karten, Verschieben zwischen Lanes, Subtasks, Tags, Daten, interne Links
(`[[…]]`) und Embeds bleiben erhalten.

## Designprinzip: Round-trip-Sicherheit

Die Datei ist die Single Source of Truth und wird mit Obsidian geteilt. Deshalb
gilt: **Beim Speichern werden nur tatsächlich geänderte Karten neu geschrieben;
Frontmatter, Lane-Überschriften, unberührte Karten und der
`kanban:settings`-Block bleiben byte-genau erhalten.** Was der Parser nicht
versteht, reicht er unverändert durch — so kann das Bearbeiten einer Karte den
Rest der Datei nie beschädigen.

Verifiziert durch einen byte-exakten Round-trip-Test gegen die echte `ToDo.md`
(217 Karten, 6 Lanes) sowie ein sanitisiertes Fixture mit allen Format-Sonderfällen.

## Funktionen (v1)

- **Vault per Ordnerauswahl** (Android Storage Access Framework, persistente
  Berechtigung) — die App arbeitet direkt auf derselben Datei wie Obsidian.
- **Board-Ansicht** mit horizontalen Lanes; Karten zeigen Titel, Beschreibung,
  Subtask-Fortschritt, Tags, Datum und Link-Chips.
- **Schnell-Hinzufügen** (FAB / pro Lane): Titel, Liste, optional Tag & Datum.
- **Abhaken** von Karten und Subtasks per Tap.
- **Verschieben zwischen Lanes** per Drag & Drop (Karte lange drücken).
- **Hybrid-Editor**: strukturierte Felder (Erledigt, Titel, Liste, Datum, Tags,
  Subtasks) **plus** ein „Rohtext"-Tab zum direkten Markdown-Bearbeiten —
  unbekannte Inhalte bleiben erhalten.
- **Interne Links**: Tippen öffnet eine **In-App-Markdown-Vorschau** der
  Zielnotiz (Obsidian-Shortest-Path-Auflösung), mit Fallback **„In Obsidian
  öffnen"** (`obsidian://`). URLs öffnen extern.
- **Sicherheit**: automatisches Backup vor jedem Schreiben
  (`.todo-md-app-backups/`, letzte 12 Versionen) und Erkennung externer
  Änderungen (z. B. durch Obsidian) mit Nachfrage „Neu laden / Überschreiben".

## Projektstruktur

```
packages/kanban_core/      Reines Dart-Paket (keine Flutter-Abhängigkeit):
  lib/src/board.dart         Parser (header/lanes/cards/footer)
  lib/src/card.dart          Karten-Modell + minimal-invasive Mutatoren
  lib/src/lane.dart          Lane mit GapNode/CardNode (round-trip-Knoten)
  lib/src/operations.dart    move/add/delete/newCard
  test/                      Round-trip- + Edit-Op-Tests (sanitisiertes Fixture)

lib/                       Flutter-App:
  src/storage/saf.dart       Dart-Wrapper um den SAF-MethodChannel
  src/storage/board_repository.dart  Laden/Speichern, Backup, Konflikt-Erkennung
  src/providers/             Riverpod (settings, board, vault-Dateien)
  src/services/link_resolver.dart    [[wikilink]]-Auflösung im Vault
  src/ui/                     Board, Karten, Editor, Notiz-Viewer, Quick-Add, Settings

android/app/src/main/kotlin/.../MainActivity.kt   SAF-MethodChannel (Kotlin)
```

## Entwicklung & Build

Voraussetzungen: Flutter (stable, getestet mit 3.44.4), Android SDK (Platform 36,
Build-Tools 36), JDK 17+.

```bash
# Abhängigkeiten holen
flutter pub get

# Statische Analyse + Tests (App)
flutter analyze
flutter test

# Tests des reinen Core-Pakets
cd packages/kanban_core && dart test && cd -

# Debug-APK bauen
flutter build apk --debug
# -> build/app/outputs/flutter-apk/app-debug.apk

# Oder direkt auf ein angeschlossenes Gerät installieren/starten
flutter run
```

Die `applicationId`/Package-ID ist `de.clausen.todo_md_app` (in
`android/app/build.gradle.kts` und der Kotlin-Paketstruktur anpassbar).

## Erste Nutzung

1. App starten → **„Vault-Ordner wählen"** → den Ordner deines Obsidian-Vaults
   auswählen (die Berechtigung bleibt dauerhaft bestehen).
2. Standardmäßig wird `ToDo.md` im Vault-Root geladen. In den **Einstellungen**
   lassen sich Board-Dateipfad und Standard-Liste für neue Aufgaben ändern.

## Hinweise / Roadmap

- Aktuell Android-only. Die gesamte Logik ist in Flutter/Dart geschrieben, ein
  iOS/iPad-Build ist später ohne Logik-Änderungen möglich (nur SAF-Äquivalent
  für iOS und Plattform-Setup nötig).
- Spätere Ideen: Home-Screen-Widget, „Teilen → als ToDo", Volltextsuche, Archiv,
  Bearbeiten verlinkter Notizen.
