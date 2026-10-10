import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/models/token.dart';

class Character {
  String id = '';
  final String roleId;
  String name;
  String descriptionShort;
  String descriptionLong;
  String howToRun;
  String image;
  Fraction fraction;
  List<Gameset> gameset;
  List<Token> tokens;
  bool wakeUpEveryNight;
  bool wakeUpAtFirstNight;
  String nameOfChosenTarget = '';
  String playerName = '';
  List<double> nightStateNumbersFirstNight;
  List<double> nightStateNumbersOtherNights;
  String help = '';
  String help2 = '';
  bool upsideDown = false;
  List<String> tipsAndTricks;
  List<String> bluffs;
  int numberOfExemplars = 1;
  List<int> possibleNrOfExemplars;
  bool variableNumberOfExemplars = false;

  static String roleIdFromImage(String image) {
    final roleId = image
        .replaceFirst(RegExp(r'^Icon_'), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toLowerCase();
    return roleId.isEmpty ? image : roleId;
  }

  static bool hasLegacyRoleId(String? roleId, String image) {
    return roleId == null ||
        roleId.trim().isEmpty ||
        roleId == image ||
        roleId.startsWith('Icon_');
  }

  static String normalizedRoleId(String image, String? roleId) {
    return hasLegacyRoleId(roleId, image) ? roleIdFromImage(image) : roleId!;
  }

  Character({
    required this.name,
    required this.descriptionShort,
    required this.descriptionLong,
    required this.howToRun,
    required this.image,
    required this.fraction,
    required this.tokens,
    required this.wakeUpEveryNight,
    required this.wakeUpAtFirstNight,
    required this.gameset,
    required this.nightStateNumbersFirstNight,
    required this.nightStateNumbersOtherNights,
    required this.tipsAndTricks,
    required this.bluffs,
    this.playerName = '',
    this.help = '',
    this.help2 = '',
    this.upsideDown = false,
    this.numberOfExemplars = 1,
    this.variableNumberOfExemplars = false,
    this.possibleNrOfExemplars = const [],
    required this.id,
    String? roleId,
  }) : roleId = normalizedRoleId(image, roleId);

  // Methode zum Erstellen einer Card-Instanz aus JSON
  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      name: json['name'] as String,
      descriptionShort: json['descriptionShort'] as String,
      descriptionLong: json['descriptionLong'] as String,
      howToRun: json['howToRun'] as String,
      image: json['image'] as String,
      fraction: Fraction.values.firstWhere((e) => e.name == json['fraction']),
      tokens: (json['tokens'] as List<dynamic>)
          .map((tokenJson) => Token.fromJson(tokenJson as Map<String, dynamic>))
          .toList(),
      wakeUpEveryNight: json['wakeUpEveryNight'] as bool,
      wakeUpAtFirstNight: json['wakeUpAtFirstNight'] as bool,
      gameset: (json['gameset'] as List<dynamic>)
          .map((e) => Gameset.values.firstWhere((gs) => gs.name == e))
          .toList(),
      playerName:
          json['playerName'] != null ? json['playerName'] as String : '',
      nightStateNumbersFirstNight:
          (json['nightStateNumbersFirstNight'] as List<dynamic>)
              .map((e) => e as double)
              .toList(),
      nightStateNumbersOtherNights:
          (json['nightStateNumbersOtherNights'] as List<dynamic>)
              .map((e) => e as double)
              .toList(),
      help: json['help'] != null ? json['help'] as String : '',
      help2: json['help2'] != null ? json['help2'] as String : '',
      id: json['id'] as String? ?? json['image'] as String,
      roleId: json['roleId'] as String? ?? json['image'] as String,
      upsideDown:
          json['upsideDown'] != null ? json['upsideDown'] as bool : false,
      tipsAndTricks: (json['tipsAndTricks'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      bluffs:
          (json['bluffs'] as List<dynamic>).map((e) => e as String).toList(),
      numberOfExemplars: json['numberOfExemplars'] != null
          ? json['numberOfExemplars'] as int
          : 1,
      variableNumberOfExemplars: json['variableNumberOfExemplars'] as bool? ??
          json['numberOfExemplars'] != null,
      possibleNrOfExemplars: json['possibleNrOfExemplars'] != null
          ? (json['possibleNrOfExemplars'] as List<dynamic>)
              .map((e) => e as int)
              .toList()
          : [],
    );
  }

  // Methode zum Konvertieren der Card-Instanz in JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roleId': roleId,
      'name': name,
      'descriptionShort': descriptionShort,
      'descriptionLong': descriptionLong,
      'howToRun': howToRun,
      'image': image,
      'fraction': fraction.name,
      'tokens': tokens.map((token) => token.toJson()).toList(),
      'wakeUpEveryNight': wakeUpEveryNight,
      'wakeUpAtFirstNight': wakeUpAtFirstNight,
      'playerName': playerName,
      'gameset': gameset.map((gs) => gs.name).toList(),
      'nightStateNumbersFirstNight': nightStateNumbersFirstNight,
      'nightStateNumbersOtherNights': nightStateNumbersOtherNights,
      'help': help,
      'help2': help2,
      'upsideDown': upsideDown,
      'tipsAndTricks': tipsAndTricks,
      'bluffs': bluffs,
      'numberOfExemplars': numberOfExemplars,
      'variableNumberOfExemplars': variableNumberOfExemplars,
      'possibleNrOfExemplars': possibleNrOfExemplars,
    };
  }

  Character copyWith({String? id}) {
    return Character.fromJson({
      ...toJson(),
      'id': id ?? this.id,
    });
  }

  get getName => name;
  get getDescriptionShort => descriptionShort;
  get getDescriptionLong => descriptionLong;
  get getHowToRun => howToRun;
  get getImage => image;
  get getFraction => fraction;
  get getWakeUpEveryNight => wakeUpEveryNight;
  get getWakeUpAtFirstNight => wakeUpAtFirstNight;
  get getNameOfChosenTarget => nameOfChosenTarget;
  get getPlayerName => playerName;
  get getGameset => gameset;
  get getNightStateNumbersFirstNight => nightStateNumbersFirstNight;
  get getNightStateNumbersOtherNights => nightStateNumbersOtherNights;
  get getHelp => help;
  get getHelp2 => help2;
  get getId => id;
  get getRoleId => roleId;
  get getUpsideDown => upsideDown;
  get getTipsAndTricks => tipsAndTricks;
  get getBluffs => bluffs;
  get getNumberOfExemplars => numberOfExemplars;
  get getVariableNumberOfExemplars => variableNumberOfExemplars;
  get getPossibleNrOfExemplars => possibleNrOfExemplars;
}
