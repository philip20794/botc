import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/screens/home_screen.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/material.dart';

class NextScreenFooter extends StatelessWidget {
  const NextScreenFooter({
    super.key,
    this.nextScreen,
    required this.nextScreenName,
    required this.nextScreenIcon,
    required this.currentScreenName,
    required this.disabled,
    this.onTap,
    this.hideHomeButton,
    this.validationMessages = const [],
    this.blockNavigationWhenDisabled = false,
  });

  final Widget? nextScreen;
  final String nextScreenName;
  final IconData nextScreenIcon;
  final String currentScreenName;
  final bool disabled;
  final VoidCallback? onTap;
  final bool? hideHomeButton;
  final List<String> validationMessages;
  final bool blockNavigationWhenDisabled;

  bool get _showsHome => hideHomeButton == null || !hideHomeButton!;

  void _continue(BuildContext context) {
    onTap?.call();
    if (nextScreen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => nextScreen!));
    }
  }

  Future<void> _handleTap(BuildContext context) async {
    if (!disabled) {
      _continue(context);
      return;
    }
    final strings = AppLocalizations.of(context)!;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.wantToContinue),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.reallyContinue),
              for (final message in validationMessages)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('• $message'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          if (!blockNavigationWhenDisabled)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.yesContinue),
            ),
        ],
      ),
    );
    if (proceed == true && context.mounted) _continue(context);
  }

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: AnimatedContainer(
          duration: duration,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: GrimoireColors.background.withValues(alpha: 0.94),
            border: Border(
              top: BorderSide(
                color: GrimoireColors.antiqueGold.withValues(alpha: 0.34),
              ),
            ),
          ),
          child: Row(
            children: [
              if (_showsHome) ...[
                IconButton(
                  tooltip: 'Home',
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => HomeScreen()),
                    (route) => false,
                  ),
                  icon: const Icon(Icons.home_outlined),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  currentScreenName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: GrimoireColors.secondaryText,
                        fontSize: 13,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => _handleTap(context),
                  icon: Icon(nextScreenIcon, size: 18),
                  label: Text(
                    nextScreenName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    backgroundColor: disabled
                        ? GrimoireColors.deepViolet.withValues(alpha: 0.66)
                        : GrimoireColors.antiqueGold,
                    foregroundColor: disabled
                        ? GrimoireColors.secondaryText
                        : GrimoireColors.background,
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
