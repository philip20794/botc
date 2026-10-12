import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/enums/basicToken.dart';

/// Resolves a persisted JSON spelling to the existing BasicToken enum.
/// Unknown and empty values deliberately result in no information sign.
Basictoken? basicTokenFromJson(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  for (final token in Basictoken.values) {
    if (token != Basictoken.empty_string && token.name == value) {
      return token;
    }
  }
  return null;
}

extension BasicTokenLocalization on Basictoken {
  String localizedText(AppLocalizations localized) => switch (this) {
        Basictoken.this_chracter_selected_you =>
          localized.this_chracter_selected_you,
        Basictoken.you_are => localized.you_are,
        Basictoken.this_player_is => localized.this_player_is,
        Basictoken.this_is_the_demon => localized.this_is_the_demon,
        Basictoken.these_are_your_minions => localized.these_are_your_minions,
        Basictoken.these_chracters_are_not_in_play =>
          localized.these_chracters_are_not_in_play,
        Basictoken.these_are_all_outsiders => localized.these_are_all_outsiders,
        Basictoken.did_you_vote_today => localized.did_you_vote_today,
        Basictoken.did_you_nominate_today => localized.did_you_nominate_today,
        Basictoken.choose_a_character => localized.choose_a_character,
        Basictoken.empty_string => localized.empty_string,
      };
}
