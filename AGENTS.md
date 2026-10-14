# Arbeitsanweisungen: Blood on the Clocktower

## Projektüberblick

- Flutter/Dart-Anwendung (Dart SDK `>=3.4.4 <4.0.0`) für den Spielablauf von Blood on the Clocktower.
- Die UI ist Material-basiert, überwiegend für Portrait-Nutzung ausgelegt und verwendet Provider.
- Firebase Core und Cloud Firestore werden einmalig in `main.dart` ohne sichtbare Anmeldung initialisiert. Öffentliche, anonymisierte GameRecords werden ausschließlich als unveränderliche `games/{gameId}`-Dokumente veröffentlicht; die lokale Upload-Warteschlange bleibt bei Netzwerkfehlern erhalten.
- Persistenten lokalen Spiel- und Layoutzustand über `shared_preferences` in den jeweiligen Services halten; keine parallelen Speicherpfade einführen.

## Architektur und Zuständigkeiten

- `lib/main.dart` ist der Composition Root: Dort alle appweiten `ChangeNotifierProvider` registrieren.
- Neue appweite, veränderliche Zustände als `ChangeNotifier`-Service unter `lib/services/` modellieren und über Provider konsumieren.
- Services kapseln Mutation, Persistenz und `notifyListeners()`; Widgets sollen Zustand über Provider lesen und Service-Methoden aufrufen.
- Für selektive Rebuilds das vorhandene `context.select`-Muster nutzen; für einmalige Aktionen `Provider.of<T>(context, listen: false)` verwenden.
- Screens unter `lib/screens/` koordinieren Abläufe und Navigation, Komponenten unter `lib/components/` kapseln wiederverwendbare Darstellung/Interaktion, Modelle unter `lib/models/` Datenstrukturen.
- Den Spiellebenszyklus über `GameStateService` und `CharacterService` gemeinsam aktualisieren: Start, Ende, Spielsetwechsel und Charakterzuordnung dürfen keinen widersprüchlichen Zustand hinterlassen.
- Die Spielerreihenfolge ist fachlich relevant: Änderungen daran über `GameStateService` führen und bei Charakterzuordnungen `CharacterService.syncPlayerNames` berücksichtigen.
- Rollennotizen werden separat von `RoleNotesService` persistiert; dessen Begrenzung auf maximal vier eindeutige Rollenbilder pro Spieler erhalten.

## Daten, Assets und Lokalisierung

- `Character` und `Token` sind die JSON-Serialisierungsgrenze; bei Schemaänderungen `fromJson` und `toJson` gemeinsam anpassen und Abwärtskompatibilität vorhandener Daten beachten.
- Charakterkataloge stammen sprachabhängig aus `assets/characters/{locale}.json`; Sprachwechsel lädt den Katalog neu. Neue Charakterdaten für unterstützte Sprachen konsistent ergänzen.
- Sichtbare UI-Texte über die ARB-Dateien in `lib/l10n/` und die generierten `AppLocalizations` beziehen; generierte `app_localizations*.dart` nicht manuell ändern.
- Neue Bild-, Font- oder JSON-Assets in `pubspec.yaml` deklarieren; bestehende Asset-Pfade und `CustomIcons` weiterverwenden.
- Unterstützte Locales bleiben mit `L10n.all`, `MyApp.supportedLocales` und den vorhandenen ARB-/Charakterdaten abgestimmt.

## UI- und Codekonventionen

- Neue Seiten folgen den bestehenden Stateful-Screen-Mustern und verwenden `MaterialPageRoute` für Navigation.
- Den vorhandenen dunklen Hintergrund-/Kartenstil und lokalisierte Dialogtexte bei Ergänzungen derselben UI-Bereiche fortführen.
- Bestehende öffentliche Namen und Speicher-Keys nicht nebenbei umbenennen; einige historische Schreibweisen sind Teil der verwendeten API und Persistenz.

## Prüfen und Navigation

- Vor Änderungen Serena MCP bevorzugt für Code-Navigation, Symbolsuche und Referenzanalyse einsetzen, sofern verfügbar.
- Aus `analysis_options.yaml` gilt `flutter_lints`; vorhandene Prüfkommandos sind `flutter analyze` und `flutter test`.
- Der Widget-Test richtet Provider und `SharedPreferences`-Mocks selbst ein; neue Widget-Tests müssen benötigte Provider entsprechend bereitstellen.
