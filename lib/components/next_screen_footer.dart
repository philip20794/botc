import 'package:auto_size_text/auto_size_text.dart';
import 'package:blood_on_the_clocktower/screens/home_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class NextScreenFooter extends StatefulWidget {
  final Widget? nextScreen;
  final String nextScreenName;
  final IconData nextScreenIcon;
  final String currentScreenName;
  final bool disabled;
  final Function? onTap;
  final bool? hideHomeButton;

  const NextScreenFooter({
    this.nextScreen,
    required this.nextScreenName,
    required this.nextScreenIcon,
    required this.currentScreenName,
    required this.disabled,
    this.onTap,
    this.hideHomeButton,
  });

  @override
  _NextScreenFooterState createState() => _NextScreenFooterState();
}

class _NextScreenFooterState extends State<NextScreenFooter> {
  @override
  Widget build(BuildContext context) {
    var maxWidth = MediaQuery.of(context).size.width;
    return Positioned(
      bottom: 0,
      child: Container(
        color: const Color(0xFF6f678a).withOpacity(0.8),
        width: maxWidth,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Back to HomeScreen
            if (widget.hideHomeButton == null || !widget.hideHomeButton!) ...[
              IconButton(
                  onPressed: () => {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => HomeScreen()),
                          (Route<dynamic> route) => false,
                        )
                      },
                  icon: const Icon(Icons.home, color: Colors.white)),
            ],
            Row(
              children: [
                SizedBox(
                  width: maxWidth * 0.2,
                  child: AutoSizeText(
                    widget.currentScreenName,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    minFontSize: 4,
                  ),
                ),
                SizedBox(width: 10),
                Icon(Icons.arrow_forward,
                    color: widget.disabled ? Colors.grey : Colors.white),
                CupertinoButton(
                  onPressed: () {
                    if (widget.disabled) {
                      _showConfirmDialog(context);
                      return;
                    }
                    if (widget.onTap != null) {
                      widget.onTap!();
                    }
                    if (widget.nextScreen != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => widget.nextScreen!),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      color: Color(0xFF4a3b5e)
                          .withOpacity(widget.disabled ? 0.4 : 0.8),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 4),
                        Icon(widget.nextScreenIcon,
                            color:
                                widget.disabled ? Colors.grey : Colors.white),
                        SizedBox(width: 10),
                        SizedBox(
                          width: maxWidth * 0.3,
                          child: AutoSizeText(widget.nextScreenName,
                              style: TextStyle(
                                  color: widget.disabled
                                      ? Colors.grey
                                      : Colors.white),
                              maxLines: 1,
                              minFontSize: 4),
                        ),
                        SizedBox(width: 10),
                      ],
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _showConfirmDialog(BuildContext context) async {
    var localizedStrings = AppLocalizations.of(context)!;
    return showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF4a3b5e).withOpacity(0.9),
          title: Text(localizedStrings.wantToContinue,
              style: TextStyle(color: Colors.white)),
          content: Text(localizedStrings.reallyContinue,
              style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(localizedStrings.cancel,
                  style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (widget.onTap != null) {
                  widget.onTap!();
                }
                if (widget.nextScreen != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => widget.nextScreen!),
                  );
                }
              },
              child: Text(localizedStrings.yesContinue,
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
