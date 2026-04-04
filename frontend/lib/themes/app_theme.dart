import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta de colores cálida terrosa para TaskBoard Personal
class AppColors {
  // Fondos
  static const Color backgroundPrimary = Color(0xFFFDF6E3);   // Crema Suave
  static const Color backgroundSecondary = Color(0xFFF5E6D3); // Beige Claro
  static const Color backgroundDark = Color(0xFF3D2914);      // Marrón Café
  
  // Textos
  static const Color textPrimary = Color(0xFF2C1810);         // Marrón Oscuro
  static const Color textSecondary = Color(0xFF6B4423);       // Marrón Medio
  static const Color textOnDark = Color(0xFFFDF6E3);          // Crema para fondos oscuros
  
  // Acentos
  static const Color accentPrimary = Color(0xFFC45C26);       // Terracota
  static const Color accentSecondary = Color(0xFFD4763B);     // Naranja Quemado
  
  // Estados
  static const Color success = Color(0xFF6B8E23);             // Verde Oliva
  static const Color warning = Color(0xFFDAA520);             // Mostaza
  static const Color error = Color(0xFFA0522D);               // Rojo Teja
  
  // Estados Kanban - Fondos
  static const Color kanbanPendingBg = Color(0xFFF5E6D3);     // Beige
  static const Color kanbanInProgressBg = Color(0xFFFFE4C4);  // Bisque
  static const Color kanbanCompletedBg = Color(0xFFE8F5E9);   // Verde claro
  
  // Estados Kanban - Bordes
  static const Color kanbanPendingBorder = Color(0xFFDAA520); // Mostaza
  static const Color kanbanInProgressBorder = Color(0xFFC45C26); // Terracota
  static const Color kanbanCompletedBorder = Color(0xFF6B8E23);  // Verde Oliva
}

/// Clase de ayuda para obtener colores según el estado de la tarea
class KanbanColors {
  static Color getBackgroundColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.kanbanPendingBg;
      case 'in_progress':
        return AppColors.kanbanInProgressBg;
      case 'completed':
        return AppColors.kanbanCompletedBg;
      default:
        return AppColors.backgroundSecondary;
    }
  }
  
  static Color getBorderColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.kanbanPendingBorder;
      case 'in_progress':
        return AppColors.kanbanInProgressBorder;
      case 'completed':
        return AppColors.kanbanCompletedBorder;
      default:
        return AppColors.textSecondary;
    }
  }
  
  static Color getHeaderColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'in_progress':
        return AppColors.accentPrimary;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }
}

/// Tema principal de la aplicación
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Esquema de colores
      colorScheme: const ColorScheme.light(
        primary: AppColors.accentPrimary,
        onPrimary: AppColors.textOnDark,
        primaryContainer: AppColors.accentSecondary,
        onPrimaryContainer: AppColors.textOnDark,
        secondary: AppColors.backgroundDark,
        onSecondary: AppColors.textOnDark,
        secondaryContainer: AppColors.backgroundSecondary,
        onSecondaryContainer: AppColors.textPrimary,
        surface: AppColors.backgroundPrimary,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.backgroundSecondary,
        error: AppColors.error,
        onError: AppColors.textOnDark,
      ),
      
      // Fondo general
      scaffoldBackgroundColor: AppColors.backgroundPrimary,
      
      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textOnDark,
        ),
        iconTheme: const IconThemeData(color: AppColors.textOnDark),
      ),
      
      // Tipografía
      textTheme: TextTheme(
        // Títulos con Playfair Display
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        displaySmall: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        headlineLarge: GoogleFonts.playfairDisplay(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        headlineSmall: GoogleFonts.playfairDisplay(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        // Cuerpo con Source Sans Pro
        titleLarge: GoogleFonts.sourceSans3(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: GoogleFonts.sourceSans3(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleSmall: GoogleFonts.sourceSans3(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.sourceSans3(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.sourceSans3(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondary,
        ),
        bodySmall: GoogleFonts.sourceSans3(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondary,
        ),
        labelLarge: GoogleFonts.sourceSans3(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        labelMedium: GoogleFonts.sourceSans3(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        labelSmall: GoogleFonts.sourceSans3(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
      
      // Cards
      cardTheme: CardThemeData(
        color: AppColors.backgroundSecondary,
        elevation: 2,
        shadowColor: AppColors.textPrimary.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(8),
      ),
      
      // Botones elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: AppColors.textOnDark,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.sourceSans3(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Botones de texto
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentPrimary,
          textStyle: GoogleFonts.sourceSans3(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Botones outlined
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentPrimary,
          side: const BorderSide(color: AppColors.accentPrimary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.sourceSans3(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentPrimary,
        foregroundColor: AppColors.textOnDark,
        elevation: 4,
        shape: CircleBorder(),
      ),
      
      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.textSecondary, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.5), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accentPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: GoogleFonts.sourceSans3(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        hintStyle: GoogleFonts.sourceSans3(
          color: AppColors.textSecondary.withValues(alpha: 0.7),
          fontSize: 14,
        ),
      ),
      
      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.backgroundSecondary,
        labelStyle: GoogleFonts.sourceSans3(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      
      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: GoogleFonts.sourceSans3(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),
      
      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.backgroundDark,
        contentTextStyle: GoogleFonts.sourceSans3(
          fontSize: 14,
          color: AppColors.textOnDark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: AppColors.textSecondary.withValues(alpha: 0.2),
        thickness: 1,
        space: 16,
      ),
      
      // ListTile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleTextStyle: GoogleFonts.sourceSans3(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        subtitleTextStyle: GoogleFonts.sourceSans3(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      // Icon theme
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: 24,
      ),
      
      // Progress indicators
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accentPrimary,
        linearTrackColor: AppColors.backgroundSecondary,
        circularTrackColor: AppColors.backgroundSecondary,
      ),
    );
  }
}
