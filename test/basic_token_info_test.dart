import 'package:blood_on_the_clocktower/l10n/app_localizations_de.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations_en.dart';
import 'package:blood_on_the_clocktower/models/enums/basicToken.dart';
import 'package:blood_on_the_clocktower/models/quick_flow.dart';
import 'package:blood_on_the_clocktower/utils/basic_token_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const supported = [
    Basictoken.you_are,
    Basictoken.this_player_is,
    Basictoken.this_is_the_demon,
    Basictoken.these_are_your_minions,
    Basictoken.this_chracter_selected_you,
    Basictoken.these_chracters_are_not_in_play,
    Basictoken.these_are_all_outsiders,
    Basictoken.choose_a_character,
    Basictoken.did_you_vote_today,
    Basictoken.did_you_nominate_today,
  ];

  test('every supported JSON information token maps to its BasicToken', () {
    for (final token in supported) {
      expect(basicTokenFromJson(token.name), token);
    }
    expect(basicTokenFromJson(''), isNull);
    expect(basicTokenFromJson('not_a_basic_token'), isNull);
  });

  test('BasicToken labels use existing English and German localizations', () {
    final english = AppLocalizationsEn();
    final german = AppLocalizationsDe();
    for (final token in supported) {
      expect(token.localizedText(english), isNotEmpty);
      expect(token.localizedText(german), isNotEmpty);
    }
    expect(Basictoken.you_are.localizedText(english), 'You \nare');
  });

  test(
      'QuickFlow presentation keeps infoToken optional and backward compatible',
      () {
    final withToken = QuickFlowPresentation.fromJson({
      'kind': 'youAre',
      'infoToken': 'you_are',
    })!;
    final withoutToken = QuickFlowPresentation.fromJson({'kind': 'youAre'})!;
    final unknownToken = QuickFlowPresentation.fromJson({
      'kind': 'youAre',
      'infoToken': 'unknown',
    })!;

    expect(withToken.infoToken, Basictoken.you_are);
    expect(withToken.toJson()['infoToken'], 'you_are');
    expect(withoutToken.infoToken, isNull);
    expect(withoutToken.toJson().containsKey('infoToken'), isFalse);
    expect(unknownToken.infoToken, isNull);
  });
}
