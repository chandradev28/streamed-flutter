import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import 'app_colors.dart';

class LayoutThemeOption {
  const LayoutThemeOption({
    required this.id,
    required this.label,
    required this.color,
  });

  final String id;
  final String label;
  final Color color;
}

class LayoutOptions {
  const LayoutOptions._();

  static const List<LayoutThemeOption> themes = <LayoutThemeOption>[
    LayoutThemeOption(id: 'white', label: 'White', color: AppColors.text),
    LayoutThemeOption(id: 'crimson', label: 'Crimson', color: AppColors.accent),
    LayoutThemeOption(id: 'ocean', label: 'Ocean', color: Color(0xFF2D9CDB)),
    LayoutThemeOption(id: 'violet', label: 'Violet', color: Color(0xFF9C27B0)),
    LayoutThemeOption(
        id: 'emerald', label: 'Emerald', color: Color(0xFF34A853)),
    LayoutThemeOption(id: 'amber', label: 'Amber', color: Color(0xFFFF8A00)),
    LayoutThemeOption(id: 'rose', label: 'Rose', color: Color(0xFFE91E63)),
  ];

  static Color accentFor(AppSettings settings) {
    return themes
        .firstWhere(
          (LayoutThemeOption option) => option.id == settings.layoutTheme,
          orElse: () => themes.first,
        )
        .color;
  }

  static Color backgroundFor(AppSettings settings) {
    if (settings.amoledBlackEnabled) {
      return AppColors.background;
    }
    return Color.alphaBlend(
        accentFor(settings).withOpacity(0.08), AppColors.surface);
  }

  static double posterWidth(AppSettings settings) {
    switch (settings.posterWidthPreset) {
      case 'compact':
        return 108;
      case 'dense':
        return 118;
      case 'standard':
        return 126;
      case 'comfort':
        return 140;
      case 'large':
        return 154;
      case 'balanced':
      default:
        return 132;
    }
  }

  static double posterRadius(AppSettings settings) {
    switch (settings.posterRadiusPreset) {
      case 'sharp':
        return 4;
      case 'subtle':
        return 8;
      case 'classic':
        return 12;
      case 'pill':
        return 28;
      case 'rounded':
      default:
        return 18;
    }
  }

  static String posterWidthLabel(String preset) {
    switch (preset) {
      case 'compact':
        return 'Compact';
      case 'dense':
        return 'Dense';
      case 'standard':
        return 'Standard';
      case 'comfort':
        return 'Comfort';
      case 'large':
        return 'Large';
      case 'balanced':
      default:
        return 'Balanced';
    }
  }

  static String posterRadiusLabel(String preset) {
    switch (preset) {
      case 'sharp':
        return 'Sharp';
      case 'subtle':
        return 'Subtle';
      case 'classic':
        return 'Classic';
      case 'pill':
        return 'Pill';
      case 'rounded':
      default:
        return 'Rounded';
    }
  }
}
