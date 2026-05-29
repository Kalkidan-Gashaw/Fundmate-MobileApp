import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF1A2980);
  static const primaryLight = Color(0xFF2E4BB8);
  static const accent = Color(0xFF26D0CE);
  static const accentSoft = Color(0xFF5CE4E2);

  static const gradientStart = Color(0xFF1A2980);
  static const gradientEnd = Color(0xFF26D0CE);

  static const darkGradientStart = Color(0xFF0C1228);
  static const darkGradientEnd = Color(0xFF145C5A);

  static const lightScaffold = Color(0xFFF0F4FA);
  static const darkScaffold = Color(0xFF0A0E18);

  static const lightSurface = Color(0xFFFFFFFF);
  static const darkSurface = Color(0xFF121A2E);

  static const lightText = Color(0xFF1E293B);
  static const darkText = Color(0xFFE8EDF5);

  static const lightTextMuted = Color(0xFF64748B);
  static const darkTextMuted = Color(0xFF8B9BB5);
}

@immutable
class FundMateColors extends ThemeExtension<FundMateColors> {
  const FundMateColors({
    required this.card,
    required this.cardBorder,
    required this.mutedText,
    required this.unreadTint,
    required this.inputFill,
    required this.surfaceElevated,
    required this.authCard,
    required this.authFieldFill,
    required this.chipSelected,
    required this.chipUnselected,
    required this.chipBorder,
    required this.avatarBg,
    required this.link,
    required this.gradientStart,
    required this.gradientEnd,
    required this.badgeBg,
    required this.badgeText,
    required this.shadow,
    required this.chatOutgoing,
    required this.chatOutgoingText,
  });

  final Color card;
  final Color cardBorder;
  final Color mutedText;
  final Color unreadTint;
  final Color inputFill;
  final Color surfaceElevated;
  final Color authCard;
  final Color authFieldFill;
  final Color chipSelected;
  final Color chipUnselected;
  final Color chipBorder;
  final Color avatarBg;
  final Color link;
  final Color gradientStart;
  final Color gradientEnd;
  final Color badgeBg;
  final Color badgeText;
  final Color shadow;
  final Color chatOutgoing;
  final Color chatOutgoingText;

  static const light = FundMateColors(
    card: Colors.white,
    cardBorder: Color(0xFFE2E8F0),
    mutedText: Color(0xFF64748B),
    unreadTint: Color(0x1426D0CE),
    inputFill: Color(0xFFF1F5F9),
    surfaceElevated: Color(0xFFF8FAFC),
    authCard: Colors.white,
    authFieldFill: Color(0xFFF1F5F9),
    chipSelected: AppColors.primary,
    chipUnselected: Color(0xFFF1F5F9),
    chipBorder: Color(0xFFCBD5E1),
    avatarBg: Color(0x1A1A2980),
    link: AppColors.primary,
    gradientStart: AppColors.gradientStart,
    gradientEnd: AppColors.gradientEnd,
    badgeBg: Color(0x1A26D0CE),
    badgeText: AppColors.primary,
    shadow: Color(0x1A000000),
    chatOutgoing: AppColors.primary,
    chatOutgoingText: Colors.white,
  );

  static const dark = FundMateColors(
    card: Color(0xFF161F33),
    cardBorder: Color(0xFF2A354D),
    mutedText: Color(0xFF8B9BB5),
    unreadTint: Color(0x3326D0CE),
    inputFill: Color(0xFF0F1524),
    surfaceElevated: Color(0xFF1C2740),
    authCard: Color(0xF0161F33),
    authFieldFill: Color(0xFF0F1524),
    chipSelected: AppColors.accent,
    chipUnselected: Color(0xFF1A2438),
    chipBorder: Color(0xFF3D4D6A),
    avatarBg: Color(0x3326D0CE),
    link: AppColors.accentSoft,
    gradientStart: AppColors.darkGradientStart,
    gradientEnd: AppColors.darkGradientEnd,
    badgeBg: Color(0x4026D0CE),
    badgeText: AppColors.accentSoft,
    shadow: Color(0x66000000),
    chatOutgoing: Color(0xFF2A4478),
    chatOutgoingText: Color(0xFFE8EDF5),
  );

  bool get isDark => card != light.card;

  @override
  FundMateColors copyWith({
    Color? card,
    Color? cardBorder,
    Color? mutedText,
    Color? unreadTint,
    Color? inputFill,
    Color? surfaceElevated,
    Color? authCard,
    Color? authFieldFill,
    Color? chipSelected,
    Color? chipUnselected,
    Color? chipBorder,
    Color? avatarBg,
    Color? link,
    Color? gradientStart,
    Color? gradientEnd,
    Color? badgeBg,
    Color? badgeText,
    Color? shadow,
    Color? chatOutgoing,
    Color? chatOutgoingText,
  }) {
    return FundMateColors(
      card: card ?? this.card,
      cardBorder: cardBorder ?? this.cardBorder,
      mutedText: mutedText ?? this.mutedText,
      unreadTint: unreadTint ?? this.unreadTint,
      inputFill: inputFill ?? this.inputFill,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      authCard: authCard ?? this.authCard,
      authFieldFill: authFieldFill ?? this.authFieldFill,
      chipSelected: chipSelected ?? this.chipSelected,
      chipUnselected: chipUnselected ?? this.chipUnselected,
      chipBorder: chipBorder ?? this.chipBorder,
      avatarBg: avatarBg ?? this.avatarBg,
      link: link ?? this.link,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      badgeBg: badgeBg ?? this.badgeBg,
      badgeText: badgeText ?? this.badgeText,
      shadow: shadow ?? this.shadow,
      chatOutgoing: chatOutgoing ?? this.chatOutgoing,
      chatOutgoingText: chatOutgoingText ?? this.chatOutgoingText,
    );
  }

  @override
  FundMateColors lerp(ThemeExtension<FundMateColors>? other, double t) {
    if (other is! FundMateColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return FundMateColors(
      card: l(card, other.card),
      cardBorder: l(cardBorder, other.cardBorder),
      mutedText: l(mutedText, other.mutedText),
      unreadTint: l(unreadTint, other.unreadTint),
      inputFill: l(inputFill, other.inputFill),
      surfaceElevated: l(surfaceElevated, other.surfaceElevated),
      authCard: l(authCard, other.authCard),
      authFieldFill: l(authFieldFill, other.authFieldFill),
      chipSelected: l(chipSelected, other.chipSelected),
      chipUnselected: l(chipUnselected, other.chipUnselected),
      chipBorder: l(chipBorder, other.chipBorder),
      avatarBg: l(avatarBg, other.avatarBg),
      link: l(link, other.link),
      gradientStart: l(gradientStart, other.gradientStart),
      gradientEnd: l(gradientEnd, other.gradientEnd),
      badgeBg: l(badgeBg, other.badgeBg),
      badgeText: l(badgeText, other.badgeText),
      shadow: l(shadow, other.shadow),
      chatOutgoing: l(chatOutgoing, other.chatOutgoing),
      chatOutgoingText: l(chatOutgoingText, other.chatOutgoingText),
    );
  }
}

extension FundMateColorsContext on BuildContext {
  FundMateColors get fundMate =>
      Theme.of(this).extension<FundMateColors>() ?? FundMateColors.light;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
