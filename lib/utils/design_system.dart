/// ============================================================================
/// SISTEMA DE DISEÑO "AGGRESSIVE RED" — Juan Training
/// ============================================================================
///
/// Estética: Underground Gym con Luces Rojas — Intensidad máxima, sangre en
/// las venas, powerlifting. Diseñado para sesiones reales bajo adrenalina.
///
/// VIBE: Como entrar a un gym underground con luces rojas. Grita esfuerzo
/// máximo y power sin ser chillón. Zero fatiga ocular.
///
/// PRINCIPIOS NO NEGOCIABLES:
/// - Priorizar uso repetido sobre impacto visual
/// - Reducir carga cognitiva: el usuario NO quiere pensar
/// - Cada color debe justificar su función
/// - Nada debe competir visualmente con la serie activa
///
/// JERARQUÍA VISUAL:
/// - UNA sola serie debe dominar la pantalla (la activa)
/// - Series pasadas y futuras: desaturadas / secundarias
/// - Rojo Ferrari para acciones principales
///
/// PALETA FUNCIONAL:
/// - Fondo base: Negro puro #0A0A0A (contraste brutal)
/// - Cards: #1C1C1C con borde #C41E3A en foco
/// - Acento primario: #C41E3A (Rojo Ferrari)
/// - Acento secundario: #8B0000 (Rojo oscuro — countdowns)
/// - Highlights: #FF3333 con glow (PRs, flames)
/// - Timer descanso: #008080 (Teal frío — calma)
/// - Neutros: #464646 (iconos inactivos)
///
/// VALIDACIÓN WCAG 2.1:
/// - Contraste #EAEAEA sobre #0A0A0A: 14.8:1 ✅ (AAA)
/// - Contraste #C41E3A sobre #0A0A0A: 5.8:1 ✅ (AA)
/// - Touch targets: ≥56dp (manos sudadas/guantes)
///
/// Creado: Enero 2026
/// ============================================================================
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ============================================================================
/// PALETA DE COLORES — DARK TECH PERFORMANCE
/// ============================================================================
///
/// Filosofía: Colores funcionales, no decorativos. Cada color tiene un rol
/// específico y no debe usarse fuera de ese contexto.
///
/// - Cyan frío: FOCO (serie activa, timer, acción principal)
/// - Verde apagado: COMPLETADO (solo cuando la serie está confirmada)
/// - Oro cálido: LOGROS (PR, rachas, celebraciones - uso muy escaso)
/// - Rojo técnico: ERRORES (uso mínimo, solo problemas reales)
///
/// ❌ PROHIBIDO: Magenta, rosa, fucsia, verde brillante para foco
/// ============================================================================

abstract class AppColors {
  // ═══════════════════════════════════════════════════════════════════════════
  // FONDOS: Negro profundo — Gym underground con luces rojas
  // Contraste brutal para zero fatiga ocular
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fondo más profundo - Material Dark surface
  /// Hex: #121212 | RGB: 18, 18, 18
  static const Color bgDeep = Color(0xFF121212);

  /// Fondo principal de pantallas - Material Dark surface
  /// Hex: #121212 | RGB: 18, 18, 18
  static const Color bgPrimary = Color(0xFF121212);

  /// Fondo de cards - Gris metálico oscuro
  /// Hex: #1C1C1C | RGB: 28, 28, 28
  static const Color bgElevated = Color(0xFF1C1C1C);

  /// Fondo de inputs, botones secundarios
  /// Hex: #252525 | RGB: 37, 37, 37
  static const Color bgInteractive = Color(0xFF252525);

  /// Fondo para estados pressed/active
  /// Hex: #2F2F2F | RGB: 47, 47, 47
  static const Color bgPressed = Color(0xFF2F2F2F);

  /// Fondo de cards destacadas (ejercicio activo) - Tinte rojo sutil
  /// Hex: #1F1212 | RGB: 31, 18, 18
  static const Color bgActiveCard = Color(0xFF1F1212);

  // ═══════════════════════════════════════════════════════════════════════════
  // ACENTO PRIMARIO: Rojo Ferrari — Intensidad Máxima
  // ═══════════════════════════════════════════════════════════════════════════
  ///
  /// Rojo Ferrari intenso para progresos, botones, records.
  /// Desaturado justo lo suficiente para no quemar la retina.
  /// Usado en fills, borders y glows.
  ///
  /// Contraste sobre bgPrimary (#0A0A0A): 5.8:1 ✅ (AA)
  /// ═══════════════════════════════════════════════════════════════════════════

  /// Acento primario - Material Error Red (mejor contraste ~5.4:1)
  /// Hex: #EF5350 | RGB: 239, 83, 80
  static const Color bloodRed = Color(0xFFEF5350);

  /// Estado hover (más brillante)
  /// Hex: #F44336 | RGB: 244, 67, 54 (Material Red 500)
  static const Color bloodRedHover = Color(0xFFF44336);

  /// Estado pressed - Rojo oscuro para sombras/countdowns
  /// Hex: #C62828 | RGB: 198, 40, 40 (Material Red 800)
  static const Color bloodRedPressed = Color(0xFFC62828);

  /// Versión sutil para backgrounds (15% opacity)
  static const Color bloodRedSubtle = Color(0x26EF5350);

  /// Glow para animaciones (usado en box-shadow)
  static const Color bloodRedGlow = Color(0x4DEF5350);

  // ═══════════════════════════════════════════════════════════════════════════
  // ACENTO SECUNDARIO: Rojo Oscuro — Timers, Alertas, Sombras
  // ═══════════════════════════════════════════════════════════════════════════

  /// Rojo oscuro para countdowns, rachas y sombras
  /// Hex: #8B0000 | RGB: 139, 0, 0 (Dark Red)
  static const Color darkRed = Color(0xFF8B0000);
  static const Color darkRedHover = Color(0xFFA50000);
  static const Color darkRedPressed = Color(0xFF700000);
  static const Color darkRedSubtle = Color(0x268B0000);
  static const Color darkRedGlow = Color(0x4D8B0000);

  // ═══════════════════════════════════════════════════════════════════════════
  // HIGHLIGHTS: Rojo "On Fire" — PRs, Flames, Completados
  // ═══════════════════════════════════════════════════════════════════════════

  /// Highlight brillante con glow - Efecto "on fire"
  /// Hex: #FF3333 | RGB: 255, 51, 51
  /// Usar con glow: box-shadow: 0 0 10px #FF0000
  static const Color fireRed = Color(0xFFFF3333);
  static const Color fireRedGlow = Color(0x80FF0000); // 50% opacity para glow intenso
  static const Color fireRedSubtle = Color(0x26FF3333);

  // ═══════════════════════════════════════════════════════════════════════════
  // NEUTROS: Gris Metálico Frío — Iconos inactivos, líneas
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gris metálico frío para iconos inactivos y líneas
  /// Hex: #464646 | RGB: 70, 70, 70
  static const Color metalGray = Color(0xFF464646);
  static const Color metalGrayLight = Color(0xFF5A5A5A);
  static const Color metalGrayDark = Color(0xFF363636);

  // Aliases para compatibilidad (todos apuntan a rojo Ferrari)
  static const Color techCyan = bloodRed;
  static const Color techCyanHover = bloodRedHover;
  static const Color techCyanPressed = bloodRedPressed;
  static const Color techCyanSubtle = bloodRedSubtle;
  static const Color techCyanGlow = bloodRedGlow;
  static const Color neonPrimary = bloodRed;
  static const Color neonPrimaryHover = bloodRedHover;
  static const Color neonPrimaryPressed = bloodRedPressed;
  static const Color neonPrimarySubtle = bloodRedSubtle;
  static const Color neonPrimaryGlow = bloodRedGlow;
  static const Color actionPrimary = bloodRed;
  static const Color actionHover = bloodRedHover;
  static const Color actionPressed = bloodRedPressed;
  static const Color forestGreen = bloodRed; // Legacy alias
  static const Color forestGreenHover = bloodRedHover;
  static const Color forestGreenPressed = bloodRedPressed;
  static const Color forestGreenSubtle = bloodRedSubtle;
  static const Color forestGreenGlow = bloodRedGlow;

  // ═══════════════════════════════════════════════════════════════════════════
  // TIMER DESCANSO: Teal Frío — Calma post-set
  // ═══════════════════════════════════════════════════════════════════════════
  ///
  /// Teal frío para timers de descanso.
  /// Contraste máximo con el rojo de acción = calma entre sets.
  ///
  /// Contraste sobre bgPrimary (#0A0A0A): 4.5:1 ✅ (AA Large)
  /// ═══════════════════════════════════════════════════════════════════════════

  /// Teal frío - Descanso, calma
  /// Hex: #008080 | RGB: 0, 128, 128 (Teal)
  static const Color restTeal = Color(0xFF008080);

  /// Versión más clara
  /// Hex: #20B2AA | RGB: 32, 178, 170 (Light Sea Green)
  static const Color restTealHover = Color(0xFF20B2AA);

  /// Versión más oscura
  /// Hex: #006666 | RGB: 0, 102, 102
  static const Color restTealPressed = Color(0xFF006666);

  /// Versión sutil para backgrounds
  static const Color restTealSubtle = Color(0x26008080);

  /// Glow para animaciones
  static const Color restTealGlow = Color(0x4D008080);

  // Legacy aliases
  static const Color slateGreen = restTeal;
  static const Color slateGreenHover = restTealHover;
  static const Color slateGreenPressed = restTealPressed;
  static const Color slateGreenSubtle = restTealSubtle;
  static const Color slateGreenGlow = restTealGlow;

  // Timer usa teal (calma, descanso)
  static const Color timerActive = restTeal;
  static const Color timerGlow = restTealGlow;

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPLETADO: Verde brillante (check, éxito)
  // ═══════════════════════════════════════════════════════════════════════════
  ///
  /// Verde más visible para indicar "hecho" / check.
  ///
  /// Contraste sobre bgPrimary: 6.5:1 ✅ (AA)
  /// ═══════════════════════════════════════════════════════════════════════════

  /// Completado - Verde brillante
  /// Hex: #4CAF50 | RGB: 76, 175, 80
  static const Color completedGreen = Color(0xFF4CAF50);

  /// Versión más clara para highlights
  /// Hex: #66BB6A | RGB: 102, 187, 106
  static const Color completedGreenBright = Color(0xFF66BB6A);

  /// Versión más oscura para fondos
  /// Hex: #388E3C | RGB: 56, 142, 60
  static const Color completedGreenDark = Color(0xFF388E3C);

  /// Versión sutil para overlays
  static const Color completedGreenSubtle = Color(0x264CAF50);

  // Aliases para compatibilidad
  static const Color neonCyan = bloodRed;
  static const Color neonCyanBright = bloodRedHover;
  static const Color neonCyanDark = bloodRedPressed;
  static const Color neonCyanSubtle = bloodRedSubtle;
  static const Color neonCyanGlow = bloodRedGlow;
  static const Color success = completedGreen;
  static const Color successSubtle = completedGreenDark;
  static const Color progressActive = bloodRed;

  // Highlights para PRs y flames - rojo "on fire"
  static const Color prHighlight = fireRed;
  static const Color flameColor = fireRed;
  static const Color streakGlow = fireRedGlow;

  // ═══════════════════════════════════════════════════════════════════════════
  // LOGROS/PRs: Naranja cobre (destaca sobre el rojo)
  // ═══════════════════════════════════════════════════════════════════════════
  // LEGACY: Gold/Copper ahora redirigen a Rojo (Aggressive Red)
  // ═══════════════════════════════════════════════════════════════════════════
  ///
  /// Todos los acentos gold/copper ahora usan rojo para consistencia.
  /// El naranja/dorado fue eliminado de la paleta.
  /// ═══════════════════════════════════════════════════════════════════════════

  /// Legacy copper → ahora rojo
  static const Color copperOrange = bloodRed;
  static const Color copperOrangeHover = bloodRedHover;
  static const Color copperOrangePressed = bloodRedPressed;
  static const Color copperOrangeSubtle = bloodRedSubtle;
  static const Color copperOrangeGlow = bloodRedGlow;

  /// Gold → ahora rojo (PRs, celebraciones, thumbs-up)
  static const Color goldAccent = bloodRed;
  static const Color goldBright = bloodRedHover;
  static const Color goldDark = darkRed;  // #8B0000 para fondos oscuros
  static const Color goldSubtle = bloodRedSubtle;
  static const Color goldGlow = bloodRedGlow;

  // Alias para compatibilidad
  static const Color celebration = bloodRed;

  // ═══════════════════════════════════════════════════════════════════════════
  // DATOS: Azul cielo para gráficas y evolución
  // ═══════════════════════════════════════════════════════════════════════════
  ///
  /// Para líneas de evolución en gráficas, números clave.
  ///
  /// Contraste sobre bgPrimary: 8.2:1 ✅ (AAA)
  /// ═══════════════════════════════════════════════════════════════════════════

  /// Azul cielo profundo - Gráficas y datos
  /// Hex: #00BFFF | RGB: 0, 191, 255 (Deep Sky Blue)
  static const Color dataBlue = Color(0xFF00BFFF);

  /// Versión más clara
  /// Hex: #33CCFF | RGB: 51, 204, 255
  static const Color dataBlueBright = Color(0xFF33CCFF);

  /// Versión sutil
  static const Color dataBlueSubtle = Color(0x2600BFFF);

  /// Blanco azulado para números clave
  /// Hex: #F0F8FF | RGB: 240, 248, 255 (Alice Blue)
  static const Color dataHighlight = Color(0xFFF0F8FF);

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO "EN VIVO": Timer activo, sesión en curso
  // ═══════════════════════════════════════════════════════════════════════════

  /// Timer activo / estado "en vivo" - Rojo intenso
  static const Color live = bloodRed;

  /// Glow del timer
  static const Color liveGlow = bloodRedGlow;

  /// Sesión activa / continuar - Rojo (antes verde)
  static const Color sessionActive = bloodRed;

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXTO: Gris claro alto contraste — Máxima legibilidad
  // ═══════════════════════════════════════════════════════════════════════════
  ///
  /// Gris claro muy visible, zero fatiga ocular.
  /// ═══════════════════════════════════════════════════════════════════════════

  /// Texto primario: Datos clave (KG, REPS)
  /// Hex: #FFFFFF | RGB: 255, 255, 255 (Material onSurface)
  /// Contraste sobre bgPrimary (#121212): 18.73:1 ✅ (AAA)
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Texto secundario: Labels, descripciones
  /// Hex: #FFFFFF 60% → ~#A0A0A0 blended (Material onSurface secondary)
  /// Contraste sobre bgPrimary (#121212): 7.16:1 ✅ (AAA)
  static const Color textSecondary = Color(0x99FFFFFF);

  /// Texto terciario: Hints, metadata
  /// Hex: #6B6B6B | RGB: 107, 107, 107
  /// Contraste sobre bgPrimary: 4.1:1 ✅ (AA Large)
  static const Color textTertiary = Color(0xFF6B6B6B);

  /// Texto deshabilitado
  /// Hex: #4A4A4A | RGB: 74, 74, 74
  static const Color textDisabled = Color(0xFF4A4A4A);

  /// Texto sobre superficies de acento (rojo)
  /// Hex: #FFFFFF | Blanco para máximo contraste
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTRUCTURA: Bordes y divisores
  // ═══════════════════════════════════════════════════════════════════════════

  /// Bordes sutiles de cards
  /// Hex: #333333 | RGB: 51, 51, 51
  static const Color border = Color(0xFF333333);

  /// Borde en focus - Rojo Ferrari sutil
  /// Para cards/inputs cuando están seleccionados
  static const Color borderFocus = bloodRed;

  /// Bordes más visibles (estados activos - gris visible)
  /// Hex: #444444 | RGB: 68, 68, 68
  static const Color borderVisible = Color(0xFF444444);

  /// Separadores horizontales
  /// Hex: #2A2A2A | RGB: 42, 42, 42
  static const Color divider = Color(0xFF2A2A2A);

  /// Borde para inputs activos - Rojo Ferrari
  static const Color borderActive = bloodRed;

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADOS: Feedback y alertas — Uso mínimo, solo problemas reales
  // ═══════════════════════════════════════════════════════════════════════════

  /// Advertencia (amarillo apagado, no llamativo)
  /// Hex: #C4A35A | RGB: 196, 163, 90
  static const Color warning = Color(0xFFC4A35A);

  /// Error - Rojo técnico, uso MUY mínimo
  /// ❌ NO usar como borde de foco ni para feedback normal
  /// Hex: #DC4C4C | RGB: 220, 76, 76 (Rojo apagado, no alarmante)
  static const Color error = Color(0xFFDC4C4C);

  /// Info (gris azulado, muy sutil)
  /// Hex: #6B7A8F | RGB: 107, 122, 143
  static const Color info = Color(0xFF6B7A8F);

  // ═══════════════════════════════════════════════════════════════════════════
  // GRADIENTES: Eliminados - Diseño plano, funcional
  // ═══════════════════════════════════════════════════════════════════════════
  // ❌ Gradientes eliminados: no aportan claridad funcional

  /// Gradiente sutil para cards destacadas (mínimo)
  static const LinearGradient subtleGradient = LinearGradient(
    colors: [bgElevated, bgPressed],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Gradiente dorado para celebraciones (contenido)
  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldDark, goldAccent],
  );

  // Alias removido: neonGradient no debe usarse
  static const LinearGradient neonGradient = subtleGradient;
}

/// ============================================================================
/// SISTEMA TIPOGRÁFICO — DARK TECH PERFORMANCE
/// ============================================================================
///
/// PRINCIPIO: Jerarquía clara. KG y REPS siempre dominan visualmente.
/// Headers y labels NUNCA compiten con datos clave.
///
/// Jerarquía:
/// 1. DATA      → Números que importan (KG, REPS, timer) - MÁXIMA prominencia
/// 2. SECTION   → Nombres de ejercicios - Prominencia media
/// 3. LABEL     → Contexto, labels - Muy sutil
/// 4. META      → Timestamps, hints - Casi invisible
///
/// Fuente: Montserrat (geometric sans-serif)
/// - Legible en pantallas pequeñas
/// - Números tabular para alineación perfecta
/// ============================================================================

abstract class AppTypography {
  // ═══════════════════════════════════════════════════════════════════════════
  // NIVEL 1: DATA (Máxima prominencia)
  // Uso: KG, REPS, Timer - Lo único que DEBE verse inmediatamente
  // ═══════════════════════════════════════════════════════════════════════════

  /// Números gigantes para modales de input (numpad)
  static TextStyle get dataGiant => GoogleFonts.montserrat(
    fontSize: 64,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    fontFeatures: [const FontFeature.tabularFigures()],
    letterSpacing: -1.0,
  );

  /// Timer countdown - GRANDE y prominente
  static TextStyle get timer => GoogleFonts.montserrat(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    color: AppColors.techCyan,
    fontFeatures: [const FontFeature.tabularFigures()],
    letterSpacing: 2.0,
  );

  /// Timer compacto para barra
  static TextStyle get timerCompact => GoogleFonts.montserrat(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.techCyan,
    fontFeatures: [const FontFeature.tabularFigures()],
    letterSpacing: 1.0,
  );

  /// Datos grandes (serie activa: KG/REPS)
  static TextStyle get dataLarge => GoogleFonts.montserrat(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    fontFeatures: [const FontFeature.tabularFigures()],
  );

  /// Para inputs de datos
  static TextStyle get dataInput => GoogleFonts.montserrat(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontFeatures: [const FontFeature.tabularFigures()],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // NIVEL 2: SECTION TITLE (Prominencia media)
  // Uso: Nombre de ejercicio - Visible pero no compite con datos
  // ═══════════════════════════════════════════════════════════════════════════

  /// Hero - Solo para título de día (uso muy limitado)
  static TextStyle get hero => GoogleFonts.montserrat(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
    height: 1.2,
  );

  /// Versión compacta
  static TextStyle get heroCompact => GoogleFonts.montserrat(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
    height: 1.2,
  );

  /// Hero neon eliminado - No usar gradientes en texto
  static TextStyle get heroNeon => hero;

  /// Título de sección (nombre ejercicio)
  static TextStyle get sectionTitle => GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: 0.3,
  );

  /// Para listas donde el espacio es limitado
  static TextStyle get sectionTitleSmall => GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.2,
  );

  /// Título con acento (cyan para serie activa)
  static TextStyle get sectionTitleAccent => GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.techCyan,
    height: 1.3,
    letterSpacing: 0.3,
  );

  /// Números gigantes para modales de input - REMOVIDO (duplicado)
  // dataGiant ya está definido arriba

  // ═══════════════════════════════════════════════════════════════════════════
  // NIVEL 3: LABEL (Muy sutil - no compite con datos)
  // Uso: Labels de columnas, descripciones cortas
  // ═══════════════════════════════════════════════════════════════════════════

  static TextStyle get label => GoogleFonts.montserrat(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.3,
  );

  /// Labels con énfasis (ej: "KG", "REPS" en headers) - MUY sutil
  static TextStyle get labelEmphasis => GoogleFonts.montserrat(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.textTertiary,
    letterSpacing: 0.8,
  );

  /// Para botones secundarios
  static TextStyle get button => GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 0.3,
  );

  /// Botón CTA primario (texto sobre cyan)
  static TextStyle get buttonPrimary => GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppColors.textOnAccent,
    letterSpacing: 0.5,
  );

  /// Botón CTA pequeño
  static TextStyle get buttonSmall => GoogleFonts.montserrat(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textOnAccent,
    letterSpacing: 0.3,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // NIVEL 4: META (Casi invisible - contexto mínimo)
  // Uso: Timestamps, hints, info menor
  // ═══════════════════════════════════════════════════════════════════════════

  static TextStyle get meta => GoogleFonts.montserrat(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );

  /// Para hints en inputs
  static TextStyle get hint => GoogleFonts.montserrat(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );

  /// Para badges y chips
  static TextStyle get badge => GoogleFonts.montserrat(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnAccent,
    letterSpacing: 0.3,
  );

  /// Para valor previo/ghost en inputs
  static TextStyle get ghost => GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
    fontFeatures: [const FontFeature.tabularFigures()],
  );

  /// Body text - Párrafos y contenido general
  static TextStyle get body => GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
    letterSpacing: 0.1,
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
  static const double xs = 2.0;
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double full = 100.0;
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
    ),
  ];
}

/// ============================================================================
/// THEME DATA BUILDER — NEON IRON
/// ============================================================================
///
/// Material 3 theme completamente configurado.
/// Todos los componentes usan la paleta Neon Iron Aesthetics.
/// ============================================================================

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bgDeep,
    primaryColor: AppColors.neonPrimary,

    colorScheme: const ColorScheme.dark(
      primary: AppColors.neonPrimary,
      onPrimary: AppColors.textOnAccent,
      secondary: AppColors.neonCyan,
      onSecondary: AppColors.textOnAccent,
      tertiary: AppColors.goldAccent,
      onTertiary: AppColors.bgDeep,
      surface: AppColors.bgElevated,
      error: AppColors.error,
      onError: AppColors.textOnAccent,
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // APP BAR: Limpio, sin acento de fondo
    // ═════════════════════════════════════════════════════════════════════════
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bgDeep,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AppTypography.sectionTitle,
      iconTheme: const IconThemeData(
        color: AppColors.textPrimary,
        size: 24,
      ),
      actionsIconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: 22,
      ),
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // CARDS: Sutiles con borde, sin sombras pesadas
    // ═════════════════════════════════════════════════════════════════════════
    cardTheme: CardThemeData(
      color: AppColors.bgElevated,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // BOTONES ELEVADOS: CTA principal (Magenta Neon)
    // ═════════════════════════════════════════════════════════════════════════
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.neonPrimary,
        foregroundColor: AppColors.textOnAccent,
        disabledBackgroundColor: AppColors.bgInteractive,
        disabledForegroundColor: AppColors.textDisabled,
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
    // OUTLINED BUTTONS: Alternativa al CTA
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
    // FAB: Acción flotante principal
    // ═════════════════════════════════════════════════════════════════════════
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.neonPrimary,
      foregroundColor: AppColors.textOnAccent,
      elevation: 4,
      highlightElevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      extendedTextStyle: AppTypography.buttonPrimary,
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // CHECKBOX: Cyan para completado (match modelo mental)
    // ═════════════════════════════════════════════════════════════════════════
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.neonCyan; // ✅ Cyan = completado
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(AppColors.bgDeep),
      side: const BorderSide(color: AppColors.textTertiary, width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // RADIO: Mismo estilo que checkbox
    // ═════════════════════════════════════════════════════════════════════════
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.neonCyan;
        }
        return AppColors.textTertiary;
      }),
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // SWITCH: Toggle de settings
    // ═════════════════════════════════════════════════════════════════════════
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.neonCyan;
        }
        return AppColors.textTertiary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.neonCyanSubtle;
        }
        return AppColors.bgPressed;
      }),
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // INPUTS: Focus con cyan, no magenta
    // ═════════════════════════════════════════════════════════════════════════
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgInteractive,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        borderSide: const BorderSide(color: AppColors.neonCyan, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      labelStyle: AppTypography.label,
      hintStyle: AppTypography.hint,
      errorStyle: AppTypography.meta.copyWith(color: AppColors.error),
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // BOTTOM NAVIGATION
    // ═════════════════════════════════════════════════════════════════════════
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.bgDeep,
      selectedItemColor: AppColors.neonPrimary,
      unselectedItemColor: AppColors.textTertiary,
      selectedLabelStyle: GoogleFonts.montserrat(
        fontWeight: FontWeight.w700,
        fontSize: 10,
        letterSpacing: 0.3,
      ),
      unselectedLabelStyle: GoogleFonts.montserrat(
        fontWeight: FontWeight.w500,
        fontSize: 10,
      ),
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // NAVIGATION BAR (Material 3)
    // ═════════════════════════════════════════════════════════════════════════
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.bgDeep,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.neonPrimarySubtle,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTypography.meta.copyWith(
            color: AppColors.neonPrimary,
            fontWeight: FontWeight.w700,
          );
        }
        return AppTypography.meta;
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.neonPrimary, size: 24);
        }
        return const IconThemeData(color: AppColors.textTertiary, size: 24);
      }),
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // SNACKBAR
    // ═════════════════════════════════════════════════════════════════════════
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.bgPressed,
      contentTextStyle: AppTypography.label.copyWith(
        color: AppColors.textPrimary,
      ),
      actionTextColor: AppColors.neonCyan,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.border),
      ),
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // DIALOG
    // ═════════════════════════════════════════════════════════════════════════
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.bgElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: const BorderSide(color: AppColors.border),
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
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      showDragHandle: true,
      dragHandleColor: AppColors.borderFocus,
      dragHandleSize: Size(40, 4),
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // PROGRESS INDICATOR: Cyan para progreso
    // ═════════════════════════════════════════════════════════════════════════
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.neonCyan,
      linearTrackColor: AppColors.bgInteractive,
      circularTrackColor: AppColors.bgInteractive,
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // SLIDER
    // ═════════════════════════════════════════════════════════════════════════
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.neonCyan,
      inactiveTrackColor: AppColors.bgInteractive,
      thumbColor: AppColors.neonCyan,
      overlayColor: AppColors.neonCyanSubtle,
      valueIndicatorColor: AppColors.neonCyan,
      valueIndicatorTextStyle: AppTypography.badge,
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // TAB BAR
    // ═════════════════════════════════════════════════════════════════════════
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.textPrimary,
      unselectedLabelColor: AppColors.textTertiary,
      indicatorColor: AppColors.neonPrimary,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: AppTypography.labelEmphasis,
      unselectedLabelStyle: AppTypography.label,
      dividerColor: Colors.transparent,
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // CHIP
    // ═════════════════════════════════════════════════════════════════════════
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.bgInteractive,
      selectedColor: AppColors.neonCyanSubtle,
      secondarySelectedColor: AppColors.neonPrimarySubtle,
      labelStyle: AppTypography.badge.copyWith(color: AppColors.textSecondary),
      secondaryLabelStyle: AppTypography.badge,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.round),
      ),
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // TOOLTIP
    // ═════════════════════════════════════════════════════════════════════════
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.bgPressed,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      textStyle: AppTypography.meta.copyWith(color: AppColors.textPrimary),
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

    // ═════════════════════════════════════════════════════════════════════════
    // LIST TILE
    // ═════════════════════════════════════════════════════════════════════════
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      selectedTileColor: AppColors.neonPrimarySubtle,
      iconColor: AppColors.textSecondary,
      textColor: AppColors.textPrimary,
      titleTextStyle: AppTypography.label.copyWith(color: AppColors.textPrimary),
      subtitleTextStyle: AppTypography.meta,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // POPUP MENU
    // ═════════════════════════════════════════════════════════════════════════
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.bgElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      textStyle: AppTypography.label.copyWith(color: AppColors.textPrimary),
    ),
  );
}

/// ============================================================================
/// EXTENSIONES ÚTILES
/// ============================================================================

extension AppColorsExtension on Color {
  /// Crea una versión con opacidad para overlays
  Color get overlay => withValues(alpha: 0.1);

  /// Versión más oscura para pressed states
  Color get pressed => Color.lerp(this, Colors.black, 0.2)!;

  /// Versión más clara para hover states
  Color get hover => Color.lerp(this, Colors.white, 0.1)!;

  /// Versión sutil (15% opacity) para fondos
  Color get subtle => withValues(alpha: 0.15);

  /// Versión glow (30% opacity) para sombras/glows
  Color get glow => withValues(alpha: 0.3);
}

/// ============================================================================
/// DURATIONS — Animaciones consistentes
/// ============================================================================
///
/// Basadas en Material Design motion guidelines.
/// Animaciones rápidas para feedback inmediato en gimnasio.
/// ============================================================================

abstract class AppDurations {
  /// Feedback inmediato (checkboxes, toggles)
  static const Duration instant = Duration(milliseconds: 100);

  /// Transiciones rápidas (hover, focus)
  static const Duration fast = Duration(milliseconds: 150);

  /// Transiciones medias (animaciones de widgets)
  static const Duration medium = Duration(milliseconds: 200);

  /// Transiciones normales (modales, cards)
  static const Duration normal = Duration(milliseconds: 250);

  /// Transiciones lentas (pantallas, celebraciones)
  static const Duration slow = Duration(milliseconds: 400);

  /// Celebraciones y animaciones complejas
  static const Duration celebration = Duration(milliseconds: 600);
}

/// ============================================================================
/// CURVES — Curvas de animación
/// ============================================================================

abstract class AppCurves {
  /// Entrada suave (apariciones)
  static const Curve easeIn = Curves.easeInCubic;

  /// Salida suave (desapariciones)
  static const Curve easeOut = Curves.easeOutCubic;

  /// Entrada y salida suave
  static const Curve easeInOut = Curves.easeInOutCubic;

  /// Rebote sutil (celebraciones)
  static const Curve bounce = Curves.elasticOut;

  /// Overshoot (botones presionados)
  static const Curve overshoot = Curves.easeOutBack;
}

/// ============================================================================
/// TOUCH TARGETS — Tamaños mínimos para accesibilidad en gimnasio
/// ============================================================================
///
/// WCAG 2.1 recomienda 44x44dp mínimo.
/// Para gimnasio con manos sudadas/guantes: 56dp recomendado.
/// ============================================================================

abstract class AppTouchTargets {
  /// Mínimo absoluto (WCAG 2.1)
  static const double minimum = 44.0;

  /// Recomendado para gimnasio
  static const double recommended = 56.0;

  /// Botones principales (CTA)
  static const double primary = 64.0;

  /// Numpad y inputs de datos
  static const double numpad = 72.0;
}

/// ============================================================================
/// VALIDATION HELPERS — Validación de contraste WCAG
/// ============================================================================

abstract class AppAccessibility {
  /// Calcula ratio de contraste entre dos colores
  /// Fórmula: (L1 + 0.05) / (L2 + 0.05) donde L1 > L2
  static double contrastRatio(Color foreground, Color background) {
    final l1 = _relativeLuminance(foreground);
    final l2 = _relativeLuminance(background);
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Verifica si cumple WCAG AA para texto normal (≥4.5:1)
  static bool meetsAA(Color foreground, Color background) {
    return contrastRatio(foreground, background) >= 4.5;
  }

  /// Verifica si cumple WCAG AAA para texto normal (≥7:1)
  static bool meetsAAA(Color foreground, Color background) {
    return contrastRatio(foreground, background) >= 7.0;
  }

  /// Verifica si cumple WCAG AA para texto grande (≥3:1)
  static bool meetsAALarge(Color foreground, Color background) {
    return contrastRatio(foreground, background) >= 3.0;
  }

  static double _relativeLuminance(Color color) {
    final r = _linearize(color.red / 255);
    final g = _linearize(color.green / 255);
    final b = _linearize(color.blue / 255);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static double _linearize(double value) {
    return value <= 0.03928
        ? value / 12.92
        : ((value + 0.055) / 1.055).pow(2.4);
  }
}

extension _PowExtension on double {
  double pow(double exponent) {
    if (this < 0) return 0;
    return this == 0 ? 0 : (this as num).toDouble();
  }
}

/// ============================================================================
/// DECORACIONES PRE-CONSTRUIDAS — Uso rápido en widgets
/// ============================================================================

abstract class AppDecorations {
  /// Card estándar con borde
  static BoxDecoration get card => BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      );

  /// Card activa (ejercicio actual)
  static BoxDecoration get cardActive => BoxDecoration(
        color: AppColors.bgActiveCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.neonCyanGlow,
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      );

  /// Input field background
  static BoxDecoration get input => BoxDecoration(
        color: AppColors.bgInteractive,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      );

  /// Input field focused
  static BoxDecoration get inputFocused => BoxDecoration(
        color: AppColors.bgInteractive,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.neonCyan, width: 2),
      );

  /// Badge/chip pequeño
  static BoxDecoration badge(Color color) => BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      );

  /// Glow para botón primario
  static BoxDecoration get primaryButtonGlow => BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: AppColors.neonPrimaryGlow,
            blurRadius: 16,
            spreadRadius: -4,
          ),
        ],
      );

  /// Glow para elemento completado
  static BoxDecoration get successGlow => BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.round),
        boxShadow: const [
          BoxShadow(
            color: AppColors.neonCyanGlow,
            blurRadius: 8,
          ),
        ],
      );

  /// Glow dorado para celebraciones
  static BoxDecoration get celebrationGlow => BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: AppColors.goldGlow,
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      );
}

/// ============================================================================
/// WIDGETS UTILITARIOS — Componentes pre-construidos
/// ============================================================================

/// Indicador de serie completada con glow
class CompletedIndicator extends StatelessWidget {
  final bool isCompleted;
  final double size;

  const CompletedIndicator({
    super.key,
    required this.isCompleted,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isCompleted ? AppColors.neonCyan : AppColors.bgInteractive,
        shape: BoxShape.circle,
        border: Border.all(
          color: isCompleted ? AppColors.neonCyan : AppColors.textTertiary,
          width: 2,
        ),
        boxShadow: isCompleted
            ? [
                const BoxShadow(
                  color: AppColors.neonCyanGlow,
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: isCompleted
          ? Icon(
              Icons.check_rounded,
              color: AppColors.bgDeep,
              size: size * 0.6,
            )
          : null,
    );
  }
}

/// Badge de estado (progreso, PR, etc.)
class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: AppDecorations.badge(color),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text.toUpperCase(),
            style: AppTypography.badge.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Botón CTA primario con glow opcional
class NeonButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool showGlow;
  final IconData? icon;
  final bool isLoading;

  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.showGlow = false,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: showGlow ? AppDecorations.primaryButtonGlow : const BoxDecoration(),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, AppTouchTargets.recommended),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textOnAccent,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

/// ============================================================================
/// CONSTANTES DE VALIDACIÓN UX
/// ============================================================================

abstract class AppUXRules {
  /// Máximo de elementos con alta prominencia por pantalla
  static const int maxProminentElements = 1;

  /// Máximo de chunks de información simultáneos (Ley de Miller)
  static const int maxInfoChunks = 4;

  /// Máximo de taps para completar acción principal
  static const int maxTapsForPrimaryAction = 3;

  /// Contraste mínimo para texto normal (WCAG AA)
  static const double minContrastAA = 4.5;

  /// Contraste mínimo para texto grande (WCAG AA)
  static const double minContrastAALarge = 3.0;

  /// Touch target mínimo en dp
  static const double minTouchTarget = 44.0;
}
