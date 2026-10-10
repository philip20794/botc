# Performance-Baseline — 2026-10-10

## Status

Eine App-Performance-Baseline konnte in dieser Umgebung nicht gemessen werden.
Es wurden weder die Anwendung installiert, noch Daten oder Spielstände verändert.

## Entwicklungsumgebung (gemessen)

| Prüfschritt | Ergebnis |
| --- | --- |
| `adb version` | Android Debug Bridge 1.0.41, Platform-Tools 35.0.1-11580240 |
| `adb devices -l` | Autorisiertes Gerät: `10AE3C00KS005AZ`, Modell `V2309A`, Status `device` |
| Geräteplattform | Android 16 / API 36 |
| Zielpaket auf dem Gerät | Nicht installiert: `de.blood_on_the_clocktower.blood_on_the_clocktower` |
| `flutter doctor -v` | Nicht abgeschlossen: Flutter-CLI lieferte innerhalb von 30 s keine Ausgabe |
| `flutter devices` | Nicht abgeschlossen: Flutter-CLI lieferte innerhalb von 30 s keine Ausgabe |

## Android-Build-Konfiguration (Quellprüfung)

- Application ID und Namespace: `de.blood_on_the_clocktower.blood_on_the_clocktower`.
- `minSdk` 23; `compileSdk` und `targetSdk` stammen aus dem Flutter-Plugin.
- Das Projekt verwendet Firebase/Google Services; die Android-App ist hardwarebeschleunigt.
- Es existiert keine Installation des Zielpakets. Daher lieferten `adb shell dumpsys meminfo` und `dumpsys gfxinfo` keinen Prozess und keine Frame-Daten.

## Messmatrix

| Szenario | Speicher | CPU | Frametimes | Status |
| --- | ---: | ---: | ---: | --- |
| Hauptmenü | Nicht gemessen | Nicht gemessen | Nicht gemessen | App nicht installierbar/profilierbar |
| Charakterauswahl | Nicht gemessen | Nicht gemessen | Nicht gemessen | App nicht installierbar/profilierbar |
| Spielbereich | Nicht gemessen | Nicht gemessen | Nicht gemessen | App nicht installierbar/profilierbar |
| Tokenaktion | Nicht gemessen | Nicht gemessen | Nicht gemessen | App nicht installierbar/profilierbar |
| Bildschirmwechsel | Nicht gemessen | Nicht gemessen | Nicht gemessen | App nicht installierbar/profilierbar |
| Wiederholtes Öffnen/Schließen | Nicht gemessen | Nicht gemessen | Nicht gemessen | App nicht installierbar/profilierbar |

## Auffälligkeiten (Code-Hypothesen, nicht gemessen)

1. **Spielbereich:** `SpielbereichScreen.build` ruft bei jedem Rebuild `initUnusedGameTokens` auf; dieses leert und durchläuft alle Charakter-Token erneut.
2. **Charakterkreis:** Jeder Rebuild erzeugt für alle Figuren `Positioned`-, Drag-and-Drop- und komplexe `CharacterWidget`-Bäume neu. Das ist bei vielen Figuren wahrscheinlich der wichtigste Framezeit-Kandidat.
3. **Tokenleiste:** Die Anzeige unzugeordneter Token berechnet die Tokenliste erneut und baut für jedes Token AssetImage- und AutoSizeText-Widgets.

Diese Punkte sind ausschließlich aus der Quellprüfung abgeleitet. Ohne Profile-Trace sind sie keine gemessenen Engpässe.

## Sicherer reproduzierbarer Messweg

1. Flutter-CLI wieder funktionsfähig machen; `flutter doctor -v` und `flutter devices` müssen vollständig ausgeben.
2. Vor einer Installation bestätigen, dass das verbundene Gerät ein dediziertes Testgerät ist. Das Zielpaket ist aktuell nicht installiert; eine Profile-Installation würde daher keine bestehende Installation oder deren Daten überschreiben.
3. `flutter run --profile -d 10AE3C00KS005AZ` starten und DevTools Performance sowie Memory öffnen.
4. Je Szenario 30 Sekunden nach einem Warm-up erfassen; zusätzlich `adb shell dumpsys meminfo <package>` und `adb shell dumpsys gfxinfo <package>` sichern.
5. Für Öffnen/Schließen 20 Zyklen durchführen, anschließend die gleichen ADB-Abfragen wiederholen und Messwerte in die Tabelle eintragen.

## Nächster sinnvoller Fix

Zuerst die Flutter-CLI-Blockade beheben. Danach den Spielbereich im Profile-Modus messen; bestätigt ein Trace die Hypothesen, `initUnusedGameTokens` aus `build` herausziehen bzw. nur bei Tokenänderungen aktualisieren.
