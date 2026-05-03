import 'package:flutter/material.dart';

/// Centralized UI colors for consistent, government-grade visuals
class AppColors {
  // Status colors
  static const Color approved = Color(0xFF2E7D32); // official muted green
  static const Color pending = Color(0xFFF59E0B); // amber
  static const Color pendingGuest = Color(0xFFFBBF24); // lighter amber for guest
  static const Color rejected = Color(0xFFB91C1C); // red

  // Chart neutrals
  static const Color axisLabel = Color(0xFF9CA3AF); // neutral gray
  static const Color gridLine = Color(0xFF9CA3AF); // use with low alpha

  // Legends background (subtle or transparent as needed)
  static const Color legendBgLight = Colors.transparent;
}
