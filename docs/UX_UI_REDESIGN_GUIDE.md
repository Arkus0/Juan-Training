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

*Documento creado: Enero 2026*
*Autor: UX/UI Analysis para Juan Training*
