// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'Bier Bande';

  @override
  String get impressum => 'Impressum';

  @override
  String get privacyPolicy => 'Datenschutz';

  @override
  String get settings => 'Einstellungen';

  @override
  String get email => 'E-Mail';

  @override
  String get de => 'Deutsch';

  @override
  String get en => 'English';

  @override
  String get language => 'Sprache';

  @override
  String get selectLanguage => 'Sprache auswählen';

  @override
  String get kontakt => 'Kontakt';

  @override
  String get deutschland => 'Deutschland';

  @override
  String get this_chracter_selected_you => 'This character \nselected you';

  @override
  String get you_are => 'You \nare';

  @override
  String get this_player_is => 'This player is';

  @override
  String get this_is_the_demon => 'This is the demon';

  @override
  String get these_are_your_minions => 'These are \nyour minions';

  @override
  String get these_chracters_are_not_in_play =>
      'These Characters \nare not in play';

  @override
  String get these_are_all_outsiders => 'These are all \noutsiders in play';

  @override
  String get did_you_vote_today => 'Did you \nvote today?';

  @override
  String get did_you_nominate_today => 'Did you \nnominate today?';

  @override
  String get choose_a_character => 'Choose a \ncharacter';

  @override
  String get empty_string => '-';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get chooseTokenFor => 'Wähle einen Token für';

  @override
  String get chooseNewCharacterFor => 'Wähle einen neuen Charakter für';

  @override
  String get chooseACharacter => 'Wähle einen Charakter';

  @override
  String get assign => 'Zuweisen';

  @override
  String get wantToContinue => 'Fortfahren?';

  @override
  String get reallyContinue => 'Möchtest du wirklich fortfahren?';

  @override
  String demonBluffsMissing(int selected, int required) {
    return 'Nur $selected von $required erforderlichen Dämonen-Bluffs wurden ausgewählt.';
  }

  @override
  String get notEnoughBluffs =>
      'Dieses Skript enthält nicht genug nicht ausgewählte gute Charaktere für drei Dämonen-Bluffs.';

  @override
  String get demonBluffs => 'Bluffs';

  @override
  String get noDemonBluffs =>
      'Vor dem Start dieser Partie wurden keine Dämonen-Bluffs ausgewählt.';

  @override
  String get demonBluffsNotUsed =>
      'Dämonen-Bluffs werden nur bei sieben oder mehr regulären Spielern verwendet.';

  @override
  String get yesContinue => 'Ja, fortfahren';

  @override
  String get description => 'Beschreibung';

  @override
  String get howToRun => 'Anleitung (für den Erzähler)';

  @override
  String get tipsAndTricks => 'Tipps und Tricks';

  @override
  String bluffs(Object character) {
    return 'So tun als ob du $character wärst';
  }

  @override
  String fightingAgainst(Object character) {
    return 'Strategie gegen $character';
  }

  @override
  String get toBeMadAbout => 'tu so als ob du der untere Charakter wärst';

  @override
  String get clickHere => 'Hier klicken';

  @override
  String get addCharacter => 'Charakter hinzufügen';

  @override
  String get playerName => 'Spielername';

  @override
  String get playerAlreadyExists => 'Spieler existiert bereits';

  @override
  String playerWithNameAlreadyExists(Object playerName) {
    return 'Der Spieler mit dem Namen $playerName existiert bereits';
  }

  @override
  String addPlayerAsCharacter(Object character, Object playerName) {
    return 'Füge $playerName als $character hinzu';
  }

  @override
  String addPlayerName(Object playerName) {
    return '$playerName hinzufügen';
  }

  @override
  String get notInTheFirstNight => '*Nicht in der ersten Nacht';

  @override
  String get allCharactersOf => 'Alle Charaktere von';

  @override
  String get layoutSettings => 'Layout-Einstellungen';

  @override
  String get rules => 'Regeln';

  @override
  String get characterSelection => 'Charakterauswahl';

  @override
  String get showCharactersToPlayers => 'Zeige die Charaktere';

  @override
  String get allCharacters => 'Alle Charaktere';

  @override
  String get players => 'Spieler';

  @override
  String get playground => 'Spielbereich';

  @override
  String get noPlayerYet => 'Noch keine Spieler';

  @override
  String get characterSettings => 'Charakter-Einstellungen';

  @override
  String get characterSize => 'Charaktergröße';

  @override
  String get numberPerRow => 'Anzahl pro Reihe';

  @override
  String get distanceX => 'Abstand X';

  @override
  String get distanceY => 'Abstand Y';

  @override
  String get numberOfCharacters => 'Anzahl der Charaktere';

  @override
  String get tokenSettings => 'Token-Einstellungen';

  @override
  String get tokenSize => 'Token-Größe';

  @override
  String get reminderTokenSettings => 'Reminder-Token-Einstellungen';

  @override
  String get selectedReminderSize => 'Größe ausgewählter Reminder';

  @override
  String get unselectedReminderSize => 'Größe nicht ausgewählter Reminder';

  @override
  String get tokenOffsetX => 'Token-Versatz X';

  @override
  String get tokenOffsetY => 'Token-Versatz Y';

  @override
  String get containerSettings => 'Container-Einstellungen';

  @override
  String get containerOffsetX => 'Container-Versatz X';

  @override
  String get containerOffsetY => 'Container-Versatz Y';

  @override
  String get reallyWantToGoBack => 'Möchtest du wirklich zurückgehen?';

  @override
  String get onlyTheStorytellerMayGoBack => 'Nur der Erzähler darf zurückgehen';

  @override
  String get yesImTheStoryteller => 'Ja, ich bin der Erzähler';

  @override
  String get giveTheDeviceToTheStoryteller => 'Gib das Gerät dem Erzähler';

  @override
  String get giveTheDeviceTo => 'Gib das Gerät an';

  @override
  String get iAmTheStoryteller => 'Ich bin der Erzähler';

  @override
  String get iAm => 'Ich bin';

  @override
  String get onlyForTheStoryteller => 'Nur für den Erzähler';

  @override
  String get startGame => 'Spiel starten';

  @override
  String get characterOf => 'Charakter von';

  @override
  String get pressAndHoldToSeeCharacter =>
      'Drücke und halte, um den Charakter zu sehen';

  @override
  String get iHaveSeenMyCharacter => 'Ich habe meinen Charakter gesehen';

  @override
  String get endGame => 'Spiel beenden?';

  @override
  String get reallyEndGame => 'Möchtest du das Spiel wirklich beenden?';

  @override
  String get yesEndGame => 'Ja, Spiel beenden';

  @override
  String get winningTeamOptional => 'Gewinnerteam (optional)';

  @override
  String get goodTeam => 'Gut';

  @override
  String get evilTeam => 'Böse';

  @override
  String get gameInProgress => 'Spiel läuft noch';

  @override
  String get endRunningGameToContinue =>
      'Um Spieler oder Charaktere neu auszuwählen, musst du zuerst das laufende Spiel beenden.';

  @override
  String get layoutReset => 'Layout zurücksetzen?';

  @override
  String get reallyResetLayout =>
      'Möchtest du das Layout wirklich zurücksetzen?';

  @override
  String get yesResetLayout => 'Ja, Layout zurücksetzen';

  @override
  String get backToHomeScreen => 'Ja, zurück zum Startbildschirm';

  @override
  String get backToHomeScreenText =>
      'Möchtest du wirklich zurück zum Startbildschirm';

  @override
  String get toHomeScreen => 'Zum Startbildschirm?';

  @override
  String get downloadAndroidApp => 'Download App (Android)';

  @override
  String get loginWithGoogle => 'Mit google einloggen';

  @override
  String get logout => 'Ausloggen';

  @override
  String get password => 'Passwort';

  @override
  String get login => 'Login';

  @override
  String get register => 'Registrieren';

  @override
  String get switchToRegister => 'Zum Benutzer erstellen';

  @override
  String get switchToLogin => 'Zurück zum login';

  @override
  String get roleNotes => 'Verdachtsübersicht';

  @override
  String get chooseRolesFor => 'Rollen wählen für';

  @override
  String get searchRoles => 'Rollen suchen';

  @override
  String get clearRoles => 'Löschen';

  @override
  String get clearAllRoleNotes => 'Alle Verdachtsrollen löschen?';

  @override
  String get maxFourRoles => 'Maximal vier Rollen pro Spieler';

  @override
  String get noRoleNotesYet => 'Keine Rollen ausgewählt';

  @override
  String get noRolesFound => 'Keine Rollen gefunden';

  @override
  String get importScript => 'Skript importieren';

  @override
  String get manageScripts => 'Skripte verwalten';

  @override
  String get customScripts => 'Eigene Skripte';

  @override
  String get selectScriptFile => 'JSON-Datei auswählen';

  @override
  String get or => 'ODER';

  @override
  String get pasteJson => 'JSON einfügen';

  @override
  String get pasteJsonHint =>
      'Füge hier ein exportiertes Blood-on-the-Clocktower-Skript ein.';

  @override
  String get analyzeScript => 'Analysieren';

  @override
  String get scriptsCreateDiscover => 'Skripte erstellen & entdecken';

  @override
  String get scriptsCreateDiscoverDescription =>
      'Erstelle eigene Blood-on-the-Clocktower-Skripte oder entdecke Skripte anderer Spieler. Exportiere sie als JSON und importiere sie hier per Datei oder Copy & Paste.';

  @override
  String get openScriptTool => 'Script Tool öffnen';

  @override
  String get scriptToolError => 'Das Script Tool konnte nicht geöffnet werden.';

  @override
  String get scriptPreview => 'Skriptvorschau';

  @override
  String scriptAuthor(Object author) {
    return 'Autor: $author';
  }

  @override
  String scriptRoleCount(Object count) {
    return 'Rollen: $count';
  }

  @override
  String get storytellerComplexity => 'Komplexität für die Spielleitung';

  @override
  String get playerComplexity => 'Spielerkomplexität';

  @override
  String get editComplexities => 'Schwierigkeitsbewertungen bearbeiten';

  @override
  String get notRated => 'Nicht bewertet';

  @override
  String get save => 'Speichern';

  @override
  String get resetComplexities => 'Auf Standardwerte zurücksetzen';

  @override
  String get unknownImportedRoles => 'Unbekannte Charaktere';

  @override
  String get mapRole => 'Rolle zuordnen';

  @override
  String get confirmImport => 'Skript speichern';

  @override
  String get resolveRolesBeforeSaving =>
      'Ordne vor dem Speichern alle Charaktere zu.';

  @override
  String get scriptFileError =>
      'Die ausgewählte Datei konnte nicht gelesen werden.';

  @override
  String get scriptImportError => 'Das Skript konnte nicht importiert werden.';

  @override
  String get scriptInvalidJson =>
      'Die ausgewählte Datei ist kein gültiges JSON.';

  @override
  String get scriptInvalidStructure =>
      'Dies ist keine gültige BOTC-Skriptdatei.';

  @override
  String get scriptInvalidMetadata =>
      'Die Metadaten des Skripts sind unvollständig oder ungültig.';

  @override
  String get scriptInvalidRole =>
      'Das Skript enthält einen ungültigen Rolleneintrag.';

  @override
  String scriptUnknownRole(Object roleId) {
    return 'Keine bekannte Rolle entspricht \"$roleId\".';
  }

  @override
  String scriptAmbiguousRole(Object roleId) {
    return 'Mehrere Rollen entsprechen \"$roleId\".';
  }

  @override
  String scriptDuplicateRole(Object roleId) {
    return 'Die Rolle \"$roleId\" kommt mehrfach vor.';
  }

  @override
  String scriptUnsupportedRole(Object roleId) {
    return '\"$roleId\" ist eine Charakterdefinition und muss manuell zugeordnet werden.';
  }

  @override
  String get deleteScript => 'Skript löschen';

  @override
  String deleteScriptConfirmation(Object scriptName) {
    return '\"$scriptName\" löschen? Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get scriptDeleted => 'Skript gelöscht';

  @override
  String get scriptSaved => 'Skript gespeichert';

  @override
  String get scriptChangeWhileRunning =>
      'Skripte können während einer laufenden Partie nicht geändert werden.';

  @override
  String get noCustomScripts => 'Noch keine eigenen Skripte gespeichert.';

  @override
  String get pdfLoadError =>
      'Dieses PDF konnte nicht geladen werden. Prüfe deine Internetverbindung und versuche es erneut.';

  @override
  String get quickFlowInvalidTarget =>
      'Dieser Spieler ist kein gültiges Ziel für den ausgewählten Reminder.';

  @override
  String get quickFlowPreviousNightTarget =>
      'Wähle einen anderen Spieler als in der vorherigen Nacht.';

  @override
  String get quickFlowUnsupported =>
      'Dieser QuickFlow-Schritt muss über das Spieler-Menü ausgeführt werden.';

  @override
  String get onlyTheStorytellerMayContinue =>
      'Nur der Erzähler darf fortfahren.';

  @override
  String get skipQuickFlowAction => 'Überspringen';

  @override
  String get chronicleEntryRemoved => 'Eintrag entfernt';

  @override
  String get undo => 'Rückgängig';

  @override
  String get chronicleDeadTitle => 'Tot';

  @override
  String get chronicleRevivedTitle => 'Wiederbelebt';

  @override
  String get continueText => 'Weiter';

  @override
  String get chronicle => 'Chronik';

  @override
  String get lastChronicle => 'Letzte Chronik';

  @override
  String get chronicleEmpty => 'Noch keine Chronik-Einträge vorhanden.';

  @override
  String get chronicleSetup => 'Aufbau';

  @override
  String chronicleNight(int round) {
    return 'Nacht $round';
  }

  @override
  String chronicleDay(int round) {
    return 'Tag $round';
  }

  @override
  String get chronicleGameStarted => 'Spiel gestartet';

  @override
  String get chroniclePhaseStarted => 'Phase begonnen';

  @override
  String chronicleDied(String player) {
    return '$player ist gestorben.';
  }

  @override
  String chronicleRevived(String player) {
    return '$player lebt wieder.';
  }

  @override
  String chronicleReminderAssigned(String token, String player) {
    return '$token wurde $player zugewiesen.';
  }

  @override
  String chronicleReminderMoved(String token, String from, String to) {
    return '$token wurde von $from zu $to verschoben.';
  }

  @override
  String chronicleReminderRemoved(String token, String player) {
    return '$token wurde von $player entfernt.';
  }

  @override
  String chronicleCharacterChanged(String player, String from, String to) {
    return '$player: $from wurde zu $to.';
  }

  @override
  String chronicleQuickCharacter(String role) {
    return '$role wurde für den QuickFlow ausgewählt.';
  }

  @override
  String chronicleQuickInfo(String role) {
    return 'Die vorbereitete Information für $role wurde gezeigt.';
  }

  @override
  String get chronicleMissingInformation => 'Noch keine Information erfasst';

  @override
  String get chronicleRecordInformation => 'Information erfassen';

  @override
  String chronicleSelectPlayers(int count) {
    return '$count Spieler auswählen';
  }

  @override
  String get chronicleAnswerYes => 'Ja';

  @override
  String get chronicleAnswerNo => 'Nein';

  @override
  String chronicleNumberResult(int value) {
    return 'Information: $value';
  }

  @override
  String chronicleYesNoResult(String answer) {
    return 'Information: $answer';
  }

  @override
  String chroniclePlayersResult(String players) {
    return 'Ausgewählt: $players';
  }

  @override
  String get chronicleAddDetails => 'Details ergänzen';

  @override
  String get chronicleAddAnother => 'Weiteren Eintrag hinzufügen';

  @override
  String get chronicleAddOptionalEvent => 'Optionales Ereignis hinzufügen';

  @override
  String get chronicleRemoveEntry => 'Eintrag entfernen';

  @override
  String get chronicleClearValue => 'Wert löschen';

  @override
  String get chronicleInvalidNumber =>
      'Gib eine Zahl im konfigurierten Bereich ein.';

  @override
  String get chronicleSelect => 'Auswählen';

  @override
  String get chronicleSearch => 'Suchen';

  @override
  String get chronicleIncomplete => 'Unvollständiger Eintrag';

  @override
  String chronicleExactCount(int count) {
    return 'Konfigurierte Auswahl: $count';
  }

  @override
  String chronicleCountRange(int min, String max) {
    return 'Konfigurierte Auswahl: $min–$max';
  }

  @override
  String chronicleNightActionVisited(String role) {
    return 'Nachtaktion von $role besucht.';
  }
}
