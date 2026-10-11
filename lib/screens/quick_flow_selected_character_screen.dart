import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:flutter/material.dart';

/// A player-safe handoff after choosing a QuickFlow character token.
class QuickFlowSelectedCharacterScreen extends StatelessWidget {
  final Character character;

  const QuickFlowSelectedCharacterScreen({super.key, required this.character});

  void _returnToSelection(BuildContext context, bool approved) {
    Navigator.of(context).pop(approved);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _returnToSelection(context, false);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => _returnToSelection(context, false),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: CharacterAvatar(
                    character: character,
                    showIsSelected: false,
                    showName: true,
                    size: 240,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const ValueKey('quick-flow-character-continue'),
                    onPressed: () async {
                      final approved = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title:
                                  Text(strings.onlyTheStorytellerMayContinue),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: Text(strings.cancel),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: Text(strings.iAmTheStoryteller),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (approved && context.mounted) {
                        _returnToSelection(context, true);
                      }
                    },
                    child: Text(strings.continueText),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
