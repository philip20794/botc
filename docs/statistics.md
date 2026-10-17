# Globale BotC-Statistik ohne Cloud Functions

## Datenfluss

1. Die App speichert den **unveränderlichen** anonymisierten Spielbericht unter
   `games/{gameId}`. Neuere Versionen ergänzen nur beim Anlegen das Feld
   `uploadedAt: FieldValue.serverTimestamp()` (Firestore Timestamp, keine lokale Uhr).
   Alte Versionen mit dem bisherigen 11-Feld-Schema funktionieren weiterhin.
2. Beim ersten GitHub-Actions-Lauf liest der Statistikjob die vorhandenen Spiele
   **einmalig**, in Portionen von bis zu 200 je Lauf. Das erfasst auch die
   bereits hochgeladenen Spiele ohne `uploadedAt`.
3. Nach dem Bootstrap fragt jeder 15-Minuten-Lauf **nur** Dokumente mit einem
   neueren `uploadedAt` ab. Der Cursor besteht aus dem serverseitigen Timestamp
   **und** der Dokument-ID (gleichzeitige Uploads werden nicht übersprungen).
4. Jedes Spiel wird atomar verarbeitet: in **einer** Firestore-Transaktion werden
   die Zähler erhöht, ein interner Beleg je Spiel-ID erstellt und der Cursor
   aktualisiert. Ein Wiederholungsversuch erhöht den Zähler nicht doppelt.

## Öffentliche Daten

- `statistics/global`: Spiele, Gewinne Gut/Böse, Gesamtspielzeit, Gesamtspieler,
  Nächte/Tage, Gesamtdauer der Nacht-/Tagesphasen, erfasste Tode/Wiederbelebungen.
  Durchschnittswerte sind Quotienten aus Summen und Anzahl der Spiele.
- `statistics/roles`: `byRole.{roleId}` mit Einsätzen, Siegen/Niederlagen,
  summierter Spieldauer und Wechseln der Startrolle. Rolle bedeutet hier
  **tatsächliche Startrolle**; für den Sieg zählt das **Endteam**.
- `statistics_scripts/{contentHash}`: Kennzahlen je eindeutigem Rollenlisteninhalt
  (SHA-256), Name, ID, benutzerdefiniert ja/nein und Skriptrollenzahl.

Die App kann diese Dokumente ohne Anmeldung lesen. Browser/Apps können sie
**nicht schreiben**. `statistics_private/progress` und
`statistics_processed/{gameId}` sind ausschließlich für Admin-SDK-Prozesse
zugänglich. Nicht als offene Firestore-Collection veröffentlichen.

## Ausführung

Workflow: `.github/workflows/aggregate-statistics.yml`

- Cron: **07, 22, 37, 52 Minuten** jeder Stunde. GitHub-Zeitpläne sind
  **best effort**: Starts können verspätet sein oder bei Last ausfallen.
- **Actions → Update global BotC statistics → Run workflow**: manueller Start
  mit Modus `incremental` (normal) oder `reconcile` (Vollabgleich).
- Falls beim Erstimport mehr als 200 Spiele vorliegen, setzt der nächste Lauf
  automatisch am letzten erfolgreich bestätigten Datensatz fort.
- Ein Vollabgleich ist **nur bei Bedarf** sinnvoll: Alte, bereits installierte
  APKs ohne `uploadedAt` können nach dem initialen Bootstrap weiterhin
  Spielberichte schreiben. Diese erscheinen **nicht** im 15-Minuten-Index.
  `reconcile` liest die Sammlung erneut und übernimmt fehlende Spiele
  mithilfe der Einmaligkeitsbelege. Ein regelmäßiger Vollscan würde
  unnötig Firestore-Lesekosten verursachen. Mit zunehmender Aktualisierung
  der Apps wird dieser Sonderfall verschwinden.
- Ungültige Spieldokumente werden als intern `invalid_game_record` markiert,
  ohne die restlichen Spiele zu blockieren. Details aus dem Spielbericht
  werden nicht ins Log geschrieben.
- Weder Firebase Functions noch ein weiterer dauerhaft laufender Server nötig.

## Einmalig: Service-Account-Rechte

Für `FIREBASE_SERVICE_ACCOUNT_B_O_T_C` wird neben den vorhandenen
Firebase-Hosting- und Rules-Rollen **Cloud Datastore User**
(`roles/datastore.user`) benötigt. Diese Rolle erlaubt Lese-/Schreibzugriffe
auf Firestore-Daten. Vergib sie auf Projekt `b-o-t-c` an den bereits
vorhandenen **GitHub Actions**-Service-Account in **Google Cloud → IAM**.
Keine JSON-Schlüssel im Repository speichern; das vorhandene GitHub Secret
wird erneut verwendet.

### Betrieb und Kosten

- Nur neue Spiele erzeugen inkrementelle Statistik-Schreibvorgänge. In
  Leerlaufphasen wird nur der Verarbeitungsstand und eine leere Firestore-Abfrage
  gelesen; die App liest nur wenige fertig aggregierte Dokumente.
- Bei großen Beständen können **erster Bootstrap** und manuelle
  `reconcile`-Läufe erhebliche Lesevorgänge auslösen. Ein fester
  Grenzwert von 200 verarbeiteten Spielen je Lauf begrenzt Lastspitzen.
- Firestore-Nutzung und GitHub Actions unterliegen Freikontingenten. Der
  Ansatz ist ohne kostenpflichtige Funktionen betreibbar, aber **nicht**
  garantiert für jede Datenmenge kostenfrei.

## Tests

- `node --test scripts/statistics/aggregate.test.mjs`
- Im Firestore-Emulator (Node-Abhängigkeiten vorher installieren):
  `npx firebase-tools emulators:exec --only firestore --project b-o-t-c "node test/firestore_rules_emulator_check.mjs && node --test scripts/statistics/*.test.mjs"`

Statistik-UI, Personenstatistiken, Fähigkeiten-Erfolgsquoten und
Zeitraumfilter sind **nicht** Teil dieses PRs.
