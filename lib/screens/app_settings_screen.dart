import 'package:blood_on_the_clocktower/components/select_language.dart';
import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/grimoire_ui.dart';
import 'package:blood_on_the_clocktower/screens/role_notes_screen.dart';
import 'package:blood_on_the_clocktower/screens/rules_selection_screen.dart';
import 'package:blood_on_the_clocktower/screens/settings_character_circle.dart';
import 'package:flutter/material.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

import '../custom_icons.dart';
import '../theme/grimoire_theme.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({Key? key}) : super(key: key);

  _AppSettingsScreenState createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  void downloadApkForWeb() {
    try {
      if (kIsWeb) {
        const String apkUrl =
            'https://github.com/philip20794/botc/releases/download/android-latest/b-o-t-c.apk';
        html.AnchorElement(href: apkUrl)
          ..setAttribute("download", "b-o-t-c.apk")
          ..click();
      }
    } catch (e) {
      print('Fehler beim Bereitstellen der APK-Datei zum Download: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    var localizedStrings = AppLocalizations.of(context)!;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(localizedStrings.settings,
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            GrimoirePanel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.language, color: Colors.white),
                title: Text(localizedStrings.language,
                    style: TextStyle(color: Colors.white)),
                trailing: const SelectLanguage(),
              ),
            ),
            _buildCard(localizedStrings.layoutSettings, Icons.video_settings,
                SettingsCharacterCircle(), null, false),
            _buildCard(localizedStrings.roleNotes, Icons.manage_search,
                const RoleNotesScreen(), null, false),
            _buildCard(localizedStrings.rules, CustomIcons.law,
                RulesSelectionScreen(), null, false),
            _buildCard(localizedStrings.downloadAndroidApp, Icons.download,
                null, () => downloadApkForWeb(), !kIsWeb)
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, var icon, Widget? onTap, Function? function,
      bool disabled) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GrimoirePressablePanel(
        enabled: !disabled,
        onTap: disabled
            ? null
            : () {
          if (disabled) {
            return;
          }
          if (function != null) {
            function();
          }
          if (onTap != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => onTap),
            );
          }
        },
        child: Row(
          children: [
            Icon(icon,
                color: disabled
                    ? GrimoireColors.disabled
                    : GrimoireColors.antiqueGold),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: disabled
                          ? GrimoireColors.disabled
                          : GrimoireColors.ivory,
                    ),
              ),
            ),
            Icon(Icons.chevron_right,
                color: disabled
                    ? GrimoireColors.disabled
                    : GrimoireColors.secondaryText),
          ],
        ),
      ),
    );
  }
}
