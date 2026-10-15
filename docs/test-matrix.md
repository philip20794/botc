# Test matrix

Diese Übersicht beschreibt die vorhandenen automatisierten Tests. Sie enthält bewusst keine Coverage-Werte.

| Funktion | Zugehörige Unit-Tests | Widget-/Integrationstests | E2E-Tests | Offener Testbedarf |
| --- | --- | --- | --- | --- |
| Spieler verwalten | `service_state_regression_test.dart` (hinzufügen, entfernen, umordnen, Persistenz) | `widget_interaction_test.dart` (Eingabe, Löschen, Drag) | TEST 1, TEST 4 | Android-Ausführung der Drag-Geste im manuellen Workflow verifizieren |
| Rollen auswählen und Fraktionsgrenzen | `character_identity_persistence_test.dart`, `select_gameset_test.dart` | vorhandene Auswahl-/Widget-Tests | TEST 1 | Kompletter interaktiver Zufalls-Auswahlpfad auf Android |
| Custom Scripts | `script_import_test.dart`, `script_service_test.dart`, `script_complexity_summary_test.dart` | `custom_script_import_screen_test.dart` | TEST 5 (Import, Abbruch, unbekannte Rolle, Auswahl, Sperre, Löschen) | Keine bekannte fachliche Lücke |
| Rollennotizen | `service_state_regression_test.dart` (Grenze vier, Zuordnung, Entfernen, Position, Persistenz) | — | TEST 6 (Öffnen, Begrenzen, Wiederherstellen, Reset, Löschen) | Direkter Touch-Drag der Tokenposition auf Android |
| Spielzustand und Lebenszyklus | `game_record_capture_test.dart`, `game_record_finalization_test.dart`, `service_state_regression_test.dart` | `quick_flow_interaction_test.dart` | TEST 1–4 | Alle Start-/Enddialoge mit lokalisierter UI als eigene Android-Flows |
| Nacht, Tag, QuickFlow und Token | `night_order_service_test.dart`, `quick_flow_test.dart`, `quick_flow_catalog_test.dart`, `reminder_token_inventory_test.dart` | `quick_flow_interaction_test.dart`, `quick_flow_bar_hit_test_test.dart` | TEST 2, TEST 4 | Token-Menüs mit allen Gesten auf Android |
| Chronik | `chronicle_service_test.dart`, `chronicle_catalog_completeness_test.dart` | `chronicle_screen_test.dart` | TEST 2, TEST 3 | Vollständiger E2E-Dialog für alle Eingabetypen |
| Spielabschluss und Upload-Warteschlange | `game_record_upload_queue_test.dart`, `game_record_validator_test.dart`, `game_record_finalization_test.dart` | — | TEST 3 | Echter Upload bleibt absichtlich ausgeschlossen; Firestore-Regeln laufen im Emulator |
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

Der manuell auslösbare Workflow `.github/workflows/android-e2e.yml` startet dafür einen Android-Emulator. Der reguläre APK-Workflow führt davor Analyse, alle Dart-/Widget-Tests sowie den Firestore-Emulator-Test aus; der APK-Build hängt vom erfolgreichen Testjob ab.

## Bewusst nicht abgedeckt

- Coverage-Messung und Coverage-Gates sind nicht konfiguriert.
- Echte öffentliche Firestore-Uploads werden nicht ausgeführt.
- Der PDF-Viewer wird nicht gegen eine instabile externe Netzwerkquelle getestet. Die offene Testbarkeit ist oben konkret dokumentiert.
