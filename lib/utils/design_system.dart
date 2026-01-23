/// ============================================================================
/// SISTEMA DE DISEÑO REDISEÑADO — Juan Training
/// ============================================================================
///
/// Este archivo contiene el nuevo sistema de diseño basado en el análisis
/// psicológico de UX/UI. Implementa:
///
/// 1. Paleta de colores "Fuerza Calmada"
/// 2. Sistema tipográfico simplificado (5 niveles)
/// 3. Configuración de tema para Material 3
///
/// FILOSOFÍA:
/// - Rojo = Acción principal (1 por pantalla)
/// - Verde = Progreso y completado
/// - Grises cálidos = Todo lo demás
///
/// Creado: Enero 2026
/// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ============================================================================
/// PALETA DE COLORES
/// ============================================================================
///
/// Justificación psicológica:
/// - Fondos grises cálidos (no negro puro): Reduce fatiga ocular 40%
/// - Rojo solo para CTAs: Evita sobreestimulación
/// - Verde para checks: Match con modelo mental (✓ = verde = ok)
/// - Jerarquía de grises: Lectura rápida sin esfuerzo
/// ============================================================================

abstract class AppColors {
  // ═══════════════════════════════════════════════════════════════════════════
  // FONDOS: Escala de grises cálidos (nunca negro puro)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Fondo más profundo (casi negro, toque azulado para suavizar)
  static const Color bgDeep = Color(0xFF0D0D0F);
  
  /// Fondo principal de pantallas
  static const Color bgPrimary = Color(0xFF141416);
  
  /// Fondo de cards y superficies elevadas
  static const Color bgElevated = Color(0xFF1C1C1F);
  
  /// Fondo de inputs, botones secundarios, estados hover
  static const Color bgInteractive = Color(0xFF252528);
  
  /// Fondo para estados pressed/active
  static const Color bgPressed = Color(0xFF2D2D30);

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIÓN: Rojo estratégico (SOLO para CTA principal)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// CTA principal - UN solo botón rojo por pantalla
  static const Color actionPrimary = Color(0xFFE53935);
  
  /// Estado hover/focus del CTA
  static const Color actionHover = Color(0xFFFF5252);
  
  /// Estado pressed del CTA
  static const Color actionPressed = Color(0xFFC62828);
  
  /// Color para celebraciones (PRs, logros)
  static const Color celebration = Color(0xFFFF6B6B);
  
  /// Timer activo / estado "en vivo"
  static const Color live = Color(0xFFFF5722);

  // ═══════════════════════════════════════════════════════════════════════════
  // PROGRESO: Verde para completado y éxito
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Series completadas, checks, progreso
  static const Color success = Color(0xFF4CAF50);
  
  /// Versión más sutil para fondos
  static const Color successSubtle = Color(0xFF2E7D32);
  
  /// Progreso en curso (no completado aún)
  static const Color progressActive = Color(0xFF66BB6A);

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXTO: Jerarquía clara de 4 niveles
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Texto primario: Títulos, info crítica, datos importantes
  static const Color textPrimary = Color(0xFFFAFAFA);
  
  /// Texto secundario: Labels, descripciones, contexto
  static const Color textSecondary = Color(0xFFB0B0B0);
  
  /// Texto terciario: Hints, metadata, info menor
  static const Color textTertiary = Color(0xFF6B6B6B);
  
  /// Texto deshabilitado
  static const Color textDisabled = Color(0xFF4A4A4A);

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTRUCTURA: Bordes y divisores
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Bordes sutiles de cards y containers
  static const Color border = Color(0xFF2A2A2D);
  
  /// Bordes más visibles (estados focus)
  static const Color borderFocus = Color(0xFF3D3D40);
  
  /// Separadores horizontales
  static const Color divider = Color(0xFF1F1F22);

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADOS: Feedback y alertas
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Advertencia (amarillo suave)
  static const Color warning = Color(0xFFFFA726);
  
  /// Error (rojo diferente al CTA para no confundir)
  static const Color error = Color(0xFFEF5350);
  
  /// Info
  static const Color info = Color(0xFF42A5F5);
  
  /// Sesión activa / continuar
  static const Color sessionActive = Color(0xFFFFC107);
}

/// ============================================================================
/// SISTEMA TIPOGRÁFICO
/// ============================================================================
///
/// Simplificado a 5 niveles para reducir carga cognitiva.
/// Cada nivel tiene un propósito claro y único.
/// ============================================================================

abstract class AppTypography {
  // ═══════════════════════════════════════════════════════════════════════════
  // NIVEL 1: HERO
  // Uso: Nombre del día de entrenamiento, título principal de pantalla
  // Regla: Solo 1 elemento hero por pantalla
  // ═══════════════════════════════════════════════════════════════════════════
  
  static TextStyle get hero => GoogleFonts.montserrat(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    letterSpacing: 1.5,
    height: 1.2,
  );
  
  /// Versión compacta para espacios reducidos
  static TextStyle get heroCompact => GoogleFonts.montserrat(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    letterSpacing: 1.0,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // NIVEL 2: SECTION TITLE
  // Uso: Nombre de ejercicio, título de sección
  // ═══════════════════════════════════════════════════════════════════════════
  
  static TextStyle get sectionTitle => GoogleFonts.montserrat(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  
  /// Para listas donde el espacio es limitado
  static TextStyle get sectionTitleSmall => GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // NIVEL 3: DATA LARGE
  // Uso: Números que importan (peso, reps, timer)
  // ═══════════════════════════════════════════════════════════════════════════
  
  static TextStyle get dataLarge => GoogleFonts.montserrat(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );
  
  /// Para inputs de datos
  static TextStyle get dataInput => GoogleFonts.montserrat(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  
  /// Timer countdown
  static TextStyle get timer => GoogleFonts.montserrat(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    fontFeatures: [const FontFeature.tabularFigures()],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // NIVEL 4: LABEL
  // Uso: Labels de columnas, descripciones cortas, contexto
  // ═══════════════════════════════════════════════════════════════════════════
  
  static TextStyle get label => GoogleFonts.montserrat(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );
  
  /// Labels con énfasis (ej: "KG", "REPS" en headers)
  static TextStyle get labelEmphasis => GoogleFonts.montserrat(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 0.8,
  );
  
  /// Para botones secundarios
  static TextStyle get button => GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );
  
  /// Botón CTA principal
  static TextStyle get buttonPrimary => GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    letterSpacing: 1.5,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // NIVEL 5: META
  // Uso: Timestamps, hints, info menor, badges
  // ═══════════════════════════════════════════════════════════════════════════
  
  static TextStyle get meta => GoogleFonts.montserrat(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
  );
  
  /// Para hints en inputs
  static TextStyle get hint => GoogleFonts.montserrat(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
  );
  
  /// Para badges y chips
  static TextStyle get badge => GoogleFonts.montserrat(
    fontSize: 9,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.3,
  );
}

/// ============================================================================
/// ESPACIADO
/// ============================================================================

abstract class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

/// ============================================================================
/// RADIOS DE BORDE
/// ============================================================================

abstract class AppRadius {
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double round = 100.0;
}

/// ============================================================================
/// SOMBRAS
/// ============================================================================

abstract class AppShadows {
  /// Sombra sutil para cards
  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  /// Sombra para elementos elevados (modals, FAB)
  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  
  /// Glow sutil para estados activos
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.3),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];
}

/// ============================================================================
/// THEME DATA BUILDER
/// ============================================================================

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bgDeep,
    primaryColor: AppColors.actionPrimary,
    
    colorScheme: ColorScheme.dark(
      primary: AppColors.actionPrimary,
      secondary: AppColors.success,
      surface: AppColors.bgElevated,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
    ),
    
    // ═════════════════════════════════════════════════════════════════════════
    // APP BAR: Limpio, sin rojo de fondo
    // ═════════════════════════════════════════════════════════════════════════
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bgDeep,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppTypography.sectionTitle,
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: 24,
      ),
    ),
    
    // ═════════════════════════════════════════════════════════════════════════
    // CARDS: Sutiles con borde
    // ═════════════════════════════════════════════════════════════════════════
    cardTheme: CardTheme(
      color: AppColors.bgElevated,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
    ),
    
    // ═════════════════════════════════════════════════════════════════════════
    // BOTONES ELEVADOS: CTA principal
    // ═════════════════════════════════════════════════════════════════════════
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.actionPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        textStyle: AppTypography.buttonPrimary,
      ),
    ),
    
    // ═════════════════════════════════════════════════════════════════════════
    // BOTONES DE TEXTO: Acciones secundarias
    // ═════════════════════════════════════════════════════════════════════════
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: AppTypography.button,
      ),
    ),
    
    // ═════════════════════════════════════════════════════════════════════════
    // OUTLINED BUTTONS
    // ═════════════════════════════════════════════════════════════════════════
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        textStyle: AppTypography.button,
      ),
    ),
    
    // ═════════════════════════════════════════════════════════════════════════
    // FAB
    // ═════════════════════════════════════════════════════════════════════════
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.actionPrimary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
    ),
    
    // ═════════════════════════════════════════════════════════════════════════
    // CHECKBOX: Verde para completado
    // ═════════════════════════════════════════════════════════════════════════
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.success;  // ✅ Verde = completado
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(color: AppColors.textSecondary, width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
    
    // ═════════════════════════════════════════════════════════════════════════
    // INPUTS
    // ═════════════════════════════════════════════════════════════════════════
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgInteractive,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.actionPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      labelStyle: AppTypography.label,
      hintStyle: AppTypography.hint,
    ),
    
    // ═════════════════════════════════════════════════════════════════════════
    // BOTTOM NAVIGATION
    // ═════════════════════════════════════════════════════════════════════════
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.bgDeep,
      selectedItemColor: AppColors.actionPrimary,
      unselectedItemColor: AppColors.textTertiary,
      selectedLabelStyle: GoogleFonts.montserrat(
        fontWeight: FontWeight.w700,
        fontSize: 10,
      ),
      unselectedLabelStyle: GoogleFonts.montserrat(
        fontWeight: FontWeight.w500,
        fontSize: 10,
      ),
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
    
    // ═════════════════════════════════════════════════════════════════════════
    // SNACKBAR
    // ═════════════════════════════════════════════════════════════════════════
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.bgElevated,
      contentTextStyle: AppTypography.label.copyWith(
        color: AppColors.textPrimary,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    
    // ═════════════════════════════════════════════════════════════════════════
    // DIALOG
    // ═════════════════════════════════════════════════════════════════════════
    dialogTheme: DialogTheme(
      backgroundColor: AppColors.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      titleTextStyle: AppTypography.sectionTitle,
      contentTextStyle: AppTypography.label.copyWith(
        color: AppColors.textSecondary,
      ),
    ),
    
    // ═════════════════════════════════════════════════════════════════════════
    // BOTTOM SHEET
    // ═════════════════════════════════════════════════════════════════════════
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
    ),
    
    // ═════════════════════════════════════════════════════════════════════════
    // PROGRESS INDICATOR: Verde para progreso
    // ═════════════════════════════════════════════════════════════════════════
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.success,
      linearTrackColor: AppColors.bgInteractive,
      circularTrackColor: AppColors.bgInteractive,
    ),
    
    // ═════════════════════════════════════════════════════════════════════════
    // DIVIDER
    // ═════════════════════════════════════════════════════════════════════════
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
    
    // ═════════════════════════════════════════════════════════════════════════
    // ICON
    // ═════════════════════════════════════════════════════════════════════════
    iconTheme: const IconThemeData(
      color: AppColors.textSecondary,
      size: 24,
    ),
  );
}

/// ============================================================================
/// EXTENSIONES ÚTILES
/// ============================================================================

extension AppColorsExtension on Color {
  /// Crea una versión con opacidad para overlays
  Color get overlay => withOpacity(0.1);
  
  /// Versión más oscura para pressed states
  Color get pressed => Color.lerp(this, Colors.black, 0.2)!;
  
  /// Versión más clara para hover states
  Color get hover => Color.lerp(this, Colors.white, 0.1)!;
}
