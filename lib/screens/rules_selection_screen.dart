import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/grimoire_ui.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/screens/pdf_viewer_page.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/material.dart';

class RulesSelectionScreen extends StatelessWidget {
  const RulesSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(strings.rules)),
        body: GridView.count(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.92,
          children: const [
            _RuleCard(title: 'Main Rules', name: 'main'),
            _RuleCard(title: 'Trouble Brewing', name: 'trouble_brewing'),
            _RuleCard(title: 'Sects & Violets', name: 'sects_and_violets'),
            _RuleCard(title: 'Bad Moon Rising', name: 'bad_moon_rising'),
            _RuleCard(title: 'Traveller & Fabled', name: 'traveller_and_fabled'),
          ],
        ),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.title, required this.name});

  final String title;
  final String name;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).height * 0.105;
    return GrimoirePressablePanel(
      padding: const EdgeInsets.all(10),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerPage(pdfUrl: rulePdfUriFor(name), title: title),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size * 1.4,
            height: size * 1.4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: size * 1.4,
                  height: size * 1.4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage('assets/images/backgrounds/token.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage('assets/rules/Logo_$name.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: GrimoireColors.antiqueGold,
                ),
          ),
        ],
      ),
    );
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
