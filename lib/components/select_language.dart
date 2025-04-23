import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SelectLanguage extends StatefulWidget {
  const SelectLanguage({super.key});

  @override
  _SelectLanguageState createState() => _SelectLanguageState();
}

class _SelectLanguageState extends State<SelectLanguage> {
  @override
  Widget build(BuildContext context) {
    var localizedStrings = AppLocalizations.of(context)!;
    final characterService = Provider.of<CharacterService>(context);
    LanguageService languageService = Provider.of<LanguageService>(context);
    return DropdownButton<String>(
      dropdownColor: const Color(0xFF6f678a),
      value: languageService.locale.languageCode,
      underline: Container(), // Entfernt die standardmäßige Unterstreichung
      onChanged: (String? newValue) {
        setState(() {
          var local = Locale(newValue!);
          languageService.setLocale(local);
          characterService.loadAllCharactersFromJson(local);
        });
      },
      items: [
        DropdownMenuItem(
          value: 'de',
          child: Text(localizedStrings.de,
              style: const TextStyle(color: Colors.white)),
        ),
        DropdownMenuItem(
          value: 'en',
          child: Text(localizedStrings.en,
              style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
