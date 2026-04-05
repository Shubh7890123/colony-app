import 'package:flutter/material.dart';

/// Light (current Colony) and dark (black / white, Threads-inspired) [ThemeData].
abstract final class ColonyTheme {
  static const Color _lightScaffold = Color(0xFFF2F7ED);
  static const Color _greenDark = Color(0xFF14471E);
  static const Color _greenBtn = Color(0xFF1A5822);
  static const Color _textMain = Color(0xFF2C3E30);

  static ThemeData get light {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E5631),
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lightScaffold,
      colorScheme: base.copyWith(surface: Colors.white),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: _lightScaffold,
        foregroundColor: _greenDark,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(color: Colors.white, elevation: 0),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade300),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _greenBtn,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );
  }

  static ThemeData get dark {
    const black = Color(0xFF000000);
    const surface = Color(0xFF121212);
    const surface2 = Color(0xFF1E1E1E);
    const white = Color(0xFFFFFFFF);
    const muted = Color(0xFF999999);

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: black,
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: white,
        onPrimary: black,
        surface: surface,
        onSurface: white,
        secondary: muted,
        onSecondary: white,
        tertiary: muted,
        error: Color(0xFFFF6B6B),
        onError: black,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: black,
        foregroundColor: white,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: white),
        titleTextStyle: TextStyle(
          color: white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: const CardThemeData(color: surface, elevation: 0),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(color: white, height: 1.4),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: white,
        textColor: white,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF333333)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF444444)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF444444)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: white, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: surface2,
          foregroundColor: white,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: white,
          side: const BorderSide(color: Color(0xFF666666)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: white),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface2,
        contentTextStyle: TextStyle(color: white),
      ),
      iconTheme: const IconThemeData(color: white),
    );
  }
}

/// Per-screen colors that follow light/dark (greens only in light).
@immutable
class ColonyColors {
  const ColonyColors._({
    required this.isDark,
    required this.scaffold,
    required this.card,
    required this.primaryText,
    required this.secondaryText,
    required this.accent,
    required this.pillBackground,
    required this.statBackground,
    required this.iconMuted,
    required this.divider,
    required this.rowCard,
    required this.communityBannerTop,
    required this.communityBannerBottom,
    required this.communityBodyText,
    required this.communityCtaFg,
    required this.searchBarFill,
    required this.headerBadgeBg,
    required this.categoryChipBg,
    required this.categoryChipFg,
    required this.filledButtonBg,
    required this.filledButtonFg,
    required this.secondaryButtonBg,
    required this.secondaryButtonFg,
    required this.segmentedTrack,
    required this.segmentedSelectedBg,
    required this.segmentedSelectedFg,
    required this.segmentedUnselectedFg,
    required this.fabBackground,
    required this.fabForeground,
    required this.unreadRowTint,
    required this.unreadBadgeBg,
    required this.unreadBadgeFg,
    required this.outlineButtonFg,
    required this.outlineButtonBorder,
  });

  final bool isDark;
  final Color scaffold;
  final Color card;
  final Color primaryText;
  final Color secondaryText;
  final Color accent;
  final Color pillBackground;
  final Color statBackground;
  final Color iconMuted;
  final Color divider;

  /// Nearby-people tiles (horizontal cards).
  final Color rowCard;
  final Color communityBannerTop;
  final Color communityBannerBottom;
  final Color communityBodyText;
  final Color communityCtaFg;
  final Color searchBarFill;
  final Color headerBadgeBg;
  final Color categoryChipBg;
  final Color categoryChipFg;
  final Color filledButtonBg;
  final Color filledButtonFg;
  final Color secondaryButtonBg;
  final Color secondaryButtonFg;
  final Color segmentedTrack;
  final Color segmentedSelectedBg;
  final Color segmentedSelectedFg;
  final Color segmentedUnselectedFg;
  final Color fabBackground;
  final Color fabForeground;
  final Color unreadRowTint;
  final Color unreadBadgeBg;
  final Color unreadBadgeFg;
  final Color outlineButtonFg;
  final Color outlineButtonBorder;

  factory ColonyColors.of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return const ColonyColors._(
        isDark: true,
        scaffold: Color(0xFF000000),
        card: Color(0xFF121212),
        primaryText: Color(0xFFFFFFFF),
        secondaryText: Color(0xFF999999),
        accent: Color(0xFFFFFFFF),
        pillBackground: Color(0xFF1E1E1E),
        statBackground: Color(0xFF121212),
        iconMuted: Color(0xFF888888),
        divider: Color(0xFF333333),
        rowCard: Color(0xFF1A1A1A),
        communityBannerTop: Color(0xFF1A1A1A),
        communityBannerBottom: Color(0xFF242424),
        communityBodyText: Color(0xFF999999),
        communityCtaFg: Color(0xFF000000),
        searchBarFill: Color(0xFF1E1E1E),
        headerBadgeBg: Color(0xFF2A2A2A),
        categoryChipBg: Color(0xFF333333),
        categoryChipFg: Color(0xFFE0E0E0),
        filledButtonBg: Color(0xFFFFFFFF),
        filledButtonFg: Color(0xFF000000),
        secondaryButtonBg: Color(0xFF2A2A2A),
        secondaryButtonFg: Color(0xFFFFFFFF),
        segmentedTrack: Color(0xFF1E1E1E),
        segmentedSelectedBg: Color(0xFFFFFFFF),
        segmentedSelectedFg: Color(0xFF000000),
        segmentedUnselectedFg: Color(0xFF888888),
        fabBackground: Color(0xFFFFFFFF),
        fabForeground: Color(0xFF000000),
        unreadRowTint: Color(0xFF1A1A1A),
        unreadBadgeBg: Color(0xFFFFFFFF),
        unreadBadgeFg: Color(0xFF000000),
        outlineButtonFg: Color(0xFFFFFFFF),
        outlineButtonBorder: Color(0xFF666666),
      );
    }
    return const ColonyColors._(
      isDark: false,
      scaffold: ColonyTheme._lightScaffold,
      card: Colors.white,
      primaryText: ColonyTheme._textMain,
      secondaryText: Color(0xFF757575),
      accent: ColonyTheme._greenDark,
      pillBackground: Color(0xFFE8F6E8),
      statBackground: Color(0xFFE8F6E8),
      iconMuted: Color(0xFF4A554A),
      divider: Color(0xFFE0E0E0),
      rowCard: Color(0xFFE8F2E4),
      communityBannerTop: Color(0xFF1B5A27),
      communityBannerBottom: Color(0xFF2E6B3B),
      communityBodyText: Color(0xB3FFFFFF),
      communityCtaFg: Color(0xFF1B5A27),
      searchBarFill: Colors.white,
      headerBadgeBg: Color(0xFFA3E9A5),
      categoryChipBg: Color(0xFFA3E9A5),
      categoryChipFg: Color(0xFF14471E),
      filledButtonBg: Color(0xFF1B5A27),
      filledButtonFg: Colors.white,
      secondaryButtonBg: Color(0xFFE8F6E8),
      secondaryButtonFg: Color(0xFF14471E),
      segmentedTrack: Colors.white,
      segmentedSelectedBg: Colors.white,
      segmentedSelectedFg: Color(0xFF2E6B3B),
      segmentedUnselectedFg: Color(0xFF757575),
      fabBackground: Color(0xFFA3E9A5),
      fabForeground: Color(0xFF14471E),
      unreadRowTint: Color(0xFFE6F3E6),
      unreadBadgeBg: Color(0xFF1E5631),
      unreadBadgeFg: Colors.white,
      outlineButtonFg: Color(0xFF1B5A27),
      outlineButtonBorder: Color(0xFF1B5A27),
    );
  }

  /// Category tints on group cards: neutral in dark mode, pastel in light.
  Color categoryTint(String category) {
    if (isDark) return const Color(0xFF2C2C2C);
    switch (category.toUpperCase()) {
      case 'TECH':
        return const Color(0xFF7DE6ED);
      case 'FITNESS':
        return const Color(0xFFF1B7C9);
      case 'LIFESTYLE':
        return const Color(0xFFA3E9A5);
      case 'ART':
        return const Color(0xFFE9D5A3);
      case 'MUSIC':
        return const Color(0xFFA3C4E9);
      case 'BUSINESS':
        return const Color(0xFFE9A3A3);
      default:
        return const Color(0xFFA3E9A5);
    }
  }
}
