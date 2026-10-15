import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:blood_on_the_clocktower/custom_icons.dart';
import 'package:blood_on_the_clocktower/components/select_character_component.dart';
import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SelectOneCharater extends StatefulWidget {
  final List<Character> charactersToChooseFrom;
  final bool travellersAreSelectable;
  final bool fabledAreSelectable;
  final FutureOr<void> Function(Character) onConfirm;
  final String title;
  final String confirmButtonText;
  final bool needToConfirm;
  final List<Character>? allCharactersToChooseFrom;
  final Future<void> Function(BuildContext context, Character character)?
      onSelectionConfirmed;

  SelectOneCharater({
    required this.charactersToChooseFrom,
    required this.onConfirm,
    required this.title,
    required this.confirmButtonText,
    this.travellersAreSelectable = false,
    this.fabledAreSelectable = false,
    this.needToConfirm = true,
    this.allCharactersToChooseFrom,
    this.onSelectionConfirmed,
  });

  _SelectOneCharaterState createState() => _SelectOneCharaterState();
}

class _SelectOneCharaterState extends State<SelectOneCharater> {
  bool _showAllCharacters = false;

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: AutoSizeText(widget.title.replaceAll("\n", ""),
              style: TextStyle(color: Colors.white),
              softWrap: false,
              maxLines: 2,
              minFontSize: 12),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (widget.allCharactersToChooseFrom != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ToggleButtons(
                  key: const ValueKey('quick-flow-character-source-toggle'),
                  constraints:
                      const BoxConstraints(minHeight: 34, minWidth: 42),
                  borderRadius: BorderRadius.circular(8),
                  isSelected: [_showAllCharacters == false, _showAllCharacters],
                  onPressed: (index) => setState(() {
                    _showAllCharacters = index == 1;
                  }),
                  children: const [
                    Tooltip(
                      message: 'Script characters',
                      child: Icon(CustomIcons.script, color: Colors.white),
                    ),
                    Tooltip(
                      message: 'All characters',
                      child: Icon(Icons.apps, color: Colors.white),
                    ),
                  ],
                ),
              ),
          ],
        ),
        body: SelectCharacterComponent(
          charactersToChooseFrom: _showAllCharacters
              ? widget.allCharactersToChooseFrom!
              : widget.charactersToChooseFrom,
          onConfirm: () {},
          onResult: (List<Character> characters) async {
            if (characters.isNotEmpty) {
              final selectorContext = context;
              await widget.onConfirm(characters[0]);
              if (!selectorContext.mounted) return;
              if (widget.onSelectionConfirmed != null) {
                await widget.onSelectionConfirmed!(
                    selectorContext, characters[0]);
              } else if (selectorContext.mounted) {
                Navigator.pop(selectorContext);
              }
            }
          },
          needToConfirm: widget.needToConfirm,
          title: widget.title,
          confirmButtonText: widget.confirmButtonText,
          travellersAreSelectable: widget.travellersAreSelectable,
          fabledAreSelectable: widget.fabledAreSelectable,
          showBackground: false,
        ),
      ),
    );
  }
}
