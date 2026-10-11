// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Beer Gang';

  @override
  String get impressum => 'Impressum';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get settings => 'Settings';

  @override
  String get email => 'E-Mail';

  @override
  String get de => 'Deutsch';

  @override
  String get en => 'English';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get kontakt => 'Contact';

  @override
  String get deutschland => 'Germany';

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
  String get cancel => 'Cancel';

  @override
  String get chooseTokenFor => 'Choose a token for';

  @override
  String get chooseNewCharacterFor => 'Choose a new character for';

  @override
  String get chooseACharacter => 'Choose a character';

  @override
  String get assign => 'Assign';

  @override
  String get wantToContinue => 'Continue?';

  @override
  String get reallyContinue => 'Do you really want to continue?';

  @override
  String demonBluffsMissing(int selected, int required) {
    return 'Only $selected of $required required Demon Bluffs has been selected.';
  }

  @override
  String get notEnoughBluffs =>
      'This script does not contain enough unselected good characters for three Demon Bluffs.';

  @override
  String get demonBluffs => 'Bluffs';

  @override
  String get noDemonBluffs =>
      'No Demon Bluffs were selected before this game started.';

  @override
  String get demonBluffsNotUsed =>
      'Demon Bluffs are only used with seven or more regular players.';

  @override
  String get yesContinue => 'Yes, continue';

  @override
  String get description => 'Description';

  @override
  String get howToRun => 'How to run';

  @override
  String get tipsAndTricks => 'Tips and Tricks';

  @override
  String bluffs(Object character) {
    return 'Bluffing to be the $character';
  }

  @override
  String fightingAgainst(Object character) {
    return 'Fighting against the $character';
  }

  @override
  String get toBeMadAbout => 'to be mad about';

  @override
  String get clickHere => 'Click here';

  @override
  String get addCharacter => 'Add character';

  @override
  String get playerName => 'Player name';

  @override
  String get playerAlreadyExists => 'Player already exists';

  @override
  String playerWithNameAlreadyExists(Object playerName) {
    return 'Player with name $playerName already exists';
  }

  @override
  String addPlayerAsCharacter(Object character, Object playerName) {
    return 'Add $playerName as $character';
  }

  @override
  String addPlayerName(Object playerName) {
    return 'Add $playerName';
  }

  @override
  String get notInTheFirstNight => '*Not in the first night';

  @override
  String get allCharactersOf => 'All characters of';

  @override
  String get layoutSettings => 'Layout settings';

  @override
  String get rules => 'Rules';

  @override
  String get characterSelection => 'Character selection';

  @override
  String get showCharactersToPlayers => 'Show characters to players';

  @override
  String get allCharacters => 'All characters';

  @override
  String get players => 'Players';

  @override
  String get playground => 'Playground';

  @override
  String get noPlayerYet => 'No players yet';

  @override
  String get characterSettings => 'Character settings';

  @override
  String get characterSize => 'Character size';

  @override
  String get numberPerRow => 'Number per row';

  @override
  String get distanceX => 'Distance X';

  @override
  String get distanceY => 'Distance Y';

  @override
  String get numberOfCharacters => 'Number of characters';

  @override
  String get tokenSettings => 'Token settings';

  @override
  String get tokenSize => 'Token size';

  @override
  String get tokenOffsetX => 'Token offset X';

  @override
  String get tokenOffsetY => 'Token offset Y';

  @override
  String get containerSettings => 'Container settings';

  @override
  String get containerOffsetX => 'Container offset X';

  @override
  String get containerOffsetY => 'Container offset Y';

  @override
  String get reallyWantToGoBack => 'Do you really want to go back?';

  @override
  String get onlyTheStorytellerMayGoBack => 'Only the storyteller may go back';

  @override
  String get yesImTheStoryteller => 'Yes, I\'m the storyteller';

  @override
  String get giveTheDeviceToTheStoryteller =>
      'Give the device to the storyteller';

  @override
  String get giveTheDeviceTo => 'Give the device to';

  @override
  String get iAmTheStoryteller => 'I am the storyteller';

  @override
  String get iAm => 'I am';

  @override
  String get onlyForTheStoryteller => 'Only for the storyteller';

  @override
  String get startGame => 'Start game';

  @override
  String get characterOf => 'Character of';

  @override
  String get pressAndHoldToSeeCharacter => 'Press and hold to see character';

  @override
  String get iHaveSeenMyCharacter => 'I have seen my character';

  @override
  String get endGame => 'End game?';

  @override
  String get reallyEndGame => 'Do you really want to end the game?';

  @override
  String get yesEndGame => 'Yes, end game';

  @override
  String get layoutReset => 'Layout reset?';

  @override
  String get reallyResetLayout => 'Do you really want to reset the layout?';

  @override
  String get yesResetLayout => 'Yes, reset layout';

  @override
  String get backToHomeScreen => 'Yes, back to Home';

  @override
  String get backToHomeScreenText =>
      'Do you really want to go back to the home screen';

  @override
  String get toHomeScreen => 'Go to Homescreen?';

  @override
  String get downloadAndroidApp => 'Download App (Android)';

  @override
  String get loginWithGoogle => 'Login with google';

  @override
  String get logout => 'Logout';

  @override
  String get password => 'Password';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get switchToRegister => 'Go to create account';

  @override
  String get switchToLogin => 'Back to login';

  @override
  String get roleNotes => 'Role notes';

  @override
  String get chooseRolesFor => 'Choose roles for';

  @override
  String get searchRoles => 'Search roles';

  @override
  String get clearRoles => 'Clear';

  @override
  String get clearAllRoleNotes => 'Clear all role notes?';

  @override
  String get maxFourRoles => 'Maximum four roles per player';

  @override
  String get noRoleNotesYet => 'No roles selected';

  @override
  String get noRolesFound => 'No roles found';

  @override
  String get importScript => 'Import script';

  @override
  String get manageScripts => 'Manage scripts';

  @override
  String get customScripts => 'Custom scripts';

  @override
  String get selectScriptFile => 'Select JSON file';

  @override
  String get scriptPreview => 'Script preview';

  @override
  String scriptAuthor(Object author) {
    return 'Author: $author';
  }

  @override
  String scriptRoleCount(Object count) {
    return 'Roles: $count';
  }

  @override
  String get storytellerComplexity => 'Storyteller complexity';

  @override
  String get playerComplexity => 'Player complexity';

  @override
  String get editComplexities => 'Edit complexity ratings';

  @override
  String get notRated => 'Not rated';

  @override
  String get save => 'Save';

  @override
  String get resetComplexities => 'Reset to defaults';

  @override
  String get unknownImportedRoles => 'Unrecognized characters';

  @override
  String get mapRole => 'Map role';

  @override
  String get confirmImport => 'Save script';

  @override
  String get resolveRolesBeforeSaving =>
      'Resolve all characters before saving.';

  @override
  String get scriptFileError => 'The selected file could not be read.';

  @override
  String get scriptImportError => 'The script could not be imported.';

  @override
  String get scriptInvalidJson => 'The selected file is not valid JSON.';

  @override
  String get scriptInvalidStructure => 'This is not a valid BOTC script file.';

  @override
  String get scriptInvalidMetadata =>
      'The script metadata is incomplete or invalid.';

  @override
  String get scriptInvalidRole => 'The script contains an invalid role entry.';

  @override
  String scriptUnknownRole(Object roleId) {
    return 'No known role matches \"$roleId\".';
  }

  @override
  String scriptAmbiguousRole(Object roleId) {
    return 'More than one role matches \"$roleId\".';
  }

  @override
  String scriptDuplicateRole(Object roleId) {
    return 'The role \"$roleId\" occurs more than once.';
  }

  @override
  String scriptUnsupportedRole(Object roleId) {
    return '\"$roleId\" is a character definition and must be mapped manually.';
  }

  @override
  String get deleteScript => 'Delete script';

  @override
  String deleteScriptConfirmation(Object scriptName) {
    return 'Delete \"$scriptName\"? This cannot be undone.';
  }

  @override
  String get scriptDeleted => 'Script deleted';

  @override
  String get scriptSaved => 'Script saved';

  @override
  String get scriptChangeWhileRunning =>
      'Scripts cannot be changed while a game is running.';

  @override
  String get noCustomScripts => 'No custom scripts saved yet.';

  @override
  String get pdfLoadError =>
      'This PDF could not be loaded. Check your internet connection and try again.';
}
