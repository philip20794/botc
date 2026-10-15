import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/screens/pdf_viewer_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';

class RulesSelectionScreen extends StatefulWidget {
  @override
  _RulesSelectionScreenState createState() => _RulesSelectionScreenState();
}

class _RulesSelectionScreenState extends State<RulesSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    var localizedStrings = AppLocalizations.of(context)!;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(localizedStrings.rules,
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: GridView.count(
          crossAxisCount: 2,
          children: [
            _buildCard("Main Rules", "main"),
            _buildCard("Trouble Brewing", "trouble_brewing"),
            _buildCard("Sects & Violets", "sects_and_violets"),
            _buildCard("Bad Moon Rising", "bad_moon_rising"),
            _buildCard("Traveller & Fabled", "traveller_and_fabled"),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, String name) {
    var size = MediaQuery.of(context).size.height * 0.14;
    final pdfUri = rulePdfUriFor(name);
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

/// Official TPI links resolve to these current public PDF download endpoints.
Uri rulePdfUriFor(String name) {
  const documentIds = <String, String>{
    'main': '1kZYrIq4P6l4IOcm70-hZE-jPrnq8EeMk',
    'trouble_brewing': '1nsPHYi4B48GpRTV_V24Zu5MATT3hWIV3',
    'sects_and_violets': '12Kcyfk0tbEfXF0E-X5k8zYNmkDUVsCia',
    'bad_moon_rising': '1EyttjAZx4NMeimIHGCeh8fdsPsUXeLYB',
    'traveller_and_fabled': '1Pj8fWN8wUdp4X1fhM6y3ja9PhFz9w5cp',
  };
  final id = documentIds[name];
  if (id == null) throw ArgumentError.value(name, 'name', 'Unknown rulebook');
  return Uri.https(
    'drive.usercontent.google.com',
    '/download',
    <String, String>{'id': id, 'export': 'download', 'confirm': 't'},
  );
}
