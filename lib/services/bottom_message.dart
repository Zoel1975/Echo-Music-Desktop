import 'package:flutter/material.dart';

import '../themes/text_styles.dart';

class BottomMessage {
  /// Shows the app's toast/snackbar from a page context.
  static void showText(
    BuildContext context,
    String text, {
    Duration duration = const Duration(milliseconds: 2500),
    SnackBarAction? action,
  }) {
    showOn(ScaffoldMessenger.of(context), text,
        duration: duration, action: action);
  }

  /// Shows the toast on an already-resolved [ScaffoldMessengerState]. Needed by
  /// services that outlive the widget that started the work (downloads,
  /// exports): after the popup is dismissed there is no usable page context.
  ///
  /// The foreground colour is derived from the background luminance: the old
  /// implementation used the theme's scaffold background as the text colour.
  /// On Windows that colour is `Colors.transparent`, so every toast rendered
  /// as an empty coloured bar with invisible text (e.g. "Download started..."
  /// or the MP3 export confirmation looked like a blank message).
  static void showOn(
    ScaffoldMessengerState messenger,
    String text, {
    Duration duration = const Duration(milliseconds: 2500),
    SnackBarAction? action,
  }) {
    final context = messenger.context;
    final background = Theme.of(context).colorScheme.primary.withOpacity(0.95);
    final foreground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: smallTextStyle(context, bold: false, opacity: 0.95)
              .copyWith(color: foreground),
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: background,
        action: action == null
            ? null
            : SnackBarAction(
                label: action.label,
                textColor: foreground,
                onPressed: action.onPressed,
              ),
      ),
    );
  }
}
