# Test matrix

Diese Übersicht beschreibt die vorhandenen automatisierten Tests. Sie enthält bewusst keine Coverage-Werte.

| Funktion | Zugehörige Unit-Tests | Widget-/Integrationstests | E2E-Tests | Offener Testbedarf |
| --- | --- | --- | --- | --- |
| Spieler verwalten | `service_state_regression_test.dart` (hinzufügen, entfernen, umordnen, Persistenz) | `widget_interaction_test.dart` (Eingabe, Löschen, Drag) | TEST 1, TEST 4 | Direkte Löschgeste im Android-E2E-Flow ergänzen |
| Rollen auswählen und Fraktionsgrenzen | `character_identity_persistence_test.dart`, `select_gameset_test.dart` | vorhandene Auswahl-/Widget-Tests | TEST 1 | Kompletter interaktiver Zufalls-Auswahlpfad auf Android |
| Custom Scripts | `script_import_test.dart`, `script_service_test.dart`, `script_complexity_summary_test.dart` | `custom_script_import_screen_test.dart` | TEST 5 (Import, Abbruch, unbekannte Rolle, Auswahl, Sperre, Löschen) | Keine bekannte fachliche Lücke |
| Rollennotizen | `service_state_regression_test.dart` (Grenze vier, Zuordnung, Entfernen, Position, Persistenz) | — | TEST 6 (Öffnen, Begrenzen, Wiederherstellen, Reset, Löschen) | Direkter Touch-Drag der Tokenposition auf Android |
| Spielzustand und Lebenszyklus | `game_record_capture_test.dart`, `game_record_finalization_test.dart`, `service_state_regression_test.dart` | `quick_flow_interaction_test.dart` | TEST 1–4; Spielstart, Abbruch und Spielabschluss laufen über die UI | Weitere lokalisierte Varianten der Start-/Enddialoge |
| Nacht, Tag, QuickFlow und Token | `night_order_service_test.dart`, `quick_flow_test.dart`, `quick_flow_catalog_test.dart`, `reminder_token_inventory_test.dart` | `quick_flow_interaction_test.dart`, `quick_flow_bar_hit_test_test.dart` | TEST 2 weist QuickFlow-Reminder per UI zu und wechselt Tag/Nacht sowie Lebensstatus per UI; TEST 4 prüft Restore | Token-Menüs mit allen Gesten auf Android |
| Chronik | `chronicle_service_test.dart`, `chronicle_catalog_completeness_test.dart` | `chronicle_screen_test.dart` | TEST 2 prüft Chronikereignisse aus UI-Phasenwechseln; TEST 3 prüft Archivierung beim UI-Spielabschluss | Vollständiger E2E-Dialog für alle Eingabetypen |
| Spielabschluss und Upload-Warteschlange | `game_record_upload_queue_test.dart`, `game_record_validator_test.dart`, `game_record_finalization_test.dart` | — | TEST 3 schließt über den Dialog ab und prüft genau einen Queue-Eintrag | Echter Upload bleibt absichtlich ausgeschlossen; Firestore-Regeln laufen im Emulator |
| Sprache und Katalog | `service_state_regression_test.dart`, `character_catalog_fallback_test.dart`, `german_catalog_translation_test.dart` | `widget_interaction_test.dart` | TEST 7 (Sprachwechsel und Neustart) | Lokalisierte Navigation auf physischem Android prüfen |
| Layout-Einstellungen | `settings_service_test.dart`, `service_state_regression_test.dart` | `widget_interaction_test.dart` | TEST 7 (Änderung und Persistenz) | Reset über alle Einstellungs-Controls als Android-Geste |
| Savant-Generator | `savant_generator_test.dart` (leere Listen, Rebuild-Stabilität, Text) | — | TEST 7 (Anzeige und erneute Generierung) | Keine bekannte fachliche Lücke |
| Regelbuch und PDF-Viewer | `rules_pdf_sources_test.dart` | — | TEST 7 öffnet die Regelbuch-Navigation | PDF-Suche, Seitennavigation, Lade- und Fehleranzeige benötigen eine injizierbare lokale PDF-Quelle bzw. einen Controller-Test-Doppelgänger; die produktive externe Google-Drive-Quelle wird nicht in Tests verwendet |
| Firestore-Sicherheitsregeln | `firestore_game_repository_test.dart` | Firestore-Emulator-Skript | CI: `firestore_rules_emulator_check.mjs` | Kein öffentlicher Firestore-Schreibtest vorgesehen |

## E2E-Ausführung

Die E2E-Suite verwendet `integration_test`, reale lokale Services und `SharedPreferences`-Fixtures. Sie schreibt keine öffentlichen GameRecords und ersetzt externe Backends durch die lokale Upload-Warteschlange.

```text
flutter test integration_test/game_flows_test.dart -d <android-device-id>
```

Der manuell auslösbare Workflow `.github/workflows/android-e2e.yml` startet dafür einen Android-Emulator. Er ist zugleich per `workflow_call` wiederverwendbar, damit `.github/workflows/android-latest.yml` dieselbe E2E-Konfiguration ohne Duplikate parallel zum normalen `test`-Job ausführt. `build-and-publish` hängt von beiden Jobs ab und kann die signierte APK erst nach deren Erfolg unter `android-latest` veröffentlichen.

Der Android-Job verwendet einen isolierten, bei jedem Lauf mit `-wipe-data` zurückgesetzten API-35-x86_64-AVD. Die Suite startet `MyApp` mit lokalen Services und einer gemockten `SharedPreferences`-Instanz direkt aus `game_flows_test.dart`; `main.dart` und damit Firebase werden nicht initialisiert. Emulator-, Window- und Flutter-Testlogs werden immer als kurzlebiges Workflow-Artefakt gespeichert und bei Fehlern wird zusätzlich das Ende von Logcat ausgegeben.

## Verifizierter Stand (2026-10-16)

- `flutter analyze --no-fatal-infos`: lokal erfolgreich; vorhandene Info-Lints sind wegen `--no-fatal-infos` nicht blockierend.
- `flutter test`: lokal erfolgreich, 168 Tests.
- Firestore-Sicherheitsregeln: lokal erfolgreich mit Firebase Emulator `v1.22.0` und vorhandenem JDK 22; der CI-Job verwendet wie gefordert Temurin 21.
- Android API 35, x86_64, AVD `Pixel_2_API_35`: alle sieben Tests aus `integration_test/game_flows_test.dart` lokal erfolgreich ausgeführt.
- TEST 1: Spieler per UI angelegt und umgeordnet, Spiel per UI gestartet.
- TEST 2: QuickFlow-Reminder, Tag-/Nachtwechsel und Lebensstatus per UI; Chronikfortschritt geprüft.
- TEST 3: Spielabschluss einschließlich Gewinnerauswahl und Neustart per UI; Queue-Deduplizierung geprüft.
- TEST 4: persistierter Spielzustand wiederhergestellt und Abschlussdialog per UI abgebrochen.
- TEST 5: Importabbruch, unbekannte Rollenzuordnung und Bestätigung per UI; Auswahl-/Sperr-/Löschregeln anschließend auf Serviceebene geprüft.
- TEST 6: Rollennotiz-Grenze, Persistenz, Reset und Löschen im Android-Harness geprüft; die Manipulation erfolgt weiterhin über den Service.
- TEST 7: Sprache und Regel-Navigation per UI sowie Einstellungs-Persistenz und Savant-Generator geprüft.

Ein GitHub-hosted Emulatorlauf des geänderten Workflows ist erst nach dem Push möglich; die Emulatorausführung selbst wurde lokal vollständig verifiziert.

## Bewusst nicht abgedeckt

- Coverage-Messung und Coverage-Gates sind nicht konfiguriert.
- Echte öffentliche Firestore-Uploads werden nicht ausgeführt.
- Der PDF-Viewer wird nicht gegen eine instabile externe Netzwerkquelle getestet. Die offene Testbarkeit ist oben konkret dokumentiert.
