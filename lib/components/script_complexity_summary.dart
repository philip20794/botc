import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ScriptComplexitySummary extends StatelessWidget {
  const ScriptComplexitySummary({super.key, this.scriptId, this.iconSize = 24});

  final String? scriptId;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scripts = context.watch<ScriptService>();
    final id = scriptId ?? scripts.selectedScriptId;
    final storyteller = scripts.storytellerComplexityFor(id);
    final player = scripts.playerComplexityFor(id);
    if (storyteller == null && player == null) return const SizedBox.shrink();
    final strings = AppLocalizations.of(context)!;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 2,
      children: [
        if (storyteller != null)
          _ComplexityValue(
            key: const ValueKey('storytellerComplexityBadge'),
            asset: 'assets/ui/script_meta/storyteller_complexity.png',
            label: strings.storytellerComplexity,
            value: storyteller,
            iconSize: iconSize,
          ),
        if (player != null)
          _ComplexityValue(
            key: const ValueKey('playerComplexityBadge'),
            asset: 'assets/ui/script_meta/player_complexity.png',
            label: strings.playerComplexity,
            value: player,
            iconSize: iconSize,
          ),
      ],
    );
  }
}

class _ComplexityValue extends StatelessWidget {
  const _ComplexityValue({
    super.key,
    required this.asset,
    required this.label,
    required this.value,
    required this.iconSize,
  });

  final String asset;
  final String label;
  final double value;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final valueText = value % 1 == 0
        ? value.toInt().toString()
        : value.toStringAsFixed(1).replaceAll(
              '.',
              Localizations.localeOf(context).languageCode == 'de' ? ',' : '.',
            );
    return Tooltip(
      message: label,
      child: Semantics(
        label: '$label: $valueText/5',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(asset, width: iconSize, height: iconSize),
            const SizedBox(width: 5),
            Text(
              '$valueText/5',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared editor used wherever locally stored script complexities are entered.
class ScriptComplexityEditorField extends StatelessWidget {
  const ScriptComplexityEditorField({
    super.key,
    required this.asset,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String asset;
  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final isRated = value != null;
    final displayValue = value ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset(asset, width: 24, height: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  Text(
                    isRated
                        ? '${displayValue.toStringAsFixed(1)}/5'
                        : strings.notRated,
                    style: TextStyle(
                      color: isRated ? Colors.white : Colors.white70,
                      fontSize: 17,
                      fontWeight: isRated ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (isRated)
              TextButton(
                onPressed: () => onChanged(null),
                child: Text(strings.notRated),
              ),
          ],
        ),
        Slider(
          value: displayValue,
          min: 0,
          max: 5,
          divisions: 10,
          label: displayValue.toStringAsFixed(1),
          onChangeStart: (newValue) {
            if (!isRated) onChanged(newValue);
          },
          onChanged: onChanged,
        ),
      ],
    );
  }
}

ThemeData withScriptComplexityEditorTheme(ThemeData base) {
  return base.copyWith(
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: Colors.white,
      inactiveTrackColor: Colors.white38,
      thumbColor: const Color(0xFFc9f2f8),
      overlayColor: Colors.white24,
      activeTickMarkColor: const Color(0xFF4a3b5e),
      inactiveTickMarkColor: Colors.white70,
    ),
  );
}
