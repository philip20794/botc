import 'package:auto_size_text/auto_size_text.dart';
import 'package:blood_on_the_clocktower/components/select_character_component.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SelectOneCharater extends StatefulWidget {
  List<Character> charactersToChooseFrom;
  bool travellersAreSelectable = false;
  bool fabledAreSelectable = false;
  Function(Character) onConfirm;
  String title;
  String confirmButtonText;
  bool needToConfirm = true;

  SelectOneCharater({
    required this.charactersToChooseFrom,
    required this.onConfirm,
    required this.title,
    required this.confirmButtonText,
    this.travellersAreSelectable = false,
    this.fabledAreSelectable = false,
    this.needToConfirm = true,
  });

  _SelectOneCharaterState createState() => _SelectOneCharaterState();
}

class _SelectOneCharaterState extends State<SelectOneCharater> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AutoSizeText(widget.title.replaceAll("\n", ""),
            style: TextStyle(color: Colors.white),
            softWrap: false,
            maxLines: 2,
            minFontSize: 12),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              alignment: Alignment.bottomCenter,
              image: AssetImage(
                  'assets/images/backgrounds/background_grim_top.jpg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      body: SelectCharacterComponent(
        charactersToChooseFrom: widget.charactersToChooseFrom,
        onConfirm: () {},
        onResult: (List<Character> characters) {
          if (characters.isNotEmpty) {
            widget.onConfirm(characters[0]);
            Navigator.pop(context);
          }
        },
        needToConfirm: widget.needToConfirm,
        title: widget.title,
        confirmButtonText: widget.confirmButtonText,
        travellersAreSelectable: widget.travellersAreSelectable,
        fabledAreSelectable: widget.fabledAreSelectable,
      ),
    );
  }
}
