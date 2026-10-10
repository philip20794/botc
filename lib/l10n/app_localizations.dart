import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// No description provided for @appName.
  ///
  /// In de, this message translates to:
  /// **'Bier Bande'**
  String get appName;

  /// No description provided for @impressum.
  ///
  /// In de, this message translates to:
  /// **'Impressum'**
  String get impressum;

  /// No description provided for @privacyPolicy.
  ///
  /// In de, this message translates to:
  /// **'Datenschutz'**
  String get privacyPolicy;

  /// No description provided for @settings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settings;

  /// No description provided for @email.
  ///
  /// In de, this message translates to:
  /// **'E-Mail'**
  String get email;

  /// No description provided for @de.
  ///
  /// In de, this message translates to:
  /// **'Deutsch'**
  String get de;

  /// No description provided for @en.
  ///
  /// In de, this message translates to:
  /// **'English'**
  String get en;

  /// No description provided for @language.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In de, this message translates to:
  /// **'Sprache auswählen'**
  String get selectLanguage;

  /// No description provided for @kontakt.
  ///
  /// In de, this message translates to:
  /// **'Kontakt'**
  String get kontakt;

  /// No description provided for @deutschland.
  ///
  /// In de, this message translates to:
  /// **'Deutschland'**
  String get deutschland;

  /// No description provided for @this_chracter_selected_you.
  ///
  /// In de, this message translates to:
  /// **'This character \nselected you'**
  String get this_chracter_selected_you;

  /// No description provided for @you_are.
  ///
  /// In de, this message translates to:
  /// **'You \nare'**
  String get you_are;

  /// No description provided for @this_player_is.
  ///
  /// In de, this message translates to:
  /// **'This player is'**
  String get this_player_is;

  /// No description provided for @this_is_the_demon.
  ///
  /// In de, this message translates to:
  /// **'This is the demon'**
  String get this_is_the_demon;

  /// No description provided for @these_are_your_minions.
  ///
  /// In de, this message translates to:
  /// **'These are \nyour minions'**
  String get these_are_your_minions;

  /// No description provided for @these_chracters_are_not_in_play.
  ///
  /// In de, this message translates to:
  /// **'These Characters \nare not in play'**
  String get these_chracters_are_not_in_play;

  /// No description provided for @these_are_all_outsiders.
  ///
  /// In de, this message translates to:
  /// **'These are all \noutsiders in play'**
  String get these_are_all_outsiders;

  /// No description provided for @did_you_vote_today.
  ///
  /// In de, this message translates to:
  /// **'Did you \nvote today?'**
  String get did_you_vote_today;

  /// No description provided for @did_you_nominate_today.
  ///
  /// In de, this message translates to:
  /// **'Did you \nnominate today?'**
  String get did_you_nominate_today;

  /// No description provided for @choose_a_character.
  ///
  /// In de, this message translates to:
  /// **'Choose a \ncharacter'**
  String get choose_a_character;

  /// No description provided for @empty_string.
  ///
  /// In de, this message translates to:
  /// **'-'**
  String get empty_string;

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// No description provided for @chooseTokenFor.
  ///
  /// In de, this message translates to:
  /// **'Wähle einen Token für'**
  String get chooseTokenFor;

  /// No description provided for @chooseNewCharacterFor.
  ///
  /// In de, this message translates to:
  /// **'Wähle einen neuen Charakter für'**
  String get chooseNewCharacterFor;

  /// No description provided for @chooseACharacter.
  ///
  /// In de, this message translates to:
  /// **'Wähle einen Charakter'**
  String get chooseACharacter;

  /// No description provided for @assign.
  ///
  /// In de, this message translates to:
  /// **'Zuweisen'**
  String get assign;

  /// No description provided for @wantToContinue.
  ///
  /// In de, this message translates to:
  /// **'Fortfahren?'**
  String get wantToContinue;

  /// No description provided for @reallyContinue.
  ///
  /// In de, this message translates to:
  /// **'Möchtest du wirklich fortfahren?'**
  String get reallyContinue;

  /// No description provided for @yesContinue.
  ///
  /// In de, this message translates to:
  /// **'Ja, fortfahren'**
  String get yesContinue;

  /// No description provided for @description.
  ///
  /// In de, this message translates to:
  /// **'Beschreibung'**
  String get description;

  /// No description provided for @howToRun.
  ///
  /// In de, this message translates to:
  /// **'Anleitung (für den Erzähler)'**
  String get howToRun;

  /// No description provided for @tipsAndTricks.
  ///
  /// In de, this message translates to:
  /// **'Tipps und Tricks'**
  String get tipsAndTricks;

  /// No description provided for @bluffs.
  ///
  /// In de, this message translates to:
  /// **'So tun als ob du {character} wärst'**
  String bluffs(Object character);

  /// No description provided for @fightingAgainst.
  ///
  /// In de, this message translates to:
  /// **'Strategie gegen {character}'**
  String fightingAgainst(Object character);

  /// No description provided for @toBeMadAbout.
  ///
  /// In de, this message translates to:
  /// **'tu so als ob du der untere Charakter wärst'**
  String get toBeMadAbout;

  /// No description provided for @clickHere.
  ///
  /// In de, this message translates to:
  /// **'Hier klicken'**
  String get clickHere;

  /// No description provided for @addCharacter.
  ///
  /// In de, this message translates to:
  /// **'Charakter hinzufügen'**
  String get addCharacter;

  /// No description provided for @playerName.
  ///
  /// In de, this message translates to:
  /// **'Spielername'**
  String get playerName;

  /// No description provided for @playerAlreadyExists.
  ///
  /// In de, this message translates to:
  /// **'Spieler existiert bereits'**
  String get playerAlreadyExists;

  /// No description provided for @playerWithNameAlreadyExists.
  ///
  /// In de, this message translates to:
  /// **'Der Spieler mit dem Namen {playerName} existiert bereits'**
  String playerWithNameAlreadyExists(Object playerName);

  /// No description provided for @addPlayerAsCharacter.
  ///
  /// In de, this message translates to:
  /// **'Füge {playerName} als {character} hinzu'**
  String addPlayerAsCharacter(Object character, Object playerName);

  /// No description provided for @addPlayerName.
  ///
  /// In de, this message translates to:
  /// **'{playerName} hinzufügen'**
  String addPlayerName(Object playerName);

  /// No description provided for @notInTheFirstNight.
  ///
  /// In de, this message translates to:
  /// **'*Nicht in der ersten Nacht'**
  String get notInTheFirstNight;

  /// No description provided for @allCharactersOf.
  ///
  /// In de, this message translates to:
  /// **'Alle Charaktere von'**
  String get allCharactersOf;

  /// No description provided for @layoutSettings.
  ///
  /// In de, this message translates to:
  /// **'Layout-Einstellungen'**
  String get layoutSettings;

  /// No description provided for @rules.
  ///
  /// In de, this message translates to:
  /// **'Regeln'**
  String get rules;

  /// No description provided for @characterSelection.
  ///
  /// In de, this message translates to:
  /// **'Charakterauswahl'**
  String get characterSelection;

  /// No description provided for @showCharactersToPlayers.
  ///
  /// In de, this message translates to:
  /// **'Zeige die Charaktere'**
  String get showCharactersToPlayers;

  /// No description provided for @allCharacters.
  ///
  /// In de, this message translates to:
  /// **'Alle Charaktere'**
  String get allCharacters;

  /// No description provided for @players.
  ///
  /// In de, this message translates to:
  /// **'Spieler'**
  String get players;

  /// No description provided for @playground.
  ///
  /// In de, this message translates to:
  /// **'Spielbereich'**
  String get playground;

  /// No description provided for @noPlayerYet.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Spieler'**
  String get noPlayerYet;

  /// No description provided for @characterSettings.
  ///
  /// In de, this message translates to:
  /// **'Charakter-Einstellungen'**
  String get characterSettings;

  /// No description provided for @characterSize.
  ///
  /// In de, this message translates to:
  /// **'Charaktergröße'**
  String get characterSize;

  /// No description provided for @numberPerRow.
  ///
  /// In de, this message translates to:
  /// **'Anzahl pro Reihe'**
  String get numberPerRow;

  /// No description provided for @distanceX.
  ///
  /// In de, this message translates to:
  /// **'Abstand X'**
  String get distanceX;

  /// No description provided for @distanceY.
  ///
  /// In de, this message translates to:
  /// **'Abstand Y'**
  String get distanceY;

  /// No description provided for @numberOfCharacters.
  ///
  /// In de, this message translates to:
  /// **'Anzahl der Charaktere'**
  String get numberOfCharacters;

  /// No description provided for @tokenSettings.
  ///
  /// In de, this message translates to:
  /// **'Token-Einstellungen'**
  String get tokenSettings;

  /// No description provided for @tokenSize.
  ///
  /// In de, this message translates to:
  /// **'Token-Größe'**
  String get tokenSize;

  /// No description provided for @tokenOffsetX.
  ///
  /// In de, this message translates to:
  /// **'Token-Versatz X'**
  String get tokenOffsetX;

  /// No description provided for @tokenOffsetY.
  ///
  /// In de, this message translates to:
  /// **'Token-Versatz Y'**
  String get tokenOffsetY;

  /// No description provided for @containerSettings.
  ///
  /// In de, this message translates to:
  /// **'Container-Einstellungen'**
  String get containerSettings;

  /// No description provided for @containerOffsetX.
  ///
  /// In de, this message translates to:
  /// **'Container-Versatz X'**
  String get containerOffsetX;

  /// No description provided for @containerOffsetY.
  ///
  /// In de, this message translates to:
  /// **'Container-Versatz Y'**
  String get containerOffsetY;

  /// No description provided for @reallyWantToGoBack.
  ///
  /// In de, this message translates to:
  /// **'Möchtest du wirklich zurückgehen?'**
  String get reallyWantToGoBack;

  /// No description provided for @onlyTheStorytellerMayGoBack.
  ///
  /// In de, this message translates to:
  /// **'Nur der Erzähler darf zurückgehen'**
  String get onlyTheStorytellerMayGoBack;

  /// No description provided for @yesImTheStoryteller.
  ///
  /// In de, this message translates to:
  /// **'Ja, ich bin der Erzähler'**
  String get yesImTheStoryteller;

  /// No description provided for @giveTheDeviceToTheStoryteller.
  ///
  /// In de, this message translates to:
  /// **'Gib das Gerät dem Erzähler'**
  String get giveTheDeviceToTheStoryteller;

  /// No description provided for @giveTheDeviceTo.
  ///
  /// In de, this message translates to:
  /// **'Gib das Gerät an'**
  String get giveTheDeviceTo;

  /// No description provided for @iAmTheStoryteller.
  ///
  /// In de, this message translates to:
  /// **'Ich bin der Erzähler'**
  String get iAmTheStoryteller;

  /// No description provided for @iAm.
  ///
  /// In de, this message translates to:
  /// **'Ich bin'**
  String get iAm;

  /// No description provided for @onlyForTheStoryteller.
  ///
  /// In de, this message translates to:
  /// **'Nur für den Erzähler'**
  String get onlyForTheStoryteller;

  /// No description provided for @startGame.
  ///
  /// In de, this message translates to:
  /// **'Spiel starten'**
  String get startGame;

  /// No description provided for @characterOf.
  ///
  /// In de, this message translates to:
  /// **'Charakter von'**
  String get characterOf;

  /// No description provided for @pressAndHoldToSeeCharacter.
  ///
  /// In de, this message translates to:
  /// **'Drücke und halte, um den Charakter zu sehen'**
  String get pressAndHoldToSeeCharacter;

  /// No description provided for @iHaveSeenMyCharacter.
  ///
  /// In de, this message translates to:
  /// **'Ich habe meinen Charakter gesehen'**
  String get iHaveSeenMyCharacter;

  /// No description provided for @endGame.
  ///
  /// In de, this message translates to:
  /// **'Spiel beenden?'**
  String get endGame;

  /// No description provided for @reallyEndGame.
  ///
  /// In de, this message translates to:
  /// **'Möchtest du das Spiel wirklich beenden?'**
  String get reallyEndGame;

  /// No description provided for @yesEndGame.
  ///
  /// In de, this message translates to:
  /// **'Ja, Spiel beenden'**
  String get yesEndGame;

  /// No description provided for @layoutReset.
  ///
  /// In de, this message translates to:
  /// **'Layout zurücksetzen?'**
  String get layoutReset;

  /// No description provided for @reallyResetLayout.
  ///
  /// In de, this message translates to:
  /// **'Möchtest du das Layout wirklich zurücksetzen?'**
  String get reallyResetLayout;

  /// No description provided for @yesResetLayout.
  ///
  /// In de, this message translates to:
  /// **'Ja, Layout zurücksetzen'**
  String get yesResetLayout;

  /// No description provided for @backToHomeScreen.
  ///
  /// In de, this message translates to:
  /// **'Ja, zurück zum Startbildschirm'**
  String get backToHomeScreen;

  /// No description provided for @backToHomeScreenText.
  ///
  /// In de, this message translates to:
  /// **'Möchtest du wirklich zurück zum Startbildschirm'**
  String get backToHomeScreenText;

  /// No description provided for @toHomeScreen.
  ///
  /// In de, this message translates to:
  /// **'Zum Startbildschirm?'**
  String get toHomeScreen;

  /// No description provided for @downloadAndroidApp.
  ///
  /// In de, this message translates to:
  /// **'Download App (Android)'**
  String get downloadAndroidApp;

  /// No description provided for @loginWithGoogle.
  ///
  /// In de, this message translates to:
  /// **'Mit google einloggen'**
  String get loginWithGoogle;

  /// No description provided for @logout.
  ///
  /// In de, this message translates to:
  /// **'Ausloggen'**
  String get logout;

  /// No description provided for @password.
  ///
  /// In de, this message translates to:
  /// **'Passwort'**
  String get password;

  /// No description provided for @login.
  ///
  /// In de, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @register.
  ///
  /// In de, this message translates to:
  /// **'Registrieren'**
  String get register;

  /// No description provided for @switchToRegister.
  ///
  /// In de, this message translates to:
  /// **'Zum Benutzer erstellen'**
  String get switchToRegister;

  /// No description provided for @switchToLogin.
  ///
  /// In de, this message translates to:
  /// **'Zurück zum login'**
  String get switchToLogin;

  /// No description provided for @roleNotes.
  ///
  /// In de, this message translates to:
  /// **'Verdachtsübersicht'**
  String get roleNotes;

  /// No description provided for @chooseRolesFor.
  ///
  /// In de, this message translates to:
  /// **'Rollen wählen für'**
  String get chooseRolesFor;

  /// No description provided for @searchRoles.
  ///
  /// In de, this message translates to:
  /// **'Rollen suchen'**
  String get searchRoles;

  /// No description provided for @clearRoles.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get clearRoles;

  /// No description provided for @clearAllRoleNotes.
  ///
  /// In de, this message translates to:
  /// **'Alle Verdachtsrollen löschen?'**
  String get clearAllRoleNotes;

  /// No description provided for @maxFourRoles.
  ///
  /// In de, this message translates to:
  /// **'Maximal vier Rollen pro Spieler'**
  String get maxFourRoles;

  /// No description provided for @noRoleNotesYet.
  ///
  /// In de, this message translates to:
  /// **'Keine Rollen ausgewählt'**
  String get noRoleNotesYet;

  /// No description provided for @noRolesFound.
  ///
  /// In de, this message translates to:
  /// **'Keine Rollen gefunden'**
  String get noRolesFound;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
