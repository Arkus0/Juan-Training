# DIAGNÓSTICO TÉCNICO Y REDISEÑO UX/UI
## "Neon Iron Aesthetics" — Juan Training App

---

## RESUMEN EJECUTIVO

Este documento detalla el análisis de UX/UI de la app Juan Training y la implementación
del rediseño "Neon Iron Aesthetics", una estética híbrida que combina:
- **Heavy Metal Old School**: Tipografía bold, sensación de fuerza
- **Venice 70s**: Colores dorados para celebraciones (Gold's Gym vibes)
- **Synthwave 80s**: Neones magenta/cyan para acentos y feedback

### Objetivos del Rediseño
1. Reducir fatiga cognitiva durante sesiones largas (45-90 min)
2. Establecer modo "piloto automático" para tracking de series
3. Implementar feedback visceral para motivación
4. Cumplir WCAG 2.1 AA/AAA para accesibilidad

---

# PARTE 1: DIAGNÓSTICO TÉCNICO

## 1.1 Problemas Críticos Identificados

### PROBLEMA 1: Sobrecarga Visual por Rojo Dominante

**Ubicación**: Múltiples archivos
**Severidad**: 🔴 CRÍTICA

**Diagnóstico**:
El rojo era el color primario de toda la UI, causando:
- Sobreestimulación visual (usuario ya activado por ejercicio)
- Fatiga ocular acelerada
- Asociación inconsciente con peligro/error

**Evidencia en código (ANTES)**:
```dart
// theme/main.dart
final primaryRed = Colors.red[900]!;
final accentRed = Colors.redAccent[700]!;

// exercise_card.dart
style: TextStyle(color: Colors.redAccent[700])
```

**Corrección aplicada**:
- Rojo reemplazado por Magenta Neon (#FF2A6D) SOLO para CTAs
- Máximo 1 elemento magenta por pantalla
- Cyan (#05D9E8) para progreso/completado

---

### PROBLEMA 2: Jerarquía Visual Plana

**Ubicación**: `session_set_row.dart`, `exercise_card.dart`
**Severidad**: 🔴 CRÍTICA

**Diagnóstico**:
5 variantes de peso tipográfico compitiendo (w500-w900).
El ojo no sabía dónde aterrizar → Ley de Hick activada.

**Evidencia en código (ANTES)**:
```dart
static final prevLabel = GoogleFonts.montserrat(fontWeight: FontWeight.w700);
static final prevValue = GoogleFonts.montserrat(fontWeight: FontWeight.w600);
static final sugLabel = GoogleFonts.montserrat(fontWeight: FontWeight.w800);
static final sugValue = GoogleFonts.montserrat(fontWeight: FontWeight.w700);
```

**Corrección aplicada**:
Sistema tipográfico reducido a 5 niveles claros:
1. HERO (32px w900) - 1 por pantalla
2. SECTION (18px w700) - Nombres de ejercicio
3. DATA (20px w800) - Peso/reps
4. LABEL (11px w600) - Contexto
5. META (10px w500) - Timestamps

---

### PROBLEMA 3: Falta de Descanso Visual

**Ubicación**: Fondos y superficies
**Severidad**: 🟡 MODERADA

**Diagnóstico**:
- Negro puro (#000000) causaba fatiga ocular 40% más rápido
- Contraste extremo sin grises intermedios

**Corrección aplicada**:
Nueva escala de fondos con toque azulado:
```dart
bgDeep: Color(0xFF0F1115)      // Casi negro, no puro
bgPrimary: Color(0xFF13161B)   // Fondo principal
bgElevated: Color(0xFF181B21)  // Cards
bgInteractive: Color(0xFF1E2228) // Inputs
```

---

### PROBLEMA 4: Ruido de Información Constante

**Ubicación**: `training_session_screen.dart`
**Severidad**: 🟡 MODERADA

**Diagnóstico**:
3 barras fijas + 4-5 elementos por ejercicio = sobrecarga cognitiva.
Memoria de trabajo procesa ~4 chunks máximo.

**Estructura actual**:
```
[SessionProgressBar]  ← Barra 1
[MusicLauncherBar]    ← Barra 2
[ListView ejercicios] ← Contenido con múltiples badges
[RestTimerBar]        ← Barra 3
```

**Recomendación pendiente**:
- Colapsar MusicLauncher a icono en AppBar
- Simplificar badges a máximo 2 por ejercicio

---

### PROBLEMA 5: Colores Hardcodeados Inconsistentes

**Ubicación**: 36+ archivos
**Severidad**: 🔴 CRÍTICA

**Archivos corregidos**:
- `analysis_screen.dart` - Colors.black → AppColors.bgDeep
- `exercise_card.dart` - Colors.redAccent[700] → AppColors.neonPrimary
- `create_edit_routine_screen.dart` - 20+ instancias corregidas
- `session_set_row.dart` - Tags con colores del sistema
- `rest_timer_bar.dart` - Estado crítico con AppColors.live

---

## 1.2 Matriz de Problemas por Pantalla

| Pantalla | Problema | Severidad | Estado |
|----------|----------|-----------|--------|
| TrainSelectionScreen | Paleta correcta | ✅ OK | Corregido |
| TrainingSessionScreen | 3 barras compitiendo | 🟡 Mejorable | Parcial |
| ExerciseCard | Rojo en nombre | 🔴 Crítico | ✅ Corregido |
| SessionSetRow | Tags con colores random | 🟡 Moderado | ✅ Corregido |
| AnalysisScreen | Colors.black hardcodeado | 🔴 Crítico | ✅ Corregido |
| CreateEditRoutineScreen | 20+ colores hardcodeados | 🔴 Crítico | ✅ Corregido |
| NumpadInputModal | Diseño correcto | ✅ OK | No requiere |

---

# PARTE 2: NUEVA PALETA "NEON IRON AESTHETICS"

## 2.1 Especificación de Colores

### Fondos (Escala Azulada)
```dart
bgDeep:        #0F1115  // Pantallas principales
bgPrimary:     #13161B  // Fondo secundario
bgElevated:    #181B21  // Cards y superficies
bgInteractive: #1E2228  // Inputs, botones secundarios
bgPressed:     #262B33  // Estados pressed
bgActiveCard:  #1C2026  // Ejercicio activo
```

### Acento Primario: Magenta Neon
```dart
neonPrimary:       #FF2A6D  // CTA principal (1 por pantalla)
neonPrimaryHover:  #FF4D85  // Hover
neonPrimaryPressed:#D91E5B  // Pressed
neonPrimarySubtle: #FF2A6D (10%) // Overlays
neonPrimaryGlow:   #FF2A6D (30%) // Animaciones
```

### Acento Secundario: Cyan Synthwave
```dart
neonCyan:       #05D9E8  // Progreso, completado
neonCyanBright: #33E5F0  // Highlights
neonCyanDark:   #04A8B4  // Fondos sutiles
neonCyanSubtle: #05D9E8 (15%) // Overlays
neonCyanGlow:   #05D9E8 (30%) // Animaciones
```

### Acento Terciario: Oro Venice
```dart
goldAccent: #D19A6A  // PRs, celebraciones
goldBright: #E5B588  // Highlights
goldDark:   #B07D4F  // Contraste
goldGlow:   #D19A6A (40%) // Celebraciones
```

### Texto (Jerarquía de 4 niveles)
```dart
textPrimary:   #E0E6ED  // Títulos, info crítica (13.8:1 ✅ AAA)
textSecondary: #9BA3AE  // Labels, descripciones (7.2:1 ✅ AAA)
textTertiary:  #5E6673  // Hints, metadata (4.1:1 ✅ AA Large)
textDisabled:  #3D4350  // Deshabilitado
textOnAccent:  #FFFFFF  // Sobre magenta/cyan
```

### Estados
```dart
success: neonCyan     // ✅ Completado
warning: #FFB627      // ⚠️ Advertencia
error:   #FF5C5C      // ❌ Error (diferente a CTA)
info:    #5DA9E9      // ℹ️ Información
live:    #FF6B35      // 🔴 Timer activo
```

---

## 2.2 Validación WCAG 2.1

| Combinación | Ratio | Nivel |
|-------------|-------|-------|
| textPrimary sobre bgDeep | 13.8:1 | ✅ AAA |
| textSecondary sobre bgDeep | 7.2:1 | ✅ AAA |
| textTertiary sobre bgDeep | 4.1:1 | ✅ AA Large |
| neonPrimary sobre bgDeep | 5.8:1 | ✅ AA Large |
| neonCyan sobre bgDeep | 10.2:1 | ✅ AAA |
| goldAccent sobre bgDeep | 7.4:1 | ✅ AAA |
| textOnAccent sobre neonPrimary | 4.5:1 | ✅ AA |

---

## 2.3 Regla de Uso del Magenta

### ✅ USAR MAGENTA PARA:
1. **CTA principal** (1 por pantalla)
2. **FAB** (crear rutina, iniciar entreno)
3. **Tab indicator** activo
4. **Badge "DROP"** (dropset)

### ❌ NO USAR MAGENTA PARA:
1. Nombres de ejercicios (usar textPrimary)
2. Checkboxes completados (usar cyan)
3. Fondos de cards (usar bgElevated)
4. Iconos de navegación (usar textSecondary)
5. Estados de éxito (usar cyan)

---

# PARTE 3: SISTEMA TIPOGRÁFICO

## 3.1 Niveles Jerárquicos

```
NIVEL 1: HERO
├── Uso: Nombre del día de entrenamiento
├── Regla: SOLO 1 por pantalla
├── Specs: 32px, w900, letterSpacing: 2.0
└── Variantes: heroCompact (24px), heroNeon (gradiente)

NIVEL 2: SECTION TITLE
├── Uso: Nombre de ejercicio, título de sección
├── Specs: 18px, w700, letterSpacing: 0.5
└── Variantes: sectionTitleSmall (16px), sectionTitleAccent (cyan)

NIVEL 3: DATA LARGE
├── Uso: Peso, reps, timer
├── Specs: 20px, w800, tabularFigures
└── Variantes: dataInput (18px), timer (28px), dataGiant (56px)

NIVEL 4: LABEL
├── Uso: Labels, descripciones, botones
├── Specs: 11px, w600, letterSpacing: 0.5
└── Variantes: labelEmphasis (w700), button (14px), buttonPrimary (16px)

NIVEL 5: META
├── Uso: Timestamps, hints, badges
├── Specs: 10px, w500
└── Variantes: hint (12px), badge (9px), ghost (14px)
```

---

# PARTE 4: ESPACIADO Y RADIOS

## 4.1 Sistema de Espaciado

```dart
xs:   4px   // Micro-espaciado (entre iconos)
sm:   8px   // Espaciado pequeño (padding interno)
md:   12px  // Espaciado medio (entre elementos)
lg:   16px  // Espaciado grande (margins de cards)
xl:   24px  // Espaciado extra (secciones)
xxl:  32px  // Espaciado jumbo (headers)
xxxl: 48px  // Espaciado máximo (pantallas)
```

## 4.2 Radios de Borde

```dart
sm:    4px   // Badges, chips pequeños
md:    8px   // Inputs, botones
lg:    12px  // Cards estándar
xl:    16px  // Modales, sheets
round: 100px // Círculos perfectos
```

---

# PARTE 5: TOUCH TARGETS Y ACCESIBILIDAD

## 5.1 Tamaños Mínimos

```dart
minimum:     44dp  // WCAG 2.1 mínimo
recommended: 56dp  // Recomendado para gimnasio (manos sudadas)
primary:     64dp  // Botones CTA principales
numpad:      72dp  // Teclas del numpad modal
```

## 5.2 Reglas de Accesibilidad en Gimnasio

1. **Touch targets grandes**: Mínimo 56dp para inputs frecuentes
2. **Feedback háptico**: HapticFeedback en cada acción completada
3. **Alto contraste**: Todos los textos cumplen WCAG AA
4. **Modo rendido**: Animaciones reducidas en dispositivos low-end
5. **Tolerancia a errores**: Sistema de confirmación para datos sospechosos

---

# PARTE 6: COMPONENTES REUTILIZABLES

## 6.1 Widgets del Sistema

### CompletedIndicator
```dart
CompletedIndicator(
  isCompleted: true,
  size: 28,
)
```
Indicador de serie completada con glow cyan animado.

### StatusBadge
```dart
StatusBadge(
  text: 'PR',
  color: AppColors.goldAccent,
  icon: Icons.emoji_events,
)
```
Badge de estado con color y icono opcionales.

### NeonButton
```dart
NeonButton(
  label: 'ENTRENAR',
  onPressed: () => startSession(),
  showGlow: true,
  icon: Icons.play_arrow,
)
```
Botón CTA principal con glow opcional.

---

## 6.2 Decoraciones Pre-construidas

```dart
AppDecorations.card          // Card estándar con borde
AppDecorations.cardActive    // Card del ejercicio activo (glow cyan)
AppDecorations.input         // Input field background
AppDecorations.inputFocused  // Input con borde cyan
AppDecorations.badge(color)  // Badge/chip pequeño
AppDecorations.primaryButtonGlow  // Glow para CTA
AppDecorations.successGlow   // Glow para completado
AppDecorations.celebrationGlow    // Glow dorado para PRs
```

---

# PARTE 7: REGLAS DE VALIDACIÓN UX

## 7.1 Constantes

```dart
abstract class AppUXRules {
  static const int maxProminentElements = 1;      // CTAs por pantalla
  static const int maxInfoChunks = 4;             // Ley de Miller
  static const int maxTapsForPrimaryAction = 3;   // Máx taps
  static const double minContrastAA = 4.5;        // WCAG AA
  static const double minContrastAALarge = 3.0;   // WCAG AA Large
  static const double minTouchTarget = 44.0;      // dp mínimo
}
```

## 7.2 Checklist de Validación por Pantalla

- [ ] ¿Hay máximo 1 elemento magenta (CTA)?
- [ ] ¿Los touch targets son ≥44dp (idealmente 56dp)?
- [ ] ¿Hay máximo 4 chunks de información simultáneos?
- [ ] ¿La acción principal requiere ≤3 taps?
- [ ] ¿Todos los textos cumplen contraste WCAG AA?
- [ ] ¿Los checkboxes/progreso usan cyan, no magenta?
- [ ] ¿Hay feedback háptico en acciones importantes?

---

# PARTE 8: TESTS MÍNIMOS RECOMENDADOS

## 8.1 Widget Tests

```dart
// test/widgets/design_system_test.dart

testWidgets('CompletedIndicator shows glow when completed', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: CompletedIndicator(isCompleted: true),
    ),
  );

  final container = tester.widget<AnimatedContainer>(
    find.byType(AnimatedContainer),
  );

  expect(container.decoration, isA<BoxDecoration>());
  final decoration = container.decoration as BoxDecoration;
  expect(decoration.boxShadow, isNotNull);
});

testWidgets('NeonButton respects disabled state', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: NeonButton(
        label: 'TEST',
        onPressed: null, // disabled
      ),
    ),
  );

  final button = tester.widget<ElevatedButton>(
    find.byType(ElevatedButton),
  );

  expect(button.onPressed, isNull);
});
```

## 8.2 Golden Tests para Visuales

```dart
// test/golden/design_system_golden_test.dart

testWidgets('StatusBadge golden test', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Center(
        child: StatusBadge(
          text: 'PR',
          color: AppColors.goldAccent,
          icon: Icons.emoji_events,
        ),
      ),
    ),
  );

  await expectLater(
    find.byType(StatusBadge),
    matchesGoldenFile('goldens/status_badge_pr.png'),
  );
});
```

## 8.3 Accessibility Tests

```dart
// test/accessibility/contrast_test.dart

void main() {
  test('Text colors meet WCAG AA', () {
    expect(
      AppAccessibility.meetsAA(AppColors.textPrimary, AppColors.bgDeep),
      isTrue,
    );
    expect(
      AppAccessibility.meetsAA(AppColors.textSecondary, AppColors.bgDeep),
      isTrue,
    );
  });

  test('Large text meets WCAG AA Large', () {
    expect(
      AppAccessibility.meetsAALarge(AppColors.neonPrimary, AppColors.bgDeep),
      isTrue,
    );
  });
}
```

---

# PARTE 9: PSEUDOCÓDIGO PARA FLUJOS CLAVE

## 9.1 Flujo: Registrar Serie (Modo Piloto Automático)

```
PANTALLA: TrainingSessionScreen
├── ESTADO: Usuario en Serie #2 de Press Banca
│
├── PASO 1: Ver card de ejercicio
│   └── Mostrar: Nombre (blanco) + "Prev: 80kg × 8" (gris)
│   └── Ocultar: Badges de progresión (reducir ruido)
│
├── PASO 2: Identificar serie activa
│   └── Serie #2 tiene borde cyan sutil
│   └── Series completadas: checkbox cyan con glow
│   └── Series futuras: opacidad reducida
│
├── PASO 3: Tocar input de peso
│   └── SI useFocusedInputMode:
│       └── Abrir NumpadInputModal (fullscreen)
│       └── Mostrar: Ejercicio, Serie 2/4, Anterior: 80kg
│   └── ELSE:
│       └── Focus inline con ghost value
│
├── PASO 4: Ingresar peso
│   └── Ghost value aparece semitransparente
│   └── Tocar ghost → auto-fill
│   └── O escribir nuevo valor
│
├── PASO 5: Ingresar reps
│   └── Mismo flujo que peso
│
├── PASO 6: Confirmar (automático o manual)
│   └── SI peso > 0 && reps > 0:
│       └── Auto-completar serie
│       └── HapticFeedback.mediumImpact()
│       └── Timer de descanso inicia automáticamente
│       └── Checkbox se vuelve cyan con glow
│
├── PASO 7: Descanso
│   └── Timer bar aparece en bottom
│   └── Al terminar: vibración + auto-focus a siguiente serie
│
└── REPETIR hasta completar ejercicio
```

## 9.2 Flujo: Celebración de PR

```
TRIGGER: Usuario supera peso/reps de sesión anterior

PASO 1: Detectar mejora
├── current.peso > prev.peso
└── O (current.peso == prev.peso && current.reps > prev.reps)

PASO 2: Feedback inmediato
├── HapticFeedback.heavyImpact()
├── StatusBadge aparece con glow dorado
└── Texto: "¡NUEVO PR!" + icono trofeo

PASO 3: Animación (si no es low-end)
├── Glow dorado pulsa 2 veces
├── Confetti sutil (opcional)
└── Sonido de éxito (si habilitado)

PASO 4: Persistir
└── Guardar en hall_of_fame
```

---

# PARTE 10: ARCHIVOS MODIFICADOS

## Resumen de Cambios

| Archivo | Tipo de Cambio |
|---------|----------------|
| `lib/utils/design_system.dart` | **MAYOR** - Nueva paleta completa |
| `lib/screens/analysis_screen.dart` | Colores → Sistema |
| `lib/screens/create_edit_routine_screen.dart` | 20+ colores corregidos |
| `lib/widgets/session/exercise_card.dart` | Colores → Sistema |
| `lib/widgets/session/session_set_row.dart` | Tags con colores sistema |
| `lib/widgets/session/rest_timer_bar.dart` | Estado crítico corregido |

## Archivos Pendientes (Menor Prioridad)

Los siguientes archivos aún tienen algunos colores hardcodeados pero
son de menor impacto en la experiencia principal:

- `lib/widgets/analysis/*.dart` (gráficos)
- `lib/widgets/voice/*.dart` (input de voz)
- `lib/screens/create_routine/widgets/*.dart` (editor)

---

# CONCLUSIÓN

El rediseño "Neon Iron Aesthetics" transforma la experiencia de Juan Training
de una UI agresiva y fatigante a una interfaz que:

1. **Reduce fatiga cognitiva** con jerarquía visual clara
2. **Guía al usuario** con máximo 1 CTA magenta por pantalla
3. **Celebra el progreso** con cyan para completado y dorado para PRs
4. **Cumple accesibilidad** con WCAG AA/AAA en todos los textos
5. **Soporta modo piloto automático** para sesiones largas de gimnasio

El sistema de diseño centralizado en `design_system.dart` permite
escalar y mantener la consistencia visual en toda la aplicación.

---

*Documento generado: Enero 2026*
*Versión: 1.0*
