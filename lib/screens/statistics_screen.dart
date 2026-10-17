import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/grimoire_ui.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/material.dart';

/// Entry point for the public game statistics. The read-only statistics
/// dashboard can be added here without changing the Home navigation.
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(strings.statistics),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: GrimoireBackgroundVeil()),
            ListView(
              key: const ValueKey('statisticsContent'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                GrimoirePanel(
                  emphasized: true,
                  child: Column(
                    children: [
                      const Icon(
                        Icons.bar_chart_rounded,
                        color: GrimoireColors.antiqueGold,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        strings.statisticsPlaceholder,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: GrimoireColors.secondaryText,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
