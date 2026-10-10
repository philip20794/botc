import 'package:blood_on_the_clocktower/components/select_language.dart';
import 'package:blood_on_the_clocktower/screens/auth_screen.dart';
import 'package:blood_on_the_clocktower/screens/rules_selection_screen.dart';
import 'package:blood_on_the_clocktower/screens/settings_character_circle.dart';
import 'package:blood_on_the_clocktower/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

import '../custom_icons.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({Key? key}) : super(key: key);

  _AppSettingsScreenState createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  void downloadApkForWeb() {
    try {
      if (kIsWeb) {
        const String apkUrl =
            'https://drive.google.com/uc?export=download&id=1Hy4T-RO2ysOhKlZZS2KMVEGG0goFBuK3';
        final html.AnchorElement anchor = html.AnchorElement(href: apkUrl)
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
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    return Scaffold(
      backgroundColor: const Color(0xFFc9f2f8),
      appBar: AppBar(
        title: Text(localizedStrings.settings,
            style: TextStyle(color: Colors.white)),
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
                    'assets/images/backgrounds/background_grim_middel.jpg'), // Path to your background image
                fit: BoxFit
                    .cover, // Ensures the image covers the entire background
              ),
            ),
          ),
          ListView(
            children: [
              Card(
                color: const Color(0xFF6f678a).withOpacity(0.9),
                margin:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: ListTile(
                  leading: const Icon(Icons.language, color: Colors.white),
                  title: Text(localizedStrings.language,
                      style: TextStyle(color: Colors.white)),
                  trailing: const SelectLanguage(),
                ),
              ),
              _buildCard(localizedStrings.layoutSettings, Icons.video_settings,
                  SettingsCharacterCircle(), null, false),
              _buildCard(localizedStrings.rules, CustomIcons.law,
                  RulesSelectionScreen(), null, false),
              if (user != null) ...[
                _buildCard(localizedStrings.logout, Icons.logout, null,
                    () => authService.signOut(), false),
              ] else ...[
                _buildCard(localizedStrings.login, Icons.login,
                    const AuthScreen(), null, false),
              ],
              _buildCard(localizedStrings.downloadAndroidApp, Icons.download,
                  null, () => downloadApkForWeb(), !kIsWeb)
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, var icon, Widget? onTap, Function? function,
      bool disabled) {
    return Card(
      color: Color(0xFF6f678a).withOpacity(disabled ? 0.5 : 0.9),
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: ListTile(
        leading: Icon(icon, color: disabled ? Colors.grey : Colors.white),
        title: Center(
            child: Text(title,
                style:
                    TextStyle(color: disabled ? Colors.grey : Colors.white))),
        onTap: () {
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
      ),
    );
  }
}
