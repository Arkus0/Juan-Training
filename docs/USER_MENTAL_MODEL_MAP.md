# MAPA DEL MODELO MENTAL DEL USUARIO

## Juan Training App - Análisis de UX

---

## 1. MODELO MENTAL ESPERADO vs REALIDAD

### TAB "ENTRENAR"

| Elemento | Lo que el usuario CREE | Lo que REALMENTE hace | Divergencia |
|----------|------------------------|----------------------|-------------|
| Botón "COMENZAR ENTRENAMIENTO" | Empieza a entrenar inmediatamente | Correcto | ✅ Alineado |
| FAB con nombre del día (ej: "LUNES") | ¿Es información o un botón? | Es un botón que inicia ese día | ⚠️ **DIVERGENCIA** |
| "ELIGE TU ENTRENO" | Abre lista de opciones | Muestra días alternativos | ✅ Alineado |
| Icono del rayo (⚡) | ¿Power mode? ¿Intensidad? | Indica sugerencia inteligente de la app | ⚠️ **DIVERGENCIA** |

### TAB "RUTINAS"

| Elemento | Lo que el usuario CREE | Lo que REALMENTE hace | Divergencia |
|----------|------------------------|----------------------|-------------|
| "MIS RUTINAS" | Ver mis rutinas | Correcto | ✅ Alineado |
| FAB "NUEVA RUTINA" | Crear rutina nueva | Correcto | ✅ Alineado |
| Swipe izquierda en tarjeta | ¿Qué pasa? No es obvio | Elimina la rutina | ⚠️ **DIVERGENCIA** |
| Ícono menú (⋮) | Opciones de la app | Solo tiene "Importar Rutina" | ✅ Alineado |

### TAB "ANÁLISIS"

| Elemento | Lo que el usuario CREE | Lo que REALMENTE hace | Divergencia |
|----------|------------------------|----------------------|-------------|
| "BITÁCORA" | ¿Un diario? ¿Notas? | Lista de sesiones pasadas | ⚠️ **DIVERGENCIA** |
| "LABORATORIO" | ¿Experimentos? ¿Pruebas? | Gráficos y estadísticas | ⚠️ **DIVERGENCIA** |
| "ANÁLISIS" (tab name) | Ver estadísticas | Correcto pero muy genérico | ⚠️ Mejorable |
| Icono `insights` | Información/datos | Correcto | ✅ Alineado |

### TAB "AJUSTES"

| Elemento | Lo que el usuario CREE | Lo que REALMENTE hace | Divergencia |
|----------|------------------------|----------------------|-------------|
| "Timer en pantalla bloqueada" | ¿Timer se bloquea? | Timer visible en lockscreen | ⚠️ **DIVERGENCIA** |

### PANTALLA DE SESIÓN

| Elemento | Lo que el usuario CREE | Lo que REALMENTE hace | Divergencia |
|----------|------------------------|----------------------|-------------|
| Icono micrófono (🎤) | ¿Grabar mi entreno? | Comandos de voz para registrar series | ⚠️ **DIVERGENCIA** |
| Icono cadena/link (🔗) | ¿Compartir? ¿URL? | Vincular ejercicios en superserie | ⚠️ **DIVERGENCIA** |
| "TERMINAR" | Terminar y guardar | Correcto | ✅ Alineado |
| Icono swap (↔️) | ¿Intercambiar algo? | Ver ejercicios alternativos | ⚠️ **DIVERGENCIA** |

### CREAR/EDITAR RUTINA

| Elemento | Lo que el usuario CREE | Lo que REALMENTE hace | Divergencia |
|----------|------------------------|----------------------|-------------|
| "RUTINA FORJADA" (snackbar) | ¿Algo especial pasó? | Solo significa "guardada" | ⚠️ **DIVERGENCIA** |
| Icono scanner (📄) | ¿Escanear código QR? | Importar rutina de foto/documento | ⚠️ **DIVERGENCIA** |
| "ARSENAL DE EJERCICIOS" | ¿Zona de combate? | Biblioteca de ejercicios | ⚠️ **DIVERGENCIA** |
| "LEGADO DE BATALLA" | ¿Logros? ¿Medallas? | Historial de sesiones | ⚠️ **DIVERGENCIA** |

---

## 2. PROBLEMAS IDENTIFICADOS

### 🔴 CRÍTICOS (Confunden al usuario)

1. **Terminología militar/épica excesiva**
   - "LEGADO DE BATALLA" → El usuario no entiende que es historial
   - "ARSENAL DE EJERCICIOS" → El usuario busca "ejercicios" no "arsenal"
   - "RUTINA FORJADA" → Simple "Guardado" es más claro
   - "Tu leyenda comienza..." → Demasiado dramático

2. **Iconos sin contexto claro**
   - Icono de rayo (⚡) para sugerencia → No es intuitivo
   - Icono de cadena (🔗) para superserie → Parece "compartir"
   - Icono de swap (↔️) para alternativas → Parece "intercambiar orden"

3. **Labels de tabs en ANÁLISIS**
   - "BITÁCORA" → Demasiado abstracto para "historial de sesiones"
   - "LABORATORIO" → Demasiado técnico para "estadísticas"

### 🟡 MODERADOS (Causan fricción)

1. **FAB con nombre del día** → No es obvio que es un botón
2. **Swipe para eliminar** sin indicador visual
3. **"Timer en pantalla bloqueada"** → Ambiguo

### 🟢 MENORES (Mejoras opcionales)

1. Tooltip del micrófono debería decir "Dictado de series"
2. Icono del escáner necesita label "Importar de foto"

---

## 3. CAMBIOS PROPUESTOS

### CAMBIOS DE TEXTO

| Actual | Propuesto | Razón |
|--------|-----------|-------|
| "LEGADO DE BATALLA" | "HISTORIAL" | Más directo |
| "ARSENAL DE EJERCICIOS" | "EJERCICIOS" | Más simple |
| "RUTINA FORJADA" | "RUTINA GUARDADA" | Más claro |
| "Tu leyenda comienza con el primer entreno" | "Aún no hay entrenamientos" | Más informativo |
| "BITÁCORA" | "HISTORIAL" | Más común |
| "LABORATORIO" | "ESTADÍSTICAS" | Más descriptivo |
| "Timer en pantalla bloqueada" | "Mostrar en pantalla de bloqueo" | Más claro |
| "¡CREA TU LEGADO AHORA!" | "Crea tu primera rutina" | Más directo |
| "SIN HISTORIAL" | "SIN ENTRENAMIENTOS" | Más específico |

### CAMBIOS DE ICONOS

| Ubicación | Actual | Propuesto | Razón |
|-----------|--------|-----------|-------|
| Sugerencia de día | `Icons.bolt_rounded` (rayo) | `Icons.recommend` o `Icons.auto_awesome` | Indica "sugerido por IA" |
| Superserie link | `Icons.link` | `Icons.join_full` o badge visual | Más claro para "unir ejercicios" |
| Ver alternativas | `Icons.swap_horiz` | `Icons.swap_vert` + tooltip | Mantener pero agregar tooltip claro |
| Importar OCR | `Icons.document_scanner` | Agregar label "De foto" | El icono está bien pero necesita contexto |

### CAMBIOS DE FLUJO

1. **FAB de día sugerido** → Agregar label pequeño "Iniciar" debajo del nombre
2. **Swipe para eliminar** → Mostrar hint visual la primera vez
3. **Micrófono en sesión** → Tooltip: "Dictar series (ej: 80kg, 10 reps)"

---

## 4. MATRIZ DE MODELO MENTAL SIMPLIFICADO

```
USUARIO QUIERE:              APP DEBE MOSTRAR:
─────────────────────────────────────────────────
"Ver mis rutinas"        →   Tab RUTINAS ✅
"Entrenar ahora"         →   Tab ENTRENAR + sugerencia prominente ✅
"Ver mi progreso"        →   Tab ANÁLISIS → HISTORIAL (antes BITÁCORA)
"Ver estadísticas"       →   Tab ANÁLISIS → ESTADÍSTICAS (antes LABORATORIO)
"Crear rutina"           →   FAB "NUEVA RUTINA" ✅
"Buscar ejercicio"       →   Biblioteca → "EJERCICIOS" (antes ARSENAL)
"Ver entrenamientos"     →   "HISTORIAL" (antes LEGADO DE BATALLA)
"Unir ejercicios"        →   Icono más descriptivo + tooltip "Crear superserie"
"Cambiar ejercicio"      →   "Ver alternativas" + tooltip claro
```

---

## 5. PRINCIPIO GUÍA

> **El modelo mental más simple es aquel donde cada elemento hace exactamente lo que su nombre sugiere, sin metáforas ni lenguaje figurativo.**

### Antes (Épico/Confuso):
- "FORJA TU LEGADO EN EL ARSENAL DE BATALLA"

### Después (Simple/Claro):
- "Crea tu rutina y busca ejercicios"

---

## 6. RESUMEN DE IMPLEMENTACIÓN

### Archivos modificados:

| Archivo | Cambio |
|---------|--------|
| `lib/screens/history_screen.dart` | "LEGADO DE BATALLA" → "HISTORIAL" |
| `lib/screens/analysis_screen.dart` | "BITÁCORA" → "HISTORIAL", "LABORATORIO" → "ESTADÍSTICAS" |
| `lib/screens/search_exercise_screen.dart` | "ARSENAL DE EJERCICIOS" → "BUSCAR EJERCICIO" |
| `lib/screens/rutinas_screen.dart` | "¡CREA TU LEGADO AHORA!" → "Crea tu primera rutina para empezar" |
| `lib/screens/create_edit_routine_screen.dart` | "RUTINA FORJADA" → "RUTINA GUARDADA" |
| `lib/widgets/analysis/session_list_view.dart` | Mensaje épico → descriptivo |
| `lib/screens/create_routine/widgets/biblioteca_bottom_sheet.dart` | "BIBLIOTECA DEL DOLOR" → "EJERCICIOS" |
| `lib/screens/settings_screen.dart` | "Timer en pantalla bloqueada" → "Mostrar en pantalla de bloqueo" |
| `lib/screens/train_selection_screen.dart` | Icono rayo → icono recomendación |
| `lib/widgets/voice/voice_training_button.dart` | Tooltip mejorado para comando de voz |
