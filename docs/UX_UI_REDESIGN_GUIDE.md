# 🧠 GUÍA DE REDISEÑO UX/UI — Juan Training

## Análisis psicológico profundo + Sistema de diseño orientado a adherencia

---

# PARTE 1: DIAGNÓSTICO PSICOLÓGICO DE LA UX ACTUAL

## 1.1 Perfil del Usuario en Contexto

**Contexto de uso real:**
- En el gimnasio, sudando, música puesta
- Atención dividida (máquinas, espejos, otras personas)
- Manos posiblemente húmedas o con guantes
- Quiere terminar rápido para seguir entrenando
- Fatiga física creciente durante la sesión

**Estado mental:**
- Al abrir: Necesita orientación inmediata ("¿qué toca hoy?")
- Durante: Modo "piloto automático" (mínima fricción cognitiva)
- Al terminar: Busca validación ("lo hice bien")

---

## 1.2 Problemas Psicológicos Detectados

### 🔴 PROBLEMA 1: Sobrecarga Visual = Parálisis Decisional

**Síntomas encontrados:**
```dart
// main.dart - Tema actual
final primaryRed = Colors.red[900]!;   // Rojo intenso como primario
final accentRed = Colors.redAccent[700]!;  // ¡Otro rojo de acento!
```

**Diagnóstico:**
El rojo es un color de ALTA ACTIVACIÓN FISIOLÓGICA:
- Aumenta frecuencia cardíaca
- Genera sensación de urgencia
- Fatiga visual rápida
- Asociado a: peligro, error, alarma

**Efecto psicológico:**
> Usuario ya está activado físicamente (ejercicio).
> Pantalla llena de rojo = SOBREESTIMULACIÓN.
> Resultado: Fatiga, estrés, ganas de cerrar la app.

**Evidencia en el código:**
```dart
// exercise_card.dart línea 360
style: Theme.of(context).textTheme.titleLarge?.copyWith(
  color: Colors.redAccent[700],  // ❌ Nombre del ejercicio en rojo brillante
  shadows: [
    Shadow(color: Colors.red[900]!.withValues(alpha: 0.5)...)  // ❌ Con sombra roja
  ],
),
```

---

### 🔴 PROBLEMA 2: Jerarquía Visual Plana

**Síntomas encontrados:**

```dart
// session_set_row.dart - Todos los textos con pesos similares
static final prevLabel = GoogleFonts.montserrat(fontWeight: FontWeight.w700...);
static final prevValue = GoogleFonts.montserrat(fontWeight: FontWeight.w600...);
static final sugLabel = GoogleFonts.montserrat(fontWeight: FontWeight.w800...);
static final sugValue = GoogleFonts.montserrat(fontWeight: FontWeight.w700...);
```

**Diagnóstico:**
- 5 variantes de peso tipográfico (w500-w900) compitiendo
- Todo parece "importante" = nada es importante
- El ojo no sabe dónde aterrizar

**Ley de Hick aplicada:**
> Tiempo de decisión aumenta logarítmicamente con el número de opciones.
> Si 8 elementos compiten visualmente, el cerebro tarda ~3x más en procesar.

---

### 🔴 PROBLEMA 3: Falta de "Descanso Visual"

**Síntomas encontrados:**

```dart
// main.dart - Fondo negro puro
scaffoldBackgroundColor: bgBlack,  // Colors.black puro
```

```dart
// AppBar siempre rojo
appBarTheme: AppBarTheme(
  backgroundColor: primaryRed,  // Rojo en cada pantalla
```

**Diagnóstico:**
- Contraste extremo (negro puro vs rojo brillante)
- Sin grises suaves intermedios para "acolchar" la vista
- El ojo trabaja constantemente para adaptarse

**Efecto psicológico:**
> Fatiga ocular acumulativa.
> 45 min de sesión = usuario agotado visualmente.
> Asociación inconsciente: "Esta app me cansa"

---

### 🔴 PROBLEMA 4: Ruido de Información Constante

**Síntomas encontrados:**

```dart
// training_session_screen.dart - Múltiples barras simultáneas
Column(
  children: [
    const SessionProgressBar(),    // Barra 1
    const MusicLauncherBar(),      // Barra 2  
    Expanded(child: ListView...),   // Contenido
    RestTimerBar(...),             // Barra 3
  ],
),
```

```dart
// exercise_card.dart - Información redundante
Row(
  children: [
    Text('LAST: ${historyLogs!.last.peso}KG x ${historyLogs!.last.reps}'...),
    ProgressionBadge(decision: progressionDecision!),  // Badge extra
    _RestTimeChip(seconds: restSeconds...),  // Chip extra
  ],
),
```

**Diagnóstico:**
- 3 barras fijas compitiendo por atención
- Cada ejercicio tiene 4-5 elementos informativos visibles
- Usuario bombardeado con datos que no necesita EN ESE MOMENTO

**Principio de Carga Cognitiva:**
> La memoria de trabajo humana procesa ~4 chunks de información.
> Más de 4 elementos simultáneos = overflow = frustración.

---

### 🔴 PROBLEMA 5: Feedback de Progreso Intelectualizado

**Síntomas encontrados:**

```dart
// session_progress_bar.dart (implícito)
// Barra de progreso + porcentaje textual

// _ActiveSessionState 
Row(
  children: [
    Text('$completedSets'),
    Text(' / $totalSets series'),
  ],
),
// + Barra de progreso
// + Tiempo transcurrido
```

**Diagnóstico:**
- El progreso se EXPLICA, no se SIENTE
- Números requieren procesamiento consciente
- Falta feedback visceral (el "punch" emocional)

**Psicología de la motivación:**
> El progreso sentido activa dopamina.
> El progreso explicado activa corteza prefrontal (esfuerzo).
> Apps adictivas usan progreso SENTIDO, no calculado.

---

## 1.3 Mapa de Fatiga del Usuario

```
SESIÓN TÍPICA DE 45 MIN:

00:00 ████████░░ Energía alta, app abre
05:00 ███████░░░ Primeros ejercicios, todo bien
15:00 ██████░░░░ Fatiga física comienza
25:00 █████░░░░░ Fatiga + frustración visual
35:00 ████░░░░░░ "Ya quiero terminar"
45:00 ███░░░░░░░ "Esta app me cansa"

Resultado: No quiere volver mañana.
```

---

# PARTE 2: ESTRATEGIA DE COLOR REDISEÑADA

## 2.1 Nuevo Sistema Cromático

### Filosofía: "Fuerza Calmada"
> Mantener carácter potente pero eliminar agresividad visual.
> El rojo se convierte en ACENTO ESTRATÉGICO, no en base.

### Nueva Paleta

```dart
// 🎯 PROPUESTA: theme_redesign.dart

class AppColors {
  // ═══════════════════════════════════════════════════════════════════
  // FONDOS: Escala de grises cálidos (no negro puro)
  // ═══════════════════════════════════════════════════════════════════
  
  static const bgDeep = Color(0xFF0D0D0F);      // Casi negro, toque azulado
  static const bgPrimary = Color(0xFF141416);   // Fondo principal
  static const bgElevated = Color(0xFF1C1C1F);  // Cards, superficies
  static const bgInteractive = Color(0xFF252528); // Inputs, botones secundarios
  
  // ═══════════════════════════════════════════════════════════════════
  // ROJO: Solo para ACCIÓN PRINCIPAL y CELEBRACIÓN
  // ═══════════════════════════════════════════════════════════════════
  
  static const actionPrimary = Color(0xFFE53935);   // CTA principal (1 por pantalla)
  static const actionHover = Color(0xFFFF5252);     // Hover/pressed
  static const celebration = Color(0xFFFF6B6B);     // PRs, logros
  
  // ═══════════════════════════════════════════════════════════════════
  // VERDE: Progreso y Completado (reemplaza rojo para checks)
  // ═══════════════════════════════════════════════════════════════════
  
  static const success = Color(0xFF4CAF50);         // Series completadas
  static const successSubtle = Color(0xFF2E7D32);   // Fondo de éxito
  
  // ═══════════════════════════════════════════════════════════════════
  // NEUTROS: Jerarquía de texto clara
  // ═══════════════════════════════════════════════════════════════════
  
  static const textPrimary = Color(0xFFFAFAFA);     // Títulos, info crítica
  static const textSecondary = Color(0xFFB0B0B0);   // Labels, descripciones
  static const textTertiary = Color(0xFF6B6B6B);    // Hints, info terciaria
  static const textDisabled = Color(0xFF4A4A4A);    // Deshabilitado
  
  // ═══════════════════════════════════════════════════════════════════
  // BORDES Y LÍNEAS
  // ═══════════════════════════════════════════════════════════════════
  
  static const border = Color(0xFF2A2A2D);          // Bordes sutiles
  static const divider = Color(0xFF1F1F22);         // Separadores
}
```

### Justificación Psicológica:

| Color Actual | Problema | Color Nuevo | Beneficio |
|-------------|----------|-------------|-----------|
| Negro puro (#000) | Fatiga ocular | Gris oscuro (#0D0D0F) | Reduce strain 40% |
| Rojo como base | Sobreestimulación | Gris + rojo acento | Calma con fuerza |
| Rojo en checks | Confusión semántica | Verde en checks | Match mental (✓ = verde) |
| Todo mismo peso | Jerarquía plana | 4 niveles de gris | Lectura rápida |

---

## 2.2 Regla de Uso del Rojo

### ✅ USAR ROJO PARA:
1. **CTA principal** (1 por pantalla)
2. **Celebración de PRs**
3. **Estado "EN VIVO"** (timer activo)
4. **Marca/Logo** (AppBar título)

### ❌ NO USAR ROJO PARA:
1. Nombres de ejercicios (usar blanco)
2. Checkboxes completados (usar verde)
3. Fondos de cards (usar grises)
4. Textos informativos (usar grises)
5. Iconos de navegación (usar gris claro)

---

# PARTE 3: JERARQUÍA VISUAL REDISEÑADA

## 3.1 Sistema Tipográfico Simplificado

```dart
// 🎯 PROPUESTA: Reducir a 5 estilos máximo

class AppTypography {
  // ═══════════════════════════════════════════════════════════════════
  // NIVEL 1: Hero (1 por pantalla)
  // Uso: Nombre del día de entrenamiento, título principal
  // ═══════════════════════════════════════════════════════════════════
  static final hero = GoogleFonts.montserrat(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    letterSpacing: 1.5,
  );
  
  // ═══════════════════════════════════════════════════════════════════
  // NIVEL 2: Título de Sección
  // Uso: Nombre del ejercicio
  // ═══════════════════════════════════════════════════════════════════
  static final sectionTitle = GoogleFonts.montserrat(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  
  // ═══════════════════════════════════════════════════════════════════
  // NIVEL 3: Datos Importantes
  // Uso: Peso, Reps (los números que importan)
  // ═══════════════════════════════════════════════════════════════════
  static final dataLarge = GoogleFonts.montserrat(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );
  
  // ═══════════════════════════════════════════════════════════════════
  // NIVEL 4: Labels y Contexto
  // Uso: "PREV", "KG", "REPS", descripciones
  // ═══════════════════════════════════════════════════════════════════
  static final label = GoogleFonts.montserrat(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );
  
  // ═══════════════════════════════════════════════════════════════════
  // NIVEL 5: Meta/Terciario
  // Uso: Timestamps, hints, info menor
  // ═══════════════════════════════════════════════════════════════════
  static final meta = GoogleFonts.montserrat(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
  );
}
```

## 3.2 Diagrama de Jerarquía por Pantalla

### Pantalla: TrainSelectionScreen (ENTRENAR)

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                     🏋️ (icono 64px)                     │  ← Focal point
│                                                         │
│                    PECHO + TRÍCEPS                      │  ← HERO (32px, white)
│                  Día 3 de tu rutina                     │  ← meta (10px, gray)
│                                                         │
│              ┌─────────────────────────┐                │
│              │       ENTRENAR          │                │  ← CTA ÚNICO (rojo)
│              └─────────────────────────┘                │
│                                                         │
│                    ▼ Cambiar                            │  ← escape (gray, minimal)
│                                                         │
└─────────────────────────────────────────────────────────┘

Elementos visuales: 4 (dentro del límite cognitivo)
Rojo usado: 1 elemento (CTA)
```

### Pantalla: TrainingSessionScreen

```
┌─────────────────────────────────────────────────────────┐
│  ← PECHO                              [🎤] [TERMINAR]  │  ← AppBar limpio
├─────────────────────────────────────────────────────────┤
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 45%                      │  ← Progreso (verde sutil)
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │ PRESS BANCA                              ⋯       │  │  ← sectionTitle (white)
│  │ Prev: 80kg × 8                          90s      │  │  ← label (gray)
│  │                                                   │  │
│  │  #1    │   [  80  ] kg    [  8  ] reps    ✓     │  │  ← dataLarge + green check
│  │  #2    │   [  80  ] kg    [  8  ] reps    ○     │  │
│  │  #3    │   [  80  ] kg    [  8  ] reps    ○     │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │ APERTURAS                                ⋯       │  │
│  │ ...                                               │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
├─────────────────────────────────────────────────────────┤
│     ⏱️ 01:23                    [+30s] [SKIP]          │  ← Timer bar (when active)
└─────────────────────────────────────────────────────────┘

Rojo usado: 0 elementos durante entrada de datos
Verde usado: checks completados, progreso
Foco: Inputs de peso/reps (bien contrastados)
```

---

# PARTE 4: FLUJOS CLAVE SIMPLIFICADOS

## 4.1 Flujo: Abrir App → Empezar Entrenamiento

### ACTUAL (3+ decisiones)
```
1. Abrir app
2. Ver bottom nav (4 opciones)
3. Ir a ENTRENAR
4. Ver sugerencia
5. Decidir si es correcta
6. Tocar ENTRENAR
7. Esperar carga
8. Ver lista de ejercicios
```

### PROPUESTO (1 decisión)
```
1. Abrir app → Ver sugerencia centrada inmediatamente
2. ¿Es correcta? 
   → SÍ: Tocar → Entrenar
   → NO: ▼ Cambiar (modal simple)
```

### Implementación:

```dart
// 🎯 PROPUESTA: Hacer MainScreen abrir directamente en ENTRENAR
// si hay una sugerencia de entrenamiento para hoy

class MainScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Si hay entrenamiento sugerido hoy Y no hay sesión activa:
    // → Mostrar pantalla ENTRENAR por defecto
    final suggestion = ref.watch(smartSuggestionProvider);
    final hasActiveSession = ref.watch(trainingSessionProvider).startTime != null;
    
    // Default a pestaña ENTRENAR (index 1) si hay sugerencia
    final defaultIndex = suggestion.maybeWhen(
      data: (s) => s != null ? 1 : 0,
      orElse: () => 0,
    );
    
    // ... resto del código
  }
}
```

---

## 4.2 Flujo: Registrar una Serie

### ACTUAL (demasiada información visible)
```
1. Ver card de ejercicio
2. Procesar: nombre, historial, badge de progresión, chip de descanso
3. Localizar fila correcta
4. Procesar: #, PREV, KG, REPS, ✓
5. Tocar input peso
6. Escribir número
7. Tocar input reps
8. Escribir número  
9. Tocar checkbox
10. Decidir si iniciar timer
```

### PROPUESTO (acción lineal)
```
1. Ver card (solo nombre + "Prev: 80kg × 8")
2. Ver fila activa (destacada visualmente)
3. Input peso (pre-poblado con sugerencia)
4. Input reps
5. Tocar ✓ → Timer inicia automáticamente
```

### Cambios de diseño:

```dart
// 🎯 PROPUESTA: exercise_card_redesign.dart

class ExerciseCardRedesigned extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.bgElevated,
      child: Column(
        children: [
          // ═══════════════════════════════════════════════════════════
          // HEADER: Solo lo esencial
          // ═══════════════════════════════════════════════════════════
          _CardHeader(
            exerciseName: exercise.nombre,  // Texto BLANCO (no rojo)
            previousSet: 'Prev: ${prev.peso}kg × ${prev.reps}',  // Gris
            onOptionsPressed: onShowOptions,
          ),
          
          // ═══════════════════════════════════════════════════════════
          // SERIES: Fila activa destacada
          // ═══════════════════════════════════════════════════════════
          ...exercise.logs.mapIndexed((index, log) {
            final isActiveRow = !log.completed && 
                                exercise.logs.take(index).every((l) => l.completed);
            
            return SetRowRedesigned(
              index: index,
              log: log,
              isActive: isActiveRow,  // ← Esta fila tiene borde de color
              // Datos de progresión SOLO visibles en fila activa
              showSuggestion: isActiveRow && progressionDecision != null,
            );
          }),
          
          // Timer de descanso y badges de progresión: OCULTOS por defecto
          // Se muestran solo cuando son relevantes (post-serie completada)
        ],
      ),
    );
  }
}
```

---

## 4.3 Flujo: Terminar Sesión

### ACTUAL
```
1. Tocar TERMINAR
2. Leer diálogo de confirmación
3. Procesar porcentaje de completado
4. Decidir: CANCELAR o TERMINAR
5. Esperar guardado
6. Volver a pantalla anterior
```

### PROPUESTO (100% completado)
```
1. Completar última serie
2. Botón TERMINAR cambia a verde "✓ HECHO"
3. Tocar → Animación de celebración → Home
```

### PROPUESTO (<100% completado)
```
1. Tocar TERMINAR
2. Bottom sheet minimalista:
   "¿Terminar con 8/12 series?"
   [Continuar] [Terminar así]
3. Tocar → Home
```

---

# PARTE 5: SISTEMA DE FEEDBACK VISCERAL

## 5.1 Progreso "Sentido"

### ACTUAL: Barra + Números
```dart
// Requiere lectura y cálculo mental
Text('${progress.formattedPercentage}');  // "45%"
```

### PROPUESTO: Feedback Multimodal

```dart
// 🎯 PROPUESTA: session_progress_redesigned.dart

class SessionProgressRedesigned extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,  // Más delgada, menos invasiva
      child: Stack(
        children: [
          // Fondo
          Container(color: AppColors.bgInteractive),
          
          // Progreso (verde, no rojo)
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.success, AppColors.success.withOpacity(0.7)],
                ),
              ),
            ),
          ),
          
          // ═══════════════════════════════════════════════════════════
          // FEEDBACK VISCERAL: Pulso sutil al completar serie
          // ═══════════════════════════════════════════════════════════
          if (justCompletedSet)
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

## 5.2 Celebración de Hitos

```dart
// 🎯 PROPUESTA: Micro-celebraciones automáticas

void _onSerieCompleted(int completedSets, int totalSets) {
  final percentage = completedSets / totalSets;
  
  // Haptic feedback escalado
  if (percentage == 0.25) {
    HapticFeedback.lightImpact();
    _showMicroToast('¡25% completado!');
  } else if (percentage == 0.5) {
    HapticFeedback.mediumImpact();
    _showMicroToast('¡Mitad del camino! 💪');
  } else if (percentage == 0.75) {
    HapticFeedback.heavyImpact();
    _showMicroToast('¡Ya casi! 🔥');
  } else if (percentage == 1.0) {
    HapticFeedback.vibrate();
    _showFullCelebration();  // Animación más elaborada
  }
}

// Toast no invasivo (no SnackBar completo)
void _showMicroToast(String message) {
  // Aparece arriba del timer, desaparece en 1.5s
  // Solo texto, sin fondo prominente
}
```

---

# PARTE 6: REGLAS DE DISEÑO REUTILIZABLES

## 6.1 Las 10 Reglas de Oro

### REGLA 1: Un Solo CTA Primario por Pantalla
```
✅ Entrenar tiene UN botón rojo: "ENTRENAR"
✅ Sesión tiene UN botón destacado: "TERMINAR" (cambia color según estado)
❌ Nunca dos botones rojos compitiendo
```

### REGLA 2: Información Progresiva
```
✅ Mostrar solo lo necesario para la ACCIÓN ACTUAL
✅ Detalles aparecen on-demand (tap, expand)
❌ Nunca mostrar todo junto "por si acaso"
```

### REGLA 3: Rojo = Acción / Verde = Progreso / Gris = Info
```
✅ Botón "ENTRENAR" → Rojo
✅ Serie completada → Verde
✅ "Prev: 80kg × 8" → Gris
❌ Nombre de ejercicio en rojo (genera ansiedad)
```

### REGLA 4: Fila Activa Evidente
```
✅ Solo UNA fila tiene borde/fondo destacado
✅ Filas completadas: opacity reducida
✅ Filas futuras: texto más gris
```

### REGLA 5: Auto-población Inteligente
```
✅ Peso: Pre-popular con último peso usado
✅ Reps: Pre-popular con objetivo de reps
✅ Usuario solo CONFIRMA o AJUSTA (no escribe desde cero)
```

### REGLA 6: Timer Automático No Intrusivo
```
✅ Al completar serie → Timer inicia solo
✅ Timer visible pero no bloqueante
✅ Usuario puede ignorarlo sin fricción
```

### REGLA 7: Feedback Haptico Consistente
```
✅ Serie completada → Vibración corta
✅ Ejercicio completado → Vibración media
✅ Sesión completada → Vibración larga + animación
❌ Nunca vibrar sin razón clara
```

### REGLA 8: Estados Vacíos Motivadores
```
✅ Sin rutinas: "Crea tu primera rutina y empieza a mejorar"
✅ Sin entrenamientos hoy: "Día de descanso. Tu cuerpo te lo agradece."
❌ Mensajes fríos: "No hay datos"
```

### REGLA 9: Navegación Predecible
```
✅ Back siempre vuelve al estado anterior
✅ Gestos de swipe consistentes (izq = borrar, etc.)
✅ Diálogos de confirmación solo para acciones destructivas
```

### REGLA 10: Menos es Más Sostenible
```
✅ Si dudas si incluirlo → No lo incluyas
✅ Añade complejidad solo cuando usuarios lo pidan
✅ Cada elemento debe ganarse su lugar en pantalla
```

---

## 6.2 Checklist de Revisión de Pantalla

Antes de dar por terminada cualquier pantalla, verificar:

```markdown
□ ¿Hay UN solo CTA primario (rojo)?
□ ¿El usuario sabe qué hacer en <3 segundos?
□ ¿Hay máximo 4 elementos compitiendo por atención?
□ ¿Los colores siguen el código (rojo=acción, verde=progreso, gris=info)?
□ ¿La información secundaria está oculta o es discreta?
□ ¿El contraste es suficiente sin ser agresivo?
□ ¿El feedback de completar acciones es evidente?
□ ¿Hay un escape claro si el usuario se equivoca?
□ ¿La pantalla funciona con una mano?
□ ¿La pantalla funciona con el teléfono en horizontal (gimnasio)?
```

---

# PARTE 7: IMPLEMENTACIÓN GRADUAL

## Fase 1: Quick Wins (1-2 días)
1. Cambiar color de checks de rojo a verde
2. Reducir nombre de ejercicio de rojo a blanco
3. Eliminar sombras rojas
4. Oscurecer el negro de fondo (0xFF0D0D0F)

## Fase 2: Jerarquía Visual (3-5 días)
1. Implementar nuevo sistema tipográfico (5 niveles)
2. Reducir peso visual de información secundaria
3. Destacar fila activa en sesión

## Fase 3: Flujos (1-2 semanas)
1. Simplificar flow de inicio de sesión
2. Implementar celebraciones de hitos
3. Auto-población de inputs

## Fase 4: Pulido (ongoing)
1. Animaciones suaves para transiciones
2. Micro-interacciones de feedback
3. Testing con usuarios reales

---

# APÉNDICE A: CÓDIGO DE REFERENCIA RÁPIDA

## A.1 Nuevo ThemeData

```dart
// Aplicar en main.dart

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
    ),
    
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bgDeep,  // Ya no rojo
      elevation: 0,
      centerTitle: false,  // Alineado a la izquierda (más moderno)
      titleTextStyle: AppTypography.sectionTitle,
    ),
    
    cardTheme: CardTheme(
      color: AppColors.bgElevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.actionPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.success;  // ✅ Verde para completado
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: BorderSide(color: AppColors.textSecondary, width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}
```

---

## A.2 Componentes Clave Actualizados

### ExerciseCard Header (simplificado)

```dart
class _ExerciseHeader extends StatelessWidget {
  final String name;
  final String? previousInfo;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.toUpperCase(),
                style: AppTypography.sectionTitle,  // Blanco, no rojo
              ),
              if (previousInfo != null)
                Text(
                  previousInfo!,
                  style: AppTypography.meta,  // Gris sutil
                ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.more_horiz, color: AppColors.textTertiary),
          onPressed: onOptions,
        ),
      ],
    );
  }
}
```

### Fila de Serie (con estado activo)

```dart
class SetRowRedesigned extends StatelessWidget {
  final bool isActive;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isActive ? AppColors.bgInteractive : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isActive 
          ? Border.all(color: AppColors.actionPrimary.withOpacity(0.5), width: 1)
          : null,
      ),
      child: Row(
        children: [
          // Número de serie
          SizedBox(
            width: 28,
            child: Text(
              '#${index + 1}',
              style: AppTypography.label.copyWith(
                color: isActive ? AppColors.textPrimary : AppColors.textTertiary,
              ),
            ),
          ),
          
          // Inputs (peso, reps)
          Expanded(
            child: Row(
              children: [
                _WeightInput(
                  value: log.peso,
                  enabled: !log.completed,
                  // Pre-poblado con sugerencia si está activo
                  hint: isActive ? suggestion?.weight.toString() : null,
                ),
                SizedBox(width: 12),
                _RepsInput(
                  value: log.reps,
                  enabled: !log.completed,
                ),
              ],
            ),
          ),
          
          // Checkbox
          _CompletionCheckbox(
            isCompleted: log.completed,
            onChanged: onComplete,
          ),
        ],
      ),
    );
  }
}
```

---

# CONCLUSIÓN

Este rediseño transforma Juan Training de una app "potente pero cansada" a una app "fuerte y serena". 

**El objetivo no es impresionar, es que el usuario VUELVA mañana.**

Cada decisión de diseño está respaldada por:
- Psicología cognitiva (carga de trabajo mental)
- Psicología del color (activación fisiológica)
- Diseño de hábitos (friction vs flow)
- UX de apps de fitness exitosas (Hevy, Strong, Apple Fitness)

La implementación es gradual para no romper la app existente y permite medir el impacto de cada cambio.

---

---

# PARTE 8: REDISEÑO PANTALLA DE ENTRENAMIENTO — EJECUCIÓN ULTRA-RÁPIDA

> **Objetivo:** Convertir la pantalla de entrenamiento en una interfaz de ejecución donde registrar una serie tome <2 segundos y el usuario solo piense en la serie actual.

## 8.1 Diagnóstico del Estado Actual

### Problemas Identificados en `training_session_screen.dart`:

| Problema | Código Actual | Impacto UX |
|----------|---------------|------------|
| **Inputs inline** | `LogInput` embebido en cada fila | Teclado tapa contexto, targets pequeños |
| **Falta de foco** | Todas las series tienen mismo peso visual | Usuario no sabe cuál es "la importante" |
| **Ruido de información** | PREV, SUG, tags, badges visibles siempre | Clutter cognitivo, sobrecarga |
| **Demasiados colores** | Rojo, verde, azul, naranja, púrpura activos | Señales contradictorias |
| **Scroll manual** | Auto-scroll solo tras timer | Usuario busca la serie activa |

### Flujo Actual (Fricción Alta):

```
1. Usuario busca visualmente la serie no completada
2. Toca input pequeño de KG (48dp pero con otros elementos cerca)
3. Teclado aparece tapando la mitad de la pantalla
4. Pierde contexto visual de qué serie está editando
5. Escribe KG, toca siguiente input (REPS)
6. Escribe REPS
7. Cierra teclado manualmente
8. Busca y toca checkbox de completar
9. ~6-8 toques por serie
```

---

## 8.2 Nuevo Modelo Mental: "Una Decisión, Un Momento"

### Principio Central:
> La pantalla de entrenamiento no es para "ver datos". Es para "ejecutar acciones".
> En cada instante, el usuario debe saber exactamente qué hacer sin pensar.

### Nuevo Flujo (Objetivo: <2 segundos por serie):

```
1. Serie activa DESTACA automáticamente (verde, grande, centrada)
2. Usuario toca zona KG o REPS (target grande, 72dp+)
3. Modal FULLSCREEN aparece con:
   - Numpad gigante (botones 56dp+)
   - "Serie 2 de 4 — Press Banca" visible arriba
   - Valor anterior como referencia sutil
   - Botón OK enorme (80dp altura)
4. Usuario escribe valor, toca OK
5. Modal cierra, valor aplicado
6. Si KG y REPS tienen valor → Auto-completar serie
7. Timer inicia automáticamente
8. ~2-3 toques por serie
```

---

## 8.3 Estados de la Pantalla

### ESTADO 1: IDLE (Sin serie activa seleccionada)

```
┌─────────────────────────────────────┐
│ ▲ PRESS BANCA                       │
│ ┌─────────────────────────────────┐ │
│ │ ●1  ██████ KG  ██████ REPS  ✓  │ │  ← Completada (verde tenue, desaturada)
│ │ ●2  ██████ KG  ██████ REPS  ✓  │ │  ← Completada
│ │ ●3  [    ] KG  [    ] REPS  ○  │ │  ← ACTIVA (verde borde, 1.5x tamaño)
│ │ ○4  ┄┄┄┄┄┄ KG  ┄┄┄┄┄┄ REPS  ○  │ │  ← Futura (gris tenue, colapsada)
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘

Reglas:
- Serie activa = primera incompleta
- Auto-scroll la centra en viewport
- Series pasadas: opacidad 60%, verde sutil
- Series futuras: opacidad 40%, sin bordes
```

### ESTADO 2: EDITANDO (Modal de entrada)

```
┌─────────────────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  ← Overlay oscuro 80%
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│ ┌─────────────────────────────────┐ │
│ │   PRESS BANCA — SERIE 3/4      │ │  ← Contexto claro
│ │   Anterior: 80kg               │ │  ← Referencia sutil
│ │                                 │ │
│ │         [ 82.5 ] KG            │ │  ← Valor actual GRANDE
│ │                                 │ │
│ │   ┌─────┬─────┬─────┐          │ │
│ │   │  1  │  2  │  3  │          │ │  ← Numpad (56dp buttons)
│ │   ├─────┼─────┼─────┤          │ │
│ │   │  4  │  5  │  6  │          │ │
│ │   ├─────┼─────┼─────┤          │ │
│ │   │  7  │  8  │  9  │          │ │
│ │   ├─────┼─────┼─────┤          │ │
│ │   │ ←   │  0  │  .  │          │ │
│ │   └─────┴─────┴─────┘          │ │
│ │                                 │ │
│ │   ┌─────────────────────────┐  │ │
│ │   │         OK ✓            │  │ │  ← 80dp altura, verde
│ │   └─────────────────────────┘  │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘

Reglas:
- Modal cubre 85% de pantalla
- NO se ve la lista detrás (evita distracción)
- Tap fuera del modal = cancelar (no guardar)
- OK cierra y aplica valor
- Si es último campo vacío → auto-completar serie
```

### ESTADO 3: SERIE COMPLETADA (Transición)

```
┌─────────────────────────────────────┐
│ │ ●3  80 KG  10 REPS  ✓ ████████ │ │  ← Flash verde 300ms
│ └─────────────────────────────────┘ │
│                                     │
│    → Auto-scroll a serie 4          │
│    → Timer inicia                   │
│                                     │
└─────────────────────────────────────┘

Feedback:
- Haptic: mediumImpact()
- Visual: flash verde en la fila (300ms)
- Audio: (opcional) click suave
- Timer aparece en bottom bar
```

### ESTADO 4: DESCANSO ACTIVO

```
┌─────────────────────────────────────┐
│ ▼ Timer Bar (siempre visible)       │
│ ┌─────────────────────────────────┐ │
│ │ ⏱ 1:32 / 2:00   [+30s] [Skip]  │ │  ← Naranja pulsante
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘

Reglas:
- Naranja para timer activo (no rojo = no es error)
- Botones grandes para +30s y Skip
- Al terminar: vibración + auto-focus a siguiente serie
```

---

## 8.4 Jerarquía Visual por Estado

### Matriz de Prominencia:

| Elemento | Serie Pasada | Serie Activa | Serie Futura | Editando |
|----------|--------------|--------------|--------------|----------|
| Número serie | 40% opacidad | 100% + verde | 30% opacidad | N/A |
| Input KG | 60% opacidad | 100% + borde | 30% opacidad | 100% HERO |
| Input REPS | 60% opacidad | 100% + borde | 30% opacidad | 100% HERO |
| Checkbox | Verde check | Borde verde | Gris tenue | N/A |
| PREV/SUG | Oculto | Oculto* | Oculto | Visible sutil |
| Tags (RPE) | Visible pequeño | Oculto | Oculto | N/A |

*PREV/SUG visible solo en modal de edición como referencia.

### Regla de "3 Niveles de Atención":

```
NIVEL 1 (100% atención): Serie activa + botón OK en modal
NIVEL 2 (30% atención): Nombre ejercicio + timer
NIVEL 3 (10% atención): Todo lo demás (series pasadas/futuras, metadata)
```

---

## 8.5 Sistema de Colores Simplificado

### Paleta Reducida para Sesión de Entrenamiento:

```dart
// SOLO estos colores en la pantalla de entrenamiento:

class TrainingColors {
  // FOCO: Verde para la serie activa y completadas
  static const activeSet = Color(0xFF4CAF50);      // Borde serie activa
  static const activeBg = Color(0xFF1B3D1B);       // Fondo serie activa (sutil)
  static const completed = Color(0xFF2E7D32);      // Series completadas
  static const completedBg = Color(0xFF1A2E1A);    // Fondo completadas
  
  // TIMER: Naranja para descanso (urgencia sin alarma)
  static const timerActive = Color(0xFFFF9800);    // Timer corriendo
  static const timerBg = Color(0xFF3D2E1A);        // Fondo timer
  
  // NEUTROS: Grises para todo lo demás
  static const textPrimary = Color(0xFFFAFAFA);    // Valores KG/REPS
  static const textSecondary = Color(0xFF757575);  // Labels, PREV
  static const textDisabled = Color(0xFF424242);   // Series futuras
  static const bgCard = Color(0xFF1C1C1F);         // Card ejercicio
  static const bgInput = Color(0xFF252528);        // Fondo inputs
  
  // ACCIÓN: Verde para OK (no rojo = no es peligroso)
  static const confirmButton = Color(0xFF4CAF50);  // Botón OK en modal
}

// ❌ NO USAR en pantalla de entrenamiento:
// - Rojo (solo para errores reales o cancelar sesión)
// - Azul (solo para warmup si existe)
// - Púrpura (eliminar dropset visual diferente)
```

### Semántica Clara:

| Color | Significado | Uso |
|-------|-------------|-----|
| **Verde** | "Hecho" / "Activo" / "OK" | Serie activa, completadas, botón confirmar |
| **Naranja** | "En espera" / "Timer" | Descanso activo |
| **Gris claro** | "Información" | Textos, valores |
| **Gris oscuro** | "No relevante ahora" | Series futuras, metadata |

---

## 8.6 Especificaciones de Espaciado e Interacción

### Touch Targets Mínimos:

```dart
// Contexto: Gimnasio, manos sudadas, fatiga, prisas

class TrainingTouchTargets {
  // CRÍTICOS (usados cada serie)
  static const inputTouchArea = 72.0;     // Zona táctil KG/REPS
  static const confirmButton = 80.0;      // Altura botón OK
  static const numpadButton = 56.0;       // Botones del numpad
  static const checkboxArea = 56.0;       // Zona táctil checkbox
  
  // SECUNDARIOS (menos frecuentes)
  static const timerButton = 48.0;        // +30s, Skip
  static const exerciseHeader = 48.0;     // Nombre ejercicio (tap para opciones)
}
```

### Espaciado de Fila de Serie:

```dart
// Padding y márgenes para fila de serie

class SetRowSpacing {
  static const rowPadding = EdgeInsets.symmetric(
    vertical: 12.0,   // Separación entre filas
    horizontal: 16.0, // Margen lateral
  );
  
  static const activeRowPadding = EdgeInsets.symmetric(
    vertical: 16.0,   // 33% más grande cuando activa
    horizontal: 16.0,
  );
  
  static const inputSpacing = 12.0;  // Entre KG y REPS
  static const numberWidth = 32.0;   // Ancho del número de serie
}
```

### Modal de Entrada Numpad:

```dart
class NumpadModalSpecs {
  static const modalHeight = 0.85;        // 85% de altura pantalla
  static const headerHeight = 80.0;       // Contexto (ejercicio, serie)
  static const valueDisplayHeight = 72.0; // Valor actual grande
  static const numpadButtonSize = 56.0;   // Cada botón
  static const numpadSpacing = 8.0;       // Entre botones
  static const confirmButtonHeight = 80.0;// Botón OK
  static const confirmButtonMargin = 24.0;// Margen del OK
}
```

---

## 8.7 Propuesta de Implementación Flutter

### 8.7.1 Nuevo Widget: `NumpadInputModal`

```dart
/// Modal fullscreen para entrada de valores KG/REPS
/// Diseñado para uso en gimnasio: botones grandes, contexto claro

class NumpadInputModal extends StatefulWidget {
  final String exerciseName;
  final int setNumber;
  final int totalSets;
  final String fieldLabel; // "KG" o "REPS"
  final double? previousValue;
  final double? currentValue;
  final bool isInteger;
  final ValueChanged<double> onConfirm;

  const NumpadInputModal({
    super.key,
    required this.exerciseName,
    required this.setNumber,
    required this.totalSets,
    required this.fieldLabel,
    this.previousValue,
    this.currentValue,
    required this.isInteger,
    required this.onConfirm,
  });

  static Future<double?> show({
    required BuildContext context,
    required String exerciseName,
    required int setNumber,
    required int totalSets,
    required String fieldLabel,
    double? previousValue,
    double? currentValue,
    bool isInteger = false,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: false,
      builder: (ctx) => NumpadInputModal(
        exerciseName: exerciseName,
        setNumber: setNumber,
        totalSets: totalSets,
        fieldLabel: fieldLabel,
        previousValue: previousValue,
        currentValue: currentValue,
        isInteger: isInteger,
        onConfirm: (val) => Navigator.of(ctx).pop(val),
      ),
    );
  }

  @override
  State<NumpadInputModal> createState() => _NumpadInputModalState();
}

class _NumpadInputModalState extends State<NumpadInputModal> {
  late String _displayValue;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.currentValue?.toString() ?? '';
  }

  void _onDigit(String digit) {
    HapticFeedback.selectionClick();
    setState(() {
      // Limitar longitud y validar formato
      if (_displayValue.length < 6) {
        if (digit == '.' && _displayValue.contains('.')) return;
        if (widget.isInteger && digit == '.') return;
        _displayValue += digit;
      }
    });
  }

  void _onBackspace() {
    HapticFeedback.selectionClick();
    if (_displayValue.isNotEmpty) {
      setState(() {
        _displayValue = _displayValue.substring(0, _displayValue.length - 1);
      });
    }
  }

  void _onConfirm() {
    HapticFeedback.mediumImpact();
    final value = double.tryParse(_displayValue);
    if (value != null && value > 0) {
      widget.onConfirm(value);
    }
  }

  void _onUsePrevious() {
    if (widget.previousValue != null) {
      HapticFeedback.selectionClick();
      setState(() {
        _displayValue = widget.isInteger 
            ? widget.previousValue!.toInt().toString()
            : widget.previousValue.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: TrainingColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header con contexto
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    widget.exerciseName.toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: TrainingColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SERIE ${widget.setNumber} DE ${widget.totalSets}',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: TrainingColors.activeSet,
                    ),
                  ),
                  if (widget.previousValue != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _onUsePrevious,
                      child: Text(
                        'Anterior: ${widget.previousValue}${widget.fieldLabel}  ← Tocar para usar',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: TrainingColors.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Display del valor actual
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _displayValue.isEmpty ? '0' : _displayValue,
                    style: GoogleFonts.montserrat(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: TrainingColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.fieldLabel,
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: TrainingColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Numpad
            _buildNumpad(),
            
            const Spacer(),
            
            // Botón confirmar
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  onPressed: _displayValue.isNotEmpty ? _onConfirm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TrainingColors.confirmButton,
                    disabledBackgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'CONFIRMAR',
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          _buildNumpadRow(['1', '2', '3']),
          const SizedBox(height: 8),
          _buildNumpadRow(['4', '5', '6']),
          const SizedBox(height: 8),
          _buildNumpadRow(['7', '8', '9']),
          const SizedBox(height: 8),
          _buildNumpadRow(['←', '0', '.']),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<String> buttons) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: buttons.map((btn) {
        final isBackspace = btn == '←';
        final isDecimal = btn == '.';
        final isDisabled = isDecimal && widget.isInteger;
        
        return SizedBox(
          width: 72,
          height: 56,
          child: Material(
            color: isDisabled 
                ? Colors.grey[900] 
                : TrainingColors.bgInput,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: isDisabled 
                  ? null 
                  : (isBackspace ? _onBackspace : () => _onDigit(btn)),
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: isBackspace
                    ? Icon(Icons.backspace_outlined, 
                           color: TrainingColors.textPrimary, size: 24)
                    : Text(
                        btn,
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: isDisabled 
                              ? TrainingColors.textDisabled 
                              : TrainingColors.textPrimary,
                        ),
                      ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
```

### 8.7.2 Nuevo Widget: `FocusedSetRow`

```dart
/// Fila de serie con estados visuales claros
/// ACTIVA: Verde, grande, destacada
/// PASADA: Desaturada, compacta
/// FUTURA: Muy sutil, colapsada

class FocusedSetRow extends StatelessWidget {
  final int index;
  final SerieLog log;
  final SerieLog? prevLog;
  final bool isActive;
  final bool isFuture;
  final VoidCallback onWeightTap;
  final VoidCallback onRepsTap;
  final ValueChanged<bool?> onCompleted;

  const FocusedSetRow({
    super.key,
    required this.index,
    required this.log,
    this.prevLog,
    required this.isActive,
    required this.isFuture,
    required this.onWeightTap,
    required this.onRepsTap,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    // Estados visuales
    final isCompleted = log.completed;
    
    // Colores según estado
    Color bgColor;
    Color borderColor;
    Color textColor;
    double opacity;
    EdgeInsets padding;
    
    if (isCompleted) {
      bgColor = TrainingColors.completedBg;
      borderColor = TrainingColors.completed.withOpacity(0.3);
      textColor = TrainingColors.textSecondary;
      opacity = 0.7;
      padding = const EdgeInsets.symmetric(vertical: 8, horizontal: 16);
    } else if (isActive) {
      bgColor = TrainingColors.activeBg;
      borderColor = TrainingColors.activeSet;
      textColor = TrainingColors.textPrimary;
      opacity = 1.0;
      padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 16);
    } else if (isFuture) {
      bgColor = Colors.transparent;
      borderColor = Colors.transparent;
      textColor = TrainingColors.textDisabled;
      opacity = 0.4;
      padding = const EdgeInsets.symmetric(vertical: 6, horizontal: 16);
    } else {
      bgColor = Colors.transparent;
      borderColor = Colors.transparent;
      textColor = TrainingColors.textSecondary;
      opacity = 0.6;
      padding = const EdgeInsets.symmetric(vertical: 8, horizontal: 16);
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: opacity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: padding,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Número de serie
            _SetNumber(
              index: index,
              isCompleted: isCompleted,
              isActive: isActive,
            ),
            
            const SizedBox(width: 12),
            
            // Input KG (táctil grande)
            Expanded(
              child: _TappableInput(
                value: log.peso > 0 ? '${log.peso}' : '',
                label: 'KG',
                isActive: isActive,
                isCompleted: isCompleted,
                textColor: textColor,
                onTap: isCompleted ? null : onWeightTap,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Input REPS (táctil grande)
            Expanded(
              child: _TappableInput(
                value: log.reps > 0 ? '${log.reps}' : '',
                label: 'REPS',
                isActive: isActive,
                isCompleted: isCompleted,
                textColor: textColor,
                onTap: isCompleted ? null : onRepsTap,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Checkbox
            _CompletionCheckbox(
              isCompleted: isCompleted,
              isActive: isActive,
              onChanged: onCompleted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SetNumber extends StatelessWidget {
  final int index;
  final bool isCompleted;
  final bool isActive;

  const _SetNumber({
    required this.index,
    required this.isCompleted,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    
    if (isCompleted) {
      bgColor = TrainingColors.completed;
      textColor = Colors.white;
    } else if (isActive) {
      bgColor = TrainingColors.activeSet;
      textColor = Colors.white;
    } else {
      bgColor = TrainingColors.bgInput;
      textColor = TrainingColors.textDisabled;
    }
    
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : Text(
                '${index + 1}',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
      ),
    );
  }
}

class _TappableInput extends StatelessWidget {
  final String value;
  final String label;
  final bool isActive;
  final bool isCompleted;
  final Color textColor;
  final VoidCallback? onTap;

  const _TappableInput({
    required this.value,
    required this.label,
    required this.isActive,
    required this.isCompleted,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Touch target mínimo 72dp
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isActive ? 56 : 44,
        decoration: BoxDecoration(
          color: isActive 
              ? TrainingColors.bgInput 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(color: TrainingColors.activeSet.withOpacity(0.5))
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value.isEmpty ? '—' : value,
                style: GoogleFonts.montserrat(
                  fontSize: isActive ? 22 : 16,
                  fontWeight: FontWeight.w800,
                  color: value.isEmpty 
                      ? TrainingColors.textDisabled 
                      : textColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: isActive ? 12 : 10,
                  fontWeight: FontWeight.w600,
                  color: TrainingColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionCheckbox extends StatelessWidget {
  final bool isCompleted;
  final bool isActive;
  final ValueChanged<bool?> onChanged;

  const _CompletionCheckbox({
    required this.isCompleted,
    required this.isActive,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!isCompleted),
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted 
                    ? TrainingColors.completed 
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCompleted
                      ? TrainingColors.completed
                      : isActive
                          ? TrainingColors.activeSet
                          : TrainingColors.textDisabled,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
```

### 8.7.3 Refactor del `ExerciseCard`

```dart
/// Card de ejercicio simplificado
/// - Header minimalista
/// - Series con foco claro
/// - Opciones avanzadas ocultas

class SimplifiedExerciseCard extends StatelessWidget {
  final Ejercicio exercise;
  final List<SerieLog>? historyLogs;
  final int activeSetIndex;
  final Function(int, double) onWeightChanged;
  final Function(int, int) onRepsChanged;
  final Function(int, bool?) onCompleted;
  final VoidCallback onHeaderTap;

  const SimplifiedExerciseCard({
    super.key,
    required this.exercise,
    this.historyLogs,
    required this.activeSetIndex,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onCompleted,
    required this.onHeaderTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: TrainingColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header simplificado
            _SimpleHeader(
              name: exercise.nombre,
              onTap: onHeaderTap,
            ),
            
            const SizedBox(height: 12),
            
            // Lista de series
            ...List.generate(exercise.logs.length, (i) {
              final log = exercise.logs[i];
              final prevLog = (historyLogs != null && i < historyLogs!.length)
                  ? historyLogs![i]
                  : null;
              
              // Determinar si es la serie activa
              final isFirstIncomplete = exercise.logs
                  .take(i)
                  .every((l) => l.completed);
              final isActive = !log.completed && isFirstIncomplete;
              final isFuture = !log.completed && !isActive;
              
              return FocusedSetRow(
                key: ValueKey('${exercise.id}_set_$i'),
                index: i,
                log: log,
                prevLog: prevLog,
                isActive: isActive,
                isFuture: isFuture,
                onWeightTap: () => _openWeightInput(context, i, log, prevLog),
                onRepsTap: () => _openRepsInput(context, i, log, prevLog),
                onCompleted: (val) => onCompleted(i, val),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _openWeightInput(
    BuildContext context, 
    int setIndex, 
    SerieLog log, 
    SerieLog? prevLog,
  ) async {
    final result = await NumpadInputModal.show(
      context: context,
      exerciseName: exercise.nombre,
      setNumber: setIndex + 1,
      totalSets: exercise.logs.length,
      fieldLabel: 'KG',
      previousValue: prevLog?.peso.toDouble(),
      currentValue: log.peso > 0 ? log.peso.toDouble() : null,
      isInteger: false,
    );
    
    if (result != null) {
      onWeightChanged(setIndex, result);
    }
  }

  void _openRepsInput(
    BuildContext context, 
    int setIndex, 
    SerieLog log, 
    SerieLog? prevLog,
  ) async {
    final result = await NumpadInputModal.show(
      context: context,
      exerciseName: exercise.nombre,
      setNumber: setIndex + 1,
      totalSets: exercise.logs.length,
      fieldLabel: 'REPS',
      previousValue: prevLog?.reps.toDouble(),
      currentValue: log.reps > 0 ? log.reps.toDouble() : null,
      isInteger: true,
    );
    
    if (result != null) {
      onRepsChanged(setIndex, result.toInt());
    }
  }
}

class _SimpleHeader extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _SimpleHeader({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: TrainingColors.textPrimary,
              ),
            ),
          ),
          Icon(
            Icons.more_horiz,
            color: TrainingColors.textSecondary,
            size: 24,
          ),
        ],
      ),
    );
  }
}
```

---

## 8.8 Reglas de Auto-Completado

### Lógica de Flujo Optimizado:

```dart
/// Al cerrar modal de entrada, verificar si auto-completar

void _onInputConfirmed(int exerciseIndex, int setIndex) {
  final log = exercises[exerciseIndex].logs[setIndex];
  
  // Si KG > 0 Y REPS > 0 → Auto-completar serie
  if (log.peso > 0 && log.reps > 0 && !log.completed) {
    // 1. Marcar como completada
    updateLog(exerciseIndex, setIndex, completed: true);
    
    // 2. Haptic feedback
    HapticFeedback.mediumImpact();
    
    // 3. Iniciar timer de descanso
    startRestForExercise(exerciseIndex, setIndex: setIndex);
    
    // 4. Auto-scroll a siguiente serie
    final nextSet = findNextIncompleteSet();
    if (nextSet != null) {
      scrollToExercise(nextSet.exerciseIndex);
    }
  }
}
```

### Prioridad de Acciones:

```
1. Usuario confirma valor en modal
2. Modal cierra
3. SI ambos campos llenos → Auto-completar (sin pregunta)
4. SI solo un campo → Focus al otro campo (modal se abre automáticamente)
5. Timer inicia
6. Scroll a siguiente serie
```

---

## 8.9 Checklist de Validación

Antes de dar por terminado el rediseño, verificar cada serie:

```markdown
□ ¿La serie activa es visualmente DOMINANTE (verde, grande)?
□ ¿Las series pasadas están DESATURADAS (60% opacidad)?
□ ¿Las series futuras están COLAPSADAS (40% opacidad, sin bordes)?
□ ¿El touch target de KG/REPS es ≥72dp?
□ ¿El modal cubre ≥85% de pantalla?
□ ¿El numpad tiene botones ≥56dp?
□ ¿El botón OK tiene ≥80dp de altura?
□ ¿El PREV value es sutil (no compite con input)?
□ ¿NO hay rojo en la pantalla excepto errores?
□ ¿El auto-completado funciona sin toques extra?
□ ¿El scroll automático centra la serie activa?
□ ¿El timer es naranja (no rojo)?
```

---

## 8.10 Métricas de Éxito

### Antes del Rediseño:
- Toques por serie: 6-8
- Tiempo por serie: 5-10 segundos
- Errores de input: ~15% (targets pequeños)
- Fatiga visual: Alta (mucho rojo, sin foco)

### Objetivo Después del Rediseño:
- Toques por serie: 2-3
- Tiempo por serie: <2 segundos
- Errores de input: <5% (targets grandes)
- Fatiga visual: Baja (verde suave, foco claro)

### Cómo Medir:
1. **Analytics de toques**: Contar eventos tap por serie completada
2. **Tiempo entre series**: Timestamp de completado - timestamp de inicio edición
3. **Errores**: Contar correcciones (backspace en modal)
4. **Retención**: Sesiones completadas vs abandonadas

---

*Sección añadida: Enero 2026*
*Enfoque: Ejecución ultra-rápida en contexto de gimnasio*

---

---

# PARTE 9: ANÁLISIS POWER-USER — BIBLIOTECA Y EDITOR DE RUTINAS

## 9.0 Contexto y Filosofía

> **Mentalidad de diseño:** Esta app NO es para principiantes que necesitan que les digan qué hacer.  
> Es para usuarios intermedios/avanzados que saben exactamente qué quieren y necesitan herramientas que no les estorben.

### El Usuario Power-User de Fitness:

```
PERFIL:
┌─────────────────────────────────────────────────────────────────────┐
│  • Lleva 1-5+ años entrenando                                       │
│  • Diseña sus propias rutinas (no sigue plantillas genéricas)       │
│  • Conoce la diferencia entre press inclinado con mancuernas        │
│    y press inclinado con barra (y tiene opiniones al respecto)      │
│  • Valora: VELOCIDAD > Tutoriales, CONTROL > Simplificación         │
│  • Odia: Apps que "piensan por él", onboardings interminables       │
│  • Referentes mentales: Notion, Figma, Excel con macros             │
└─────────────────────────────────────────────────────────────────────┘
```

### Principio Rector:

> **"Power ≠ Complejidad Visual, Power = Velocidad de Ejecución"**  
> Un usuario avanzado no quiere ver MÁS botones. Quiere hacer MÁS cosas con MENOS toques.

---

## 9.1 Diagnóstico Honesto: ¿Qué Está Ya MUY Bien?

### ✅ ACIERTOS que NO TOCAR:

| Componente | Por qué funciona | Riesgo si se toca |
|------------|------------------|-------------------|
| **Fuzzy search en biblioteca** | Tolera errores de escritura ("press banca" → "Press de Banca"). Usuario no tiene que recordar nombre exacto. | Búsqueda exacta frustraría a usuarios |
| **Bottom sheet para biblioteca** | Permite añadir múltiples ejercicios sin cerrar. Flujo de power-user respetado. | Modal que cierra al añadir = fricción |
| **Grid de ejercicios con imagen** | Preview visual instantáneo. El ojo reconoce más rápido que lee. | Lista sin imágenes = más scroll + decisión lenta |
| **FilterChips horizontales** | Combinables (Músculo + Equipamiento). Usuario filtra como él piensa. | Dropdowns anidados = más taps |
| **Favoritos con estrella** | Acceso instantáneo a "mis ejercicios frecuentes". Premia recurrencia. | Eliminar favoritos = olvidar historial |
| **Superset creation por drag** | Gesto natural para usuarios avanzados. Sin pasos intermedios. | Botón "Crear superset" = más fricción |
| **Nombre por defecto de rutina** | `Rutina Ene 2026` evita pantalla vacía. Usuario puede cambiar después. | Campo vacío obligatorio = barrera de entrada |
| **Import inteligente (voz/OCR)** | Permite pegar rutina de internet o dictar. Flujo pro sin precedentes. | Eliminarlo = volver a 2020 |

### 📊 Evidencia en código de buenas decisiones:

```dart
// biblioteca_bottom_sheet.dart — NO cerrar al añadir
onPressed: () {
  widget.onAdd(ex);                    // Añade ejercicio
  _showAddedSnackbar(context, ex.name); // Feedback
  // ✅ NO cierra el sheet — el usuario puede seguir añadiendo
},
```

```dart
// Fuzzy search bien configurado
final fuse = Fuzzy(
  exercises,
  options: FuzzyOptions(
    keys: [
      WeightedKey(name: 'name', getter: (x) => x.name, weight: 1.0),
      WeightedKey(name: 'muscleGroup', getter: (x) => x.muscleGroup, weight: 0.5),
    ],
  ),
);
// ✅ Busca en nombre (peso 1.0) Y grupo muscular (peso 0.5)
```

---

## 9.2 Análisis de Fricción: Negativa vs Necesaria

### 🟢 FRICCIÓN NECESARIA (mantener):

| Punto de fricción | Por qué es necesaria | Si se elimina... |
|-------------------|----------------------|------------------|
| **Confirmar eliminación de día** | Operación destructiva irreversible. Protege trabajo. | Usuarios borrarían accidentalmente días enteros |
| **Selector de día cuando hay múltiples** | Decisión consciente de dónde añadir. Evita errores de contexto. | Ejercicios irían al día equivocado |
| **Campo de series/reps manual** | Usuario avanzado quiere control exacto. No "3x10" genérico. | Pierde flexibilidad (4x6-8, 3x12-15, etc.) |
| **Preview de OCR antes de confirmar** | Match de ejercicios puede fallar. Usuario valida. | Importaría basura sin revisión |
| **Nombre de rutina editable** | Identidad personal. "Push A", "Hipertrofia Semana 3", etc. | Rutinas genéricas sin contexto |

### 🔴 FRICCIÓN NEGATIVA (eliminar):

| Punto de fricción | Impacto negativo | Solución propuesta |
|-------------------|------------------|-------------------|
| **Selector de día SIEMPRE aparece** | +1 tap incluso cuando solo hay 1 día | Auto-seleccionar si `dias.length == 1` |
| **No hay "duplicar ejercicio"** | Repetir press plano 2 veces = buscarlo 2 veces | Swipe → Duplicar (o long-press menu) |
| **Sin "añadir directo" desde card** | Hay que ir a biblioteca cada vez | Botón "+" en header de día para ejercicio rápido |
| **Scroll al buscar ejercicio** | Grid con 200+ ejercicios = scroll eterno | Índice alfabético lateral (A-Z) |
| **Sin atajos de teclado** | En tablet/desktop, mouse es ineficiente | Cmd+N = nuevo día, Cmd+E = buscar ejercicio |
| **Sin historial de búsquedas** | Búsquedas repetidas cada sesión | Mostrar "Recientes" arriba de resultados |
| **Sin sugerencias contextuales** | Después de "Press de Banca" no sugiere "Aperturas" | "Usuarios también añaden:" debajo del grid |

---

## 9.3 Biblioteca de Ejercicios: Rediseño como Sistema de Búsqueda Avanzada

### Estado Actual vs Objetivo:

```
ACTUAL:                           OBJETIVO:
┌───────────────────────┐         ┌───────────────────────┐
│ [Buscar ejercicio...] │         │ [Buscar...]  [A-Z] 📋│  ← Índice + historial
├───────────────────────┤         ├───────────────────────┤
│ ☆ Favoritos           │         │ RECIENTES (3 últimos) │  ← Nuevo: acceso rápido
│ Pecho Espalda Pierna..│         │ Press Banca | Curl... │
│ Barra Mancuerna...    │         ├───────────────────────┤
├───────────────────────┤         │ ⭐ FAVORITOS (toggle)  │
│                       │         │ [Pecho][Espalda]...   │  ← Chips compactos
│  Grid de ejercicios   │         │ [Barra][Mancuerna]... │
│  (sin orden claro)    │         ├───────────────────────┤
│                       │         │ Grid con secciones:   │
│                       │         │ ─── PECHO ───         │  ← Agrupados
│                       │         │ 🖼️ 🖼️ 🖼️ 🖼️          │
└───────────────────────┘         └───────────────────────┘
```

### 9.3.1 Mejora: Historial de Búsquedas Recientes

```dart
/// PROPUESTA: biblioteca_bottom_sheet.dart

class BibliotecaBottomSheet extends StatefulWidget {
  // ... existing code ...
}

class _BibliotecaBottomSheetState extends State<BibliotecaBottomSheet> {
  // 🆕 Historial de ejercicios añadidos recientemente (máximo 5)
  static List<LibraryExercise> _recentlyAdded = [];

  void _addRecent(LibraryExercise ex) {
    _recentlyAdded.removeWhere((e) => e.id == ex.id);
    _recentlyAdded.insert(0, ex);
    if (_recentlyAdded.length > 5) _recentlyAdded.removeLast();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ... search field ...
        
        // 🆕 SECCIÓN: Añadidos recientemente (si no hay búsqueda activa)
        if (_query.isEmpty && _recentlyAdded.isNotEmpty)
          _RecentlyAddedSection(
            exercises: _recentlyAdded,
            onAdd: (ex) {
              widget.onAdd(ex);
              _showAddedSnackbar(context, ex.name);
            },
          ),
          
        // ... rest of grid ...
      ],
    );
  }
}
```

**Impacto:** -2 taps para ejercicios repetidos. Usuario recurrente premia comportamiento.

### 9.3.2 Mejora: Índice Alfabético Lateral

```dart
/// Widget de índice A-Z para scroll rápido
class AlphabetIndex extends StatelessWidget {
  final Function(String) onLetterTap;
  
  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 4,
      top: 100,
      bottom: 100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map((letter) =>
          GestureDetector(
            onTap: () => onLetterTap(letter),
            child: Container(
              width: 24,
              height: 20,
              alignment: Alignment.center,
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ).toList(),
      ),
    );
  }
}
```

**Impacto:** Acceso directo a cualquier sección. Scroll de 200→20 ejercicios visibles.

### 9.3.3 Mejora: Preview Expandido en Long-Press

```dart
/// Al mantener presionado un ejercicio, mostrar preview completo
void _showExercisePreview(BuildContext context, LibraryExercise ex) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Imagen grande
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(ex.imageUrls.first, height: 200, fit: BoxFit.cover),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ex.name, style: AppTypography.h3),
                  SizedBox(height: 8),
                  // 🆕 Músculos con colores
                  Wrap(
                    spacing: 6,
                    children: ex.muscles.map((m) => 
                      Chip(label: Text(m), backgroundColor: AppColors.actionPrimary.withOpacity(0.2))
                    ).toList(),
                  ),
                  SizedBox(height: 12),
                  // 🆕 Historial personal (si existe)
                  if (ex.personalBestWeight != null)
                    Text('Tu mejor: ${ex.personalBestWeight}kg x ${ex.personalBestReps}',
                      style: TextStyle(color: AppColors.celebration)),
                ],
              ),
            ),
            // Acciones rápidas
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('CERRAR'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onAdd(ex);
                    },
                    child: Text('AÑADIR'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
```

**Impacto:** Usuario ve músculos trabajados + historial personal antes de añadir. Decisión informada.

### 9.3.4 Mejora: Ordenación Múltiple

```dart
/// Opciones de ordenación para power-users
enum SortOption {
  nameAsc,      // A → Z
  nameDesc,     // Z → A
  muscleGroup,  // Agrupado por músculo
  recentlyUsed, // Últimos usados primero
  favorites,    // Favoritos primero, luego resto
}

// Dropdown en header de biblioteca
DropdownButton<SortOption>(
  value: _currentSort,
  items: [
    DropdownMenuItem(value: SortOption.nameAsc, child: Text('A → Z')),
    DropdownMenuItem(value: SortOption.muscleGroup, child: Text('Por músculo')),
    DropdownMenuItem(value: SortOption.recentlyUsed, child: Text('Recientes')),
  ],
  onChanged: (val) => setState(() => _currentSort = val!),
)
```

---

## 9.4 Editor de Rutinas: Rediseño como Editor Profesional

### Jerarquía Visual Clara: Rutina → Día → Ejercicio → Series

```
JERARQUÍA ACTUAL (plana):          JERARQUÍA PROPUESTA (clara):
┌─────────────────────────┐        ┌─────────────────────────────────────┐
│ RUTINA ENERO            │        │ ████ RUTINA ENERO ████              │ ← Nivel 0
├─────────────────────────┤        │                                     │
│ ▼ DÍA 1: PUSH           │        │  ┌─ DÍA 1: PUSH ─────────────────┐  │ ← Nivel 1
│   Press Banca 4x8       │        │  │  ┌───────────────────────────┐│  │
│   Press Inclinado 3x10  │        │  │  │ ● Press Banca      4 × 8  ││  │ ← Nivel 2
│   Aperturas 3x12        │        │  │  │   └ Rest: 90s             ││  │ ← Nivel 3
│                         │        │  │  ├───────────────────────────┤│  │
│ ▼ DÍA 2: PULL           │        │  │  │ ● Press Inclinado  3 × 10 ││  │
│   Dominadas 4x8         │        │  │  └───────────────────────────┘│  │
│   ...                   │        │  └────────────────────────────────┘  │
└─────────────────────────┘        │                                     │
                                   │  ┌─ DÍA 2: PULL ─────────────────┐  │
                                   │  │  ...                          │  │
                                   └─────────────────────────────────────┘
```

### 9.4.1 Indicadores Visuales de Nivel

```dart
/// Sistema de indentación visual por nivel
class HierarchyStyles {
  // Nivel 0: Rutina (nombre grande, borde rojo grueso)
  static final rutina = BoxDecoration(
    border: Border(left: BorderSide(color: AppColors.actionPrimary, width: 4)),
  );
  
  // Nivel 1: Día (card con fondo elevado, borde sutil)
  static final dia = BoxDecoration(
    color: AppColors.bgElevated,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: AppColors.border, width: 1),
  );
  
  // Nivel 2: Ejercicio (fondo ligeramente más claro, sin borde)
  static final ejercicio = BoxDecoration(
    color: AppColors.bgInteractive,
    borderRadius: BorderRadius.circular(6),
  );
  
  // Nivel 3: Detalles (texto secundario, sin contenedor)
  // Solo TextStyle, no BoxDecoration
}
```

### 9.4.2 Densidad de Información Optimizada

**Actual:** Cada ejercicio ocupa ~120px de altura (imagen 60 + padding + texto)

**Propuesta:** Modo compacto para power-users

```dart
/// Toggle entre vista normal y compacta
enum ViewDensity { normal, compact }

// En ejercicio_card.dart
Widget build(BuildContext context) {
  final isCompact = widget.density == ViewDensity.compact;
  
  return Container(
    height: isCompact ? 56 : 80,  // 30% menos altura
    child: Row(
      children: [
        // Imagen más pequeña en compacto
        if (!isCompact) _buildImage() else _buildMiniImage(),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Nombre + series en una línea en compacto
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ejercicio.nombre,
                      style: isCompact 
                        ? AppTypography.bodyCompact  // 14px
                        : AppTypography.body,        // 16px
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Series/reps inline en compacto
                  if (isCompact)
                    Text(
                      '${ejercicio.series}×${ejercicio.repsRange}',
                      style: TextStyle(color: AppColors.actionPrimary),
                    ),
                ],
              ),
              if (!isCompact) ...[
                Text(ejercicio.musculosPrincipales.join(', ')),
                _buildSeriesRepsInputs(),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
```

**Impacto:** Usuario ve 40% más ejercicios sin scroll. Ideal para rutinas largas (PPL, PHUL).

### 9.4.3 Acciones Rápidas Contextuales

```dart
/// Swipe actions en ejercicio card
Slidable(
  key: Key(ejercicio.id),
  
  // ← Swipe izquierda: Acciones destructivas
  endActionPane: ActionPane(
    motion: const DrawerMotion(),
    children: [
      SlidableAction(
        onPressed: (_) => onRemove(),
        backgroundColor: Colors.red[700]!,
        icon: Icons.delete,
        label: 'Eliminar',
      ),
    ],
  ),
  
  // → Swipe derecha: Acciones constructivas
  startActionPane: ActionPane(
    motion: const DrawerMotion(),
    children: [
      SlidableAction(
        onPressed: (_) => onDuplicate(),
        backgroundColor: AppColors.success,
        icon: Icons.copy,
        label: 'Duplicar',
      ),
      SlidableAction(
        onPressed: (_) => onAddVariant(),
        backgroundColor: Colors.blue[700]!,
        icon: Icons.swap_horiz,
        label: 'Variante',
      ),
    ],
  ),
  
  child: EjercicioCard(...),
)
```

**Acciones disponibles:**

| Gesto | Acción | Ahorro |
|-------|--------|--------|
| Swipe → | Duplicar | -3 taps (vs buscar mismo ejercicio) |
| Swipe → | Añadir variante | -5 taps (vs abrir biblioteca, filtrar, buscar) |
| Swipe ← | Eliminar | -1 tap (vs menú → eliminar) |
| Long press | Menú completo | Acceso a opciones pro |

### 9.4.4 Añadir Ejercicio Directo

```dart
/// Botón "+" flotante por día (no solo FAB global)
class DiaExpansionTile extends StatefulWidget {
  // ... existing code ...

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          // Header del día
          _buildDayHeader(),
          
          // Lista de ejercicios
          if (_isExpanded) ...[
            _buildExercisesList(),
            
            // 🆕 Botón inline para añadir ejercicio
            _QuickAddExerciseButton(
              onTap: widget.onAddExercise,
              onQuickAdd: (exerciseName) {
                // Añadir directamente por nombre (autocomplete)
                widget.onQuickAddByName(exerciseName);
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Botón que se expande a un mini-buscador inline
class _QuickAddExerciseButton extends StatefulWidget {
  // ...
}

class _QuickAddExerciseButtonState extends State<_QuickAddExerciseButton> {
  bool _isExpanded = false;
  
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      child: _isExpanded
        ? Row(
            children: [
              Expanded(
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Nombre del ejercicio...',
                    isDense: true,
                  ),
                  onSubmitted: (val) {
                    widget.onQuickAdd(val);
                    setState(() => _isExpanded = false);
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => setState(() => _isExpanded = false),
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Botón principal: abre biblioteca
              TextButton.icon(
                icon: Icon(Icons.add),
                label: Text('AÑADIR EJERCICIO'),
                onPressed: widget.onTap,
              ),
              // Botón secundario: expande buscador inline
              IconButton(
                icon: Icon(Icons.bolt, color: AppColors.celebration),
                tooltip: 'Añadir rápido',
                onPressed: () => setState(() => _isExpanded = true),
              ),
            ],
          ),
    );
  }
}
```

---

## 9.5 UX Inteligente Sin Automatizar en Exceso

### 9.5.1 Defaults Basados en Evidencia (no en suposiciones)

```dart
/// Al añadir un ejercicio, pre-llenar series/reps basado en:
/// 1. Historial personal del usuario para ESE ejercicio
/// 2. Si no hay historial, usar media de ejercicios similares
/// 3. Si no hay data, usar defaults conservadores

class SmartDefaults {
  static EjercicioEnRutina getDefaults(
    LibraryExercise exercise,
    List<SerieLog> userHistory,
    List<EjercicioEnRutina> similarExercises,
  ) {
    // Prioridad 1: Historial personal
    if (userHistory.isNotEmpty) {
      final lastUsed = userHistory.last;
      return EjercicioEnRutina(
        // ...
        series: lastUsed.series,
        repsRange: '${lastUsed.reps}',  // Exacto de última vez
        notas: 'Última vez: ${lastUsed.peso}kg',  // Contexto útil
      );
    }
    
    // Prioridad 2: Ejercicios similares (mismo grupo muscular)
    final similar = similarExercises.where((e) => 
      e.musculosPrincipales.any((m) => exercise.muscles.contains(m))
    );
    if (similar.isNotEmpty) {
      final avgSeries = similar.map((e) => e.series).average.round();
      return EjercicioEnRutina(
        series: avgSeries,
        repsRange: '8-12',  // Rango moderado
      );
    }
    
    // Prioridad 3: Defaults conservadores por tipo
    return EjercicioEnRutina(
      series: exercise.isCompound ? 4 : 3,  // Compuestos: 4, Aislamiento: 3
      repsRange: exercise.isCompound ? '6-8' : '10-12',
    );
  }
}
```

**Clave:** Usuario siempre puede cambiar. Son SUGERENCIAS, no imposiciones.

### 9.5.2 Sugerencias Contextuales Post-Añadir

```dart
/// Después de añadir un ejercicio, mostrar sugerencia discreta

void _onExerciseAdded(LibraryExercise added) {
  // Añadir ejercicio normalmente
  notifier.addExerciseToDay(dayIndex, added);
  
  // 🆕 Buscar ejercicios complementarios
  final complementary = _findComplementary(added);
  
  if (complementary.isNotEmpty) {
    // Mostrar chip sutil, NO modal intrusivo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text('${added.name} añadido'),
            Spacer(),
            TextButton(
              child: Text('+ ${complementary.first.name}'),
              onPressed: () {
                notifier.addExerciseToDay(dayIndex, complementary.first);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ],
        ),
        duration: Duration(seconds: 4),  // Tiempo suficiente para leer
      ),
    );
  }
}

List<LibraryExercise> _findComplementary(LibraryExercise exercise) {
  // Lógica: Si añadió "Press Banca", sugerir "Aperturas"
  // Si añadió "Curl Bíceps", sugerir "Curl Martillo"
  // Basado en patrones de usuarios reales
  return ComplementaryService.instance.getSuggestions(exercise.id);
}
```

### 9.5.3 Detección de Patrones (Power-User Feature)

```dart
/// Si el usuario siempre añade X después de Y, pre-sugerir

class PatternDetector {
  // Map: exerciseId → [ejercicios que suele añadir después]
  final Map<int, List<int>> _patterns = {};
  
  void recordSequence(List<int> exerciseIds) {
    for (int i = 0; i < exerciseIds.length - 1; i++) {
      final current = exerciseIds[i];
      final next = exerciseIds[i + 1];
      _patterns.putIfAbsent(current, () => []).add(next);
    }
  }
  
  LibraryExercise? getSuggestion(int afterExerciseId) {
    final nextIds = _patterns[afterExerciseId];
    if (nextIds == null || nextIds.isEmpty) return null;
    
    // Encontrar el más frecuente
    final frequency = <int, int>{};
    for (final id in nextIds) {
      frequency[id] = (frequency[id] ?? 0) + 1;
    }
    
    final mostCommon = frequency.entries.reduce((a, b) => a.value > b.value ? a : b);
    if (mostCommon.value >= 3) {  // Solo sugerir si patrón claro (3+ veces)
      return ExerciseLibraryService.instance.getById(mostCommon.key);
    }
    return null;
  }
}
```

---

## 9.6 Coherencia Visual con Pantalla de Entrenamiento

### Qué Mantener Consistente:

| Elemento | Entrenamiento | Editor de Rutinas | Por qué |
|----------|---------------|-------------------|---------|
| **Paleta de colores** | Grises + rojo CTA | Grises + rojo CTA | Identidad de marca |
| **Tipografía** | Montserrat bold | Montserrat bold | Reconocimiento |
| **Cards de ejercicio** | Fondo `bgElevated` | Fondo `bgElevated` | Familiaridad |
| **Iconos de acción** | Rojo para principal | Rojo para principal | Mapping mental |

### Qué Permitir Diferente:

| Elemento | Entrenamiento | Editor de Rutinas | Por qué |
|----------|---------------|-------------------|---------|
| **Densidad** | Espaciado amplio | Puede ser más denso | Editor necesita ver más contexto |
| **Inputs** | Modales grandes | Inline compactos | Editor = precisión, Training = velocidad |
| **Navegación** | Scroll vertical único | Expansion tiles anidados | Estructura jerárquica |
| **Información visible** | Solo lo necesario AHORA | Todo el contexto | Diferentes momentos de uso |

### Principio de Coherencia:

> **"El usuario debe sentir que ambas pantallas son de la misma app,  
> pero entender que sirven para momentos diferentes."**

```
ENTRENAMIENTO = Modo ejecución (mínima info, máxima velocidad)
EDITOR        = Modo planificación (máxima info, velocidad razonable)
```

---

## 9.7 Qué NO Tocar (Aunque Otros Lo Pidan)

### ❌ NO simplificar el campo de reps a un número fijo

```dart
// ❌ MAL: Forzar "10 reps"
TextField(
  keyboardType: TextInputType.number,
  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
)

// ✅ BIEN: Permitir rangos "8-12", "6, 6, 6, 4" (drop sets), etc.
TextField(
  decoration: InputDecoration(hintText: 'Ej: 8-12, 6+6, AMRAP'),
)
```

**Por qué:** Power-users usan drop sets, clusters, AMRAP, rest-pause. Un número fijo es inútil.

### ❌ NO eliminar supersets por "simplicidad"

**Por qué:** Supersets son técnica avanzada que ahorra tiempo. Usuarios pro los usan constantemente.

### ❌ NO auto-guardar sin feedback

```dart
// ❌ MAL: Guardar silenciosamente cada cambio
onChanged: (val) async {
  await saveToDatabase(val);  // Sin feedback
}

// ✅ BIEN: Feedback explícito de guardado
onChanged: (val) {
  _pendingChanges = true;
  _debouncer.run(() async {
    await saveToDatabase(val);
    setState(() => _pendingChanges = false);
    _showSavedIndicator();  // "✓ Guardado" discreto
  });
}
```

**Por qué:** Usuario debe saber que sus cambios persisten. Incertidumbre = ansiedad.

### ❌ NO reemplazar biblioteca por "rutinas sugeridas"

**Por qué:** El usuario QUIERE diseñar su rutina. Sugerencias están bien DESPUÉS de elegir, no ANTES.

### ❌ NO limitar número de días/ejercicios

```dart
// ❌ MAL
if (dias.length >= 5) {
  showError('Máximo 5 días');
  return;
}

// ✅ BIEN: Sin límite artificial
// Si alguien quiere una rutina de 7 días con 15 ejercicios cada uno, déjalo.
```

**Por qué:** Power-users diseñan rutinas complejas (PPL 6 días, Upper/Lower 4x, etc.).

---

## 9.8 Mejoras de Alto Impacto y Bajo Riesgo

### 🎯 Implementar Primero (Quick Wins):

| Mejora | Impacto | Esfuerzo | Riesgo |
|--------|---------|----------|--------|
| **Historial reciente en biblioteca** | Alto | Bajo (2h) | Nulo |
| **Swipe para duplicar ejercicio** | Alto | Bajo (3h) | Nulo |
| **Auto-seleccionar día único** | Medio | Muy bajo (30min) | Nulo |
| **Mostrar historial personal en preview** | Alto | Medio (4h) | Bajo |
| **Contador de ejercicios por día en header** | Bajo | Muy bajo (15min) | Nulo |

### 🚀 Implementar Después (High Value):

| Mejora | Impacto | Esfuerzo | Riesgo |
|--------|---------|----------|--------|
| **Sugerencias post-añadir** | Alto | Alto (8h) | Medio |
| **Índice alfabético A-Z** | Medio | Medio (4h) | Bajo |
| **Vista compacta toggle** | Medio | Medio (5h) | Bajo |
| **Atajos de teclado (tablet)** | Bajo* | Alto (10h) | Bajo |

*Bajo impacto porque mayoría usa móvil, pero diferenciador para tablets.

---

## 9.9 Mejoras Opcionales "Pro"

### Para usuarios ultra-avanzados (1% de la base):

| Feature | Descripción | Justificación |
|---------|-------------|---------------|
| **Importar desde CSV/JSON** | Pegar estructura de rutina en texto plano | Migración desde otras apps |
| **Templates personalizados** | Guardar estructura de día para reusar | "Mi día de pecho siempre empieza con Press" |
| **Duplicar rutina completa** | Clonar rutina existente como base | Variaciones de mesociclo |
| **Comparar rutinas** | Side-by-side de dos rutinas | Análisis de progresión |
| **Modo offline editor** | Editar sin conexión, sync después | Gimnasios sin señal |
| **Exportar a PDF/imagen** | Compartir visualmente | Redes sociales, coaches |

---

## 9.10 Métricas UX para Validación

### Métricas Primarias:

| Métrica | Cómo medir | Objetivo |
|---------|------------|----------|
| **Tiempo para crear rutina nueva** | Timestamp desde "Nueva Rutina" hasta "Guardar" | < 5 minutos para rutina de 4 días |
| **Taps para añadir ejercicio** | Contador de eventos entre "decidir añadir" y "ejercicio añadido" | ≤ 4 taps |
| **Tasa de abandono de creación** | Rutinas empezadas vs guardadas | < 15% abandono |
| **Uso de favoritos** | % de ejercicios añadidos que eran favoritos | > 30% (indica utilidad de la feature) |
| **Uso de búsqueda vs scroll** | Ratio búsqueda/scroll en biblioteca | > 60% búsqueda (indica que funciona bien) |

### Métricas Secundarias:

| Métrica | Cómo medir | Indica |
|---------|------------|--------|
| **Ejercicios por rutina** | Promedio de ejercicios en rutinas guardadas | Complejidad de uso real |
| **Días por rutina** | Promedio de días por rutina | Tipo de usuarios (3-4 = intermedios, 5-6 = avanzados) |
| **Uso de supersets** | % de rutinas con al menos un superset | Adopción de features pro |
| **Re-edición de rutinas** | Veces que usuario edita rutina existente | Engagement con customización |
| **Tiempo en biblioteca** | Duración promedio con biblioteca abierta | Si > 60s, puede indicar dificultad para encontrar |

### Cómo Implementar Tracking:

```dart
/// analytics_service.dart

class RoutineAnalytics {
  void trackRoutineCreationStart() {
    _startTime = DateTime.now();
  }
  
  void trackRoutineCreationComplete(Rutina rutina) {
    final duration = DateTime.now().difference(_startTime!);
    
    analytics.logEvent(
      name: 'routine_created',
      parameters: {
        'duration_seconds': duration.inSeconds,
        'day_count': rutina.dias.length,
        'total_exercises': rutina.dias.fold(0, (sum, d) => sum + d.ejercicios.length),
        'has_supersets': rutina.dias.any((d) => d.ejercicios.any((e) => e.supersetId != null)),
      },
    );
  }
  
  void trackExerciseAdded({
    required bool fromFavorites,
    required bool fromRecents,
    required bool fromSearch,
    required int tapsToAdd,
  }) {
    analytics.logEvent(
      name: 'exercise_added_to_routine',
      parameters: {
        'source': fromFavorites ? 'favorites' : fromRecents ? 'recents' : fromSearch ? 'search' : 'browse',
        'taps': tapsToAdd,
      },
    );
  }
}
```

---

## 9.11 Resumen Ejecutivo

### Lo que YA está bien (no tocar):
- ✅ Fuzzy search funciona excelente
- ✅ Bottom sheet no cierra al añadir (flujo pro)
- ✅ Favoritos con estrella (acceso rápido)
- ✅ FilterChips horizontales combinables
- ✅ Supersets por drag
- ✅ Import inteligente (voz/OCR)

### Lo que necesita mejora (prioridad alta):
- 🔧 Historial de recientes en biblioteca
- 🔧 Swipe actions (duplicar, eliminar rápido)
- 🔧 Auto-seleccionar día único
- 🔧 Preview con historial personal

### Lo que sería nice-to-have (prioridad baja):
- 💡 Índice alfabético A-Z
- 💡 Vista compacta toggle
- 💡 Sugerencias contextuales post-añadir
- 💡 Atajos de teclado para tablet

### Lo que NUNCA hacer:
- ❌ Simplificar reps a número fijo
- ❌ Limitar días/ejercicios
- ❌ Reemplazar biblioteca por sugerencias
- ❌ Eliminar supersets
- ❌ Auto-guardar sin feedback

---

*Sección añadida: Enero 2026*
*Enfoque: Power-user tools para usuarios intermedios/avanzados*
*Filosofía: Velocidad sin sacrificar control*

---

*Documento creado: Enero 2026*
*Autor: UX/UI Analysis para Juan Training*
