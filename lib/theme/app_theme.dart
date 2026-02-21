import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primaryBlue = Color(0xFF1D4ED8);
  static const Color darkBlue    = Color(0xFF1D4ED8);
  static const Color lightBlue   = Color(0xFF1D4ED8);
  static const Color accentBlue  = Color(0xFF2196F3);
  static const Color white       = Color(0xFFFFFFFF);
  static const Color lightGray   = Color(0xFFF5F5F5);
  static const Color darkGray    = Color(0xFF757575);

  static ThemeData get theme {
    return ThemeData(
      primaryColor:            primaryBlue,
      scaffoldBackgroundColor: white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary:   primaryBlue,
        secondary: accentBlue,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: white,
        elevation:       2,
        centerTitle:     true,
        titleTextStyle:  TextStyle(
          color:      white,
          fontSize:   20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color:     white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side:            const BorderSide(color: primaryBlue),
          padding:         const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: lightGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(color: primaryBlue, width: 2),
        ),
        labelStyle:         const TextStyle(color: darkGray),
        floatingLabelStyle: const TextStyle(color: primaryBlue),
      ),

      // ── Popup-style dialog ─────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,

        // Compact, centred, never full-screen — feels like a popup.
        alignment: Alignment.center,

        // Tight corner radius + strong shadow so it floats above the page.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 24,

        // Dim the page behind it so focus stays on the popup.
        shadowColor: Colors.black,

        // Constrain width so it never stretches edge-to-edge on wide screens.
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 80,   // leaves visible margin on both sides
          vertical:   60,
        ),

        titleTextStyle: const TextStyle(
          color:      Color(0xFF1A1A2E),
          fontSize:   18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        contentTextStyle: TextStyle(
          color:    Colors.grey.shade700,
          fontSize: 14,
          height:   1.5,
        ),
      ),
    );
  }

  // ── Helper: show a dialog that truly feels like a popup ───────────────────
  //
  // Use this instead of showDialog() for a snappier entrance animation and
  // a lighter scrim that makes the content behind still readable.
  //
  //   AppTheme.showPopup(context, builder: (_) => MyDialog());
  //
  static Future<T?> showPopup<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context:            context,
      barrierDismissible: barrierDismissible,
      barrierLabel:       'Dismiss',
      // Lighter scrim — popup convention vs. full modal.
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => builder(context),
      transitionBuilder: (ctx, animation, _, child) {
        // Combine a subtle scale-up with a fade-in.
        final curved = CurvedAnimation(
          parent: animation,
          curve:  Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve:  Curves.easeIn,
            ),
            child: child,
          ),
        );
      },
    );
  }
}