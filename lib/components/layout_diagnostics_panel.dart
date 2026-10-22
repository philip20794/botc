import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

/// A live, selectable snapshot for calibrating future screen-size defaults.
///
/// Viewport sizes describe the space available to Flutter; display sizes
/// describe the physical screen. In a browser these can be different.
class LayoutDiagnosticsPanel extends StatelessWidget {
  const LayoutDiagnosticsPanel({
    super.key,
    required this.settings,
    required this.previewCharacterCount,
  });

  final SettingsService settings;
  final int previewCharacterCount;

  static String _logicalSize(Size size) =>
      size.width.toStringAsFixed(1) + ' x ' +
      size.height.toStringAsFixed(1);

  static String _physicalSize(Size size) =>
      size.width.toStringAsFixed(0) + ' x ' +
      size.height.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    // MediaQuery makes the panel rebuild when the window or its scale changes.
    final media = MediaQuery.of(context);
    final view = View.of(context);
    final viewport = media.size;
    final display = view.display.size;
    final ratio = media.devicePixelRatio;
    final widthClass = viewport.width < 600
        ? 'compact (<600 dp)'
        : viewport.width < 840
            ? 'medium (600-839 dp)'
            : 'expanded (>=840 dp)';

    final snapshot = [
      'runtime=' + (kIsWeb ? 'web' : 'native'),
      'platform=' + defaultTargetPlatform.name,
      'viewportLogical=' + _logicalSize(viewport) + ' dp',
      'viewPhysical=' + _physicalSize(view.physicalSize) + ' px',
      'displayPhysical=' + _physicalSize(display) + ' px',
      'displayLogical=' + _logicalSize(display / ratio) + ' dp',
      'devicePixelRatio=' + ratio.toStringAsFixed(2),
      'orientation=' + media.orientation.name,
      'viewportWidthClass=' + widthClass,
      'shortestSide=' + viewport.shortestSide.toStringAsFixed(1) + ' dp',
      'safePaddingLTRB=' +
          [
            media.padding.left,
            media.padding.top,
            media.padding.right,
            media.padding.bottom,
          ].map((value) => value.toStringAsFixed(1)).join(',') +
          ' dp',
      '',
      'characterKnobSize=' + settings.characterKnobSize.toString(),
      'startAngleDiv=' + settings.startAngleDiv.toString(),
      'radiusX=' + settings.radiusX.toString(),
      'radiusY=' + settings.radiusY.toString(),
      'numberOfCharacters=' + previewCharacterCount.toString(),
      'tokenKnobSize=' + settings.tokenKnobSize.toString(),
      'tokenOffsetX=' + settings.tokenOffsetX.toString(),
      'tokenOffsetY=' + settings.tokenOffsetY.toString(),
      'selectedReminderTokenSize=' +
          settings.selectedReminderTokenSize.toString(),
      'unselectedReminderTokenSize=' +
          settings.unselectedReminderTokenSize.toString(),
      'offsetX=' + settings.offsetX.toString(),
      'offsetY=' + settings.offsetY.toString(),
    ].join('\n');

    return Container(
      key: const ValueKey('layout-settings-diagnostics'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: GrimoireColors.background.withValues(alpha: 0.75),
        border: Border.all(color: GrimoireColors.deepViolet),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Layout debug',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: GrimoireColors.ivory,
            ),
          ),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(
              snapshot,
              key: const ValueKey('layout-settings-diagnostics-text'),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                height: 1.35,
                color: GrimoireColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
