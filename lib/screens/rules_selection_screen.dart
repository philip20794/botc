import 'package:blood_on_the_clocktower/components/select_gameset.dart';
import 'package:blood_on_the_clocktower/screens/app_settings_screen.dart';
import 'package:blood_on_the_clocktower/screens/character_auswahl_screen.dart';
import 'package:blood_on_the_clocktower/screens/pdf_viewer_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class RulesSelectionScreen extends StatefulWidget {
  @override
  _RulesSelectionScreenState createState() => _RulesSelectionScreenState();
}

class _RulesSelectionScreenState extends State<RulesSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    var localizedStrings = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(localizedStrings.rules, style: TextStyle(color: Colors.white)),
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
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    'assets/images/backgrounds/background_grim_full.jpg'), // Path to your background image
                fit: BoxFit
                    .cover, // Ensures the image covers the entire background
              ),
            ),
          ),
          GridView.count(
            crossAxisCount: 2,
            children: [
              _buildCard("Main Rules", "main"),
              _buildCard("Trouble Brewing", "trouble_brewing"),
              _buildCard("Sects & Violets", "sects_and_violets"),
              _buildCard("Bad Moon Rising", "bad_moon_rising"),
              _buildCard("Traveller & Fabled", "traveller_and_fabled"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, String name) {
    var size = MediaQuery.of(context).size.height * 0.14;
    Uri pdfUri;
    switch (name) {
      case 'bad_moon_rising':
        pdfUri = Uri.parse(
            'https://firebasestorage.googleapis.com/v0/b/b-o-t-c.appspot.com/o/bad_moon_rising_Rulebook.pdf?alt=media&token=ac237de5-1dd3-4e10-8b0f-ebdc2639a3c0');
        break;
      case 'main':
        pdfUri = Uri.parse(
            'https://firebasestorage.googleapis.com/v0/b/b-o-t-c.appspot.com/o/main_Rulebook.pdf?alt=media&token=5a7540eb-65a5-48c1-9f79-dcccaafcdc33');
        break;
      case 'sects_and_violets':
        pdfUri = Uri.parse(
            'https://firebasestorage.googleapis.com/v0/b/b-o-t-c.appspot.com/o/sects_and_violets_Rulebook.pdf?alt=media&token=da63d238-edc8-4ecc-adb6-1cd50fe42ae4');
        break;
      case 'traveller_and_fabled':
        pdfUri = Uri.parse(
            'https://firebasestorage.googleapis.com/v0/b/b-o-t-c.appspot.com/o/traveller_and_fabled_Rulebook.pdf?alt=media&token=0720b102-8df3-4167-9414-7eeb681c5c5a');
        break;
      case 'trouble_brewing':
        pdfUri = Uri.parse(
            'https://firebasestorage.googleapis.com/v0/b/b-o-t-c.appspot.com/o/trouble_brewing_Rulebook.pdf?alt=media&token=3a91417a-c5d6-4b90-8b51-80f01dc93b91');
        break;
      default:
        throw Exception('Unknown name: $name');
    }
    return Center(
        child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        PdfViewerPage(pdfUrl: pdfUri, title: title)),
              );
            },
            child: Stack(
              children: [
                Positioned(
                  child: Container(
                    width: size * 1.4,
                    height: size * 1.4,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: AssetImage(
                            'assets/images/backgrounds/token.png'), // Zweites Bild
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                // Unterstes Bild
                Positioned(
                    top: size * 0.2,
                    left: size * 0.2,
                    child: Container(
                      width: size, // Breite und Höhe anpassen
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage('assets/rules/Logo_$name.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ))
                // Oberstes Bild
              ],
            )));
  }
}
