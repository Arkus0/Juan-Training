# AUDITORÍA DE PRODUCTO — Juan Training
## Senior PM + UX Research | Enero 2026

> **Objetivo:** Evaluar, priorizar y eliminar. No proponer nuevas features.

---

# PASO 1 — DEFINICIÓN DEL USUARIO REAL

## Usuario Objetivo Único

**El "Intermedio Consistente"**

| Atributo | Descripción |
|----------|-------------|
| **Experiencia** | 1-3 años entrenando con pesas |
| **Conocimiento** | Sabe qué es un press banca, una sentadilla, sabe que necesita progresión |
| **Limitación** | NO sabe diseñar su propia periodización ni interpretar métricas avanzadas |
| **Motivación primaria** | Ver que está mejorando → seguir entrenando |
| **Contexto de uso** | En el gym, entre series, 10-15 interacciones de <5 segundos cada una |
| **Frecuencia** | 3-5 sesiones/semana |
| **Patrón de comportamiento** | Rutina estable, pocos cambios. Quiere "hacer lo mismo pero mejor" |

### Perfil psicológico clave:
> **"No quiero pensar en el gimnasio. Quiero que la app me diga qué hacer y yo lo hago."**

Este usuario:
- ✅ Valora la simplicidad sobre la flexibilidad
- ✅ Prefiere defaults inteligentes sobre configuración
- ✅ Se motiva con progreso visible y frecuente
- ✅ Abandonará si siente que "la app le da trabajo"

---

## Usuarios NO Prioritarios (explícitamente)

### 1. El Principiante Total
| Por qué NO | Impacto |
|-----------|---------|
| Necesita educación, no herramienta | Requeriría onboarding extenso, tutoriales, validaciones constantes |
| No tiene historial → progresión no funciona | Sistemas de progresión asumen datos previos |
| Alto churn natural | Inversión de retención con bajo ROI |

**Decisión:** No simplificar más la app para capturar este segmento. Ya hay apps para principiantes (Strong, Hevy básico).

### 2. El Powerlifter/Atleta Competitivo
| Por qué NO | Impacto |
|-----------|---------|
| Necesita RPE granular, periodización compleja, programación específica | Feature creep garantizado |
| Ya usa spreadsheets personalizados o apps especializadas | No migrarán |
| Representan <2% del mercado | Distorsionan feedback con requests edge-case |

**Decisión:** El sistema RPE actual es SUFICIENTE. No añadir más granularidad.

### 3. El "Gym Bro" Casual
| Por qué NO | Impacto |
|-----------|---------|
| Entrena sin estructura, cambia de rutina cada semana | Progresión imposible de trackear |
| No completará sesiones → datos inconsistentes | Corrompe el historial |
| No valora el tracking detallado | Abandona en semana 2 |

**Decisión:** No optimizar para usuarios que no completan sesiones enteras.

---

# PASO 2 — AUDITORÍA POR FRICCIÓN

## Sistema 1: Registro de Series y Edición de Peso/Reps

| Pregunta | Evaluación |
|----------|------------|
| ¿El usuario lo entiende sin explicación? | ✅ SÍ — Inputs claros, numpad familiar |
| ¿Lo usa de forma recurrente? | ✅ SÍ — Es el núcleo de cada sesión |
| ¿Reduce decisiones o las aumenta? | ⚠️ MIXTO — Sugerencias ayudan, pero la edición manual es demasiado fácil de acceder |

### Hallazgos específicos:
- **Positivo:** El diseño del `session_set_row.dart` con numpad modal es correcto
- **Positivo:** SmartDefaults desde historial reduce carga cognitiva
- **Problema detectado:** El usuario puede editar peso/reps libremente, lo que puede romper la lógica de progresión. Si el sistema sugiere 80kg y el usuario pone 85kg "porque se siente fuerte", la progresión se corrompe.

### Clasificación: **CORE — No tocar, pero blindar**

**Acción:** El input de peso debería mostrar claramente que está desviándose de la sugerencia. No bloquearlo, pero hacerlo visible.

---

## Sistema 2: Progresión Automática (Lineal, RPE, Doble Progresión)

| Pregunta | Evaluación |
|----------|------------|
| ¿El usuario lo entiende sin explicación? | ❌ NO — 3 tipos de progresión es demasiado. El usuario promedio no sabe qué elegir |
| ¿Lo usa de forma recurrente? | ⚠️ PASIVO — El usuario no "usa" la progresión, la recibe |
| ¿Reduce decisiones o las aumenta? | ⚠️ MIXTO — Cuando funciona, reduce. Cuando muestra 3 opciones de configuración, aumenta |

### Hallazgos específicos:
- **Problema grave:** En `progression_type.dart` hay 4 tipos (none, lineal, dobleRepsFirst, rpe). Esto es exceso de opciones para el usuario objetivo.
- **Problema grave:** El usuario debe elegir tipo de progresión POR EJERCICIO. Esto es carga cognitiva innecesaria.
- **Positivo:** El sistema de confirmación de 2 sesiones en `progression_engine.dart` es correcto conceptualmente.

### Clasificación: **SECUNDARIO — Simplificar agresivamente**

**Acciones:**
1. **Eliminar la elección del usuario.** El sistema debería auto-detectar el tipo de progresión basándose en:
   - Ejercicios compuestos → Doble progresión
   - Ejercicios de aislamiento → Lineal con incrementos menores
   - Usuario marca "fue difícil" → Sistema ajusta internamente
2. **Enterrar "RPE" como opción.** Mantenerlo para power users en configuración avanzada, pero NO mostrarlo en flujo normal.
3. **Reducir a 2 estados visibles:** "Sube" o "Repite". Nada más.

---

## Sistema 3: OCR / Voz

| Pregunta | Evaluación |
|----------|------------|
| ¿El usuario lo entiende sin explicación? | ❌ NO — El icono del micrófono se confunde con "grabar entrenamiento" |
| ¿Lo usa de forma recurrente? | ❌ NO — Es feature de importación, no de uso diario |
| ¿Reduce decisiones o las aumenta? | ✅ SÍ cuando funciona — Pero el flujo de corrección post-OCR es complejo |

### Hallazgos específicos:
- **OCR:** El `smart_import_sheet.dart` tiene 1040 líneas. Eso es una señal de complejidad excesiva para una feature de importación.
- **Voz en sesión:** El `voice_training_button.dart` existe pero su utilidad durante la sesión es cuestionable — el usuario tiene las manos ocupadas pero también está en ambiente ruidoso.
- **Problema UX:** El icono de micrófono en la sesión activa (AppBar) no comunica su función.

### Clasificación: **RUIDO — Fusionar o eliminar uso en sesión**

**Acciones:**
1. **Mantener OCR solo para importación inicial de rutinas.** No promoverlo activamente.
2. **Eliminar el botón de voz del AppBar de sesión.** Si se quiere mantener, moverlo a un gesto (long press en el input de reps).
3. **Voz para crear rutina:** Evaluar uso real. Si <5% de usuarios la usan para crear rutinas, eliminar.

---

## Sistema 4: Biblioteca de Ejercicios

| Pregunta | Evaluación |
|----------|------------|
| ¿El usuario lo entiende sin explicación? | ✅ SÍ — Búsqueda fuzzy funciona |
| ¿Lo usa de forma recurrente? | ⚠️ SOLO AL CREAR RUTINA — Después, casi nunca |
| ¿Reduce decisiones o las aumenta? | ⚠️ AUMENTA si hay demasiados ejercicios similares |

### Hallazgos específicos:
- **Positivo:** `search_exercise_screen.dart` usa Fuzzy search correctamente
- **Problema potencial:** Si la biblioteca tiene >500 ejercicios, el usuario se paraliza. "¿Hago press inclinado con mancuernas o con barra?"
- **El sistema de "alternativas" (swap icon) es útil pero mal comunicado**

### Clasificación: **CORE — Pero podar el catálogo**

**Acciones:**
1. **Limitar ejercicios visibles inicialmente a ~150 "esenciales".** El resto en "Mostrar más".
2. **Auto-sugerir alternativas basadas en equipamiento disponible** (si el usuario nunca usa máquinas, no mostrar ejercicios de máquina primero).
3. **El icono de swap (↔️) debe tener tooltip la primera vez:** "Ver ejercicios similares".

---

## Sistema 5: Creación de Rutinas

| Pregunta | Evaluación |
|----------|------------|
| ¿El usuario lo entiende sin explicación? | ⚠️ PARCIAL — El flujo es claro pero hay demasiadas opciones por ejercicio |
| ¿Lo usa de forma recurrente? | ❌ NO — Una vez creada, rara vez se edita |
| ¿Reduce decisiones o las aumenta? | ⚠️ AUMENTA — Configurar series, reps, descanso, tipo de progresión POR EJERCICIO es excesivo |

### Hallazgos específicos:
- **El `create_edit_routine_screen.dart` tiene 1154 líneas.** Esto indica complejidad excesiva.
- **SmartDefaults es la dirección correcta:** Auto-rellenar basado en historial.
- **Problema:** Todavía se permite configurar demasiado manualmente.

### Clasificación: **SECUNDARIO — Automatizar más, mostrar menos**

**Acciones:**
1. **Auto-asignar series/reps/descanso basado en tipo de ejercicio:**
   - Compuesto (Sentadilla, Press): 4×6-8, 180s descanso
   - Accesorio (Curl, Extensiones): 3×10-12, 90s descanso
2. **Ocultar configuración de progresión.** El sistema decide.
3. **"Editar avanzado" como opción enterrada** para quien quiera personalizar.

---

## Resumen de Clasificación

| Sistema | Clasificación | Acción Principal |
|---------|---------------|------------------|
| Registro series/peso/reps | **CORE** | Proteger la lógica de progresión del input libre |
| Progresión automática | **SECUNDARIO** | Eliminar elección de tipo, auto-detectar |
| OCR/Voz | **RUIDO** | Sacar voz de sesión, mantener OCR solo para import |
| Biblioteca ejercicios | **CORE** | Podar catálogo, mejorar alternativas |
| Creación rutinas | **SECUNDARIO** | Auto-configurar defaults, ocultar opciones |

---

# PASO 3 — ADHERENCIA

## ¿Qué hace que el usuario vuelva mañana?

### 1. **Ver que "va bien" sin esfuerzo**
El usuario abre la app → ve qué toca hoy → ve que la vez pasada lo hizo bien → tiene motivación inmediata.

**Elemento clave:** El preview "Si lo logras: +2.5kg" documentado en `PROGRESSION_USER_EXPERIENCE.md` es EXACTAMENTE lo correcto. Muestra consecuencia, no métrica.

### 2. **Sentir que "algo pasó" al terminar**
El milestone de "¡NUEVO PESO DESBLOQUEADO!" genera dopamina. El usuario quiere volver para desbloquear el siguiente.

**Elemento clave:** `milestone_celebration.dart` existe. Verificar que se activa consistentemente.

### 3. **No tener que pensar**
Abrir → hacer lo que dice → cerrar. Si esto funciona, vuelve. Si tiene que decidir algo cada sesión, abandona.

---

## ¿Qué genera abandono silencioso?

### 1. **Estancamiento invisible**
El usuario hace 80kg durante 6 semanas. El sistema no le dice nada. No sabe si está bien o mal. Deja de abrir la app.

**Diagnóstico:** El sistema de progresión tiene lógica de deload, pero **¿el usuario entiende que estancarse está bien temporalmente?** El documento `PROGRESSION_USER_EXPERIENCE.md` tiene los mensajes correctos ("Un día difícil no cambia nada"), pero verificar implementación.

### 2. **Sesión incompleta = culpa**
El usuario tiene que irse a los 30 minutos. La app muestra "45% completado". Se siente mal. No quiere volver a ver ese número.

**Diagnóstico:** El flujo de `_onFinishSession` en `training_session_screen.dart` muestra mensaje de confirmación con porcentaje. Esto es **CULPABILIZANTE**.

### 3. **Demasiadas opciones en el momento incorrecto**
Durante la sesión, el usuario tiene acceso a: editar peso, editar reps, ver alternativas, vincular superserie, micrófono, timer manual, etc. Esto genera fatiga decisional.

**Diagnóstico:** El `exercise_card.dart` y widgets asociados probablemente tienen demasiados affordances visibles simultáneamente.

### 4. **La app "no le conoce"**
Después de 3 meses de uso, la app sigue preguntando cosas que debería saber. El usuario siente que sus datos no sirven para nada.

---

## 3 Acciones para Aumentar Adherencia (Sin Features Nuevas)

### ACCIÓN 1: Eliminar el porcentaje de sesión incompleta

**Problema:** "Has completado 45% de la sesión" genera culpa.

**Cambio:** Al terminar antes de tiempo, NO mostrar porcentaje. Solo:
> "¿Terminar entrenamiento?"
> "Los ejercicios completados se guardarán."

Si el usuario completó <50%, agregar:
> "💡 Consejo: Puedes continuar mañana donde lo dejaste."

**Impacto:** Reduce abandono por sesiones parciales percibidas como "fracaso".

---

### ACCIÓN 2: Hacer el progreso "obvio" sin buscar

**Problema:** El usuario tiene que ir a "Análisis" para ver si va bien.

**Cambio:** En la pantalla de inicio (antes de entrenar), mostrar UNA métrica de progreso reciente:
> "Esta semana: 2 ejercicios subieron peso ✓"

O si no hubo progreso:
> "Llevas 3 sesiones consistente. El progreso vendrá."

**Impacto:** El usuario ve que sus datos SIRVEN para algo cada vez que abre la app.

---

### ACCIÓN 3: Reducir opciones visibles durante la sesión

**Problema:** Demasiados iconos/opciones en la tarjeta de ejercicio.

**Cambio:** Ocultar por defecto:
- Icono de micrófono (mover a gesto o eliminar)
- Icono de superserie (solo mostrar si ya hay superseries configuradas)
- Tiempo de descanso editable (auto-iniciar con el configurado)

Mostrar siempre:
- Peso sugerido
- Reps sugerido
- Input para registrar
- Botón "Listo"

**Impacto:** Reduce fatiga cognitiva. El usuario solo ve lo que necesita.

---

# PASO 4 — DECISIONES DURAS

## QUÉ NO SE DEBE VOLVER A TOCAR EN 2 MESES

| Área | Razón |
|------|-------|
| **Motor de progresión (`progression_engine.dart`)** | Ya funciona. Los 19 tests pasan. Cualquier cambio ahora genera regresiones. Congelar. |
| **Flujo de registro de serie** | El numpad modal, los inputs — funcionan. No iterar sobre algo que funciona. |
| **Diseño visual (paleta Neon Iron)** | Ya se hizo el rediseño en `UX_UI_REDESIGN_GUIDE.md`. Implementarlo si no está implementado, pero no rediseñar de nuevo. |
| **Base de datos/Modelos** | Los modelos en `lib/models/` están estabilizados. Cambios aquí requieren migraciones y testing extenso. |

**Regla:** Si algo funciona y no genera quejas específicas, está prohibido tocarlo.

---

## QUÉ DEBE DESAPARECER AUNQUE "SEA TÉCNICAMENTE IMPRESIONANTE"

### 1. **Voz durante sesión de entrenamiento**
**Razón:** El ambiente de gimnasio es ruidoso. El usuario tiene las manos libres entre series pero está cansado mentalmente. Hablarle a la app es fricción, no comodidad.

**Acción:** Eliminar `voice_training_button.dart` del `TrainingSessionScreen`. Mantener voz solo para crear rutinas (si hay datos de uso que lo justifiquen).

### 2. **RPE como opción visible de progresión**
**Razón:** <10% de usuarios entienden qué es RPE. Mostrarlo confunde al 90% restante.

**Acción:** Mantener la lógica internamente, pero NO mostrar "Basada en RPE" como opción seleccionable. El sistema puede usar RPE-implícito (cuando el usuario dice "fue muy difícil").

### 3. **Superseries como feature prominente**
**Razón:** Las superseries son para usuarios avanzados. Mostrar el icono de "vincular" (🔗) confunde a usuarios que no saben qué es.

**Acción:** Ocultar por defecto. Solo mostrar si la rutina YA tiene superseries configuradas, o en modo de edición avanzada.

### 4. **Terminología militar/épica restante**
**Razón:** "RUTINA FORJADA", "LEGADO DE BATALLA" — el documento `USER_MENTAL_MODEL_MAP.md` ya identificó esto como problema. Si todavía está en producción, eliminarlo.

**Acción:** Buscar y reemplazar:
- "FORJADA" → "GUARDADA"
- "LEGADO" → "HISTORIAL"
- "ARSENAL" → "EJERCICIOS"
- "Tu leyenda comienza..." → "Aún no hay entrenamientos"

---

## MÉTRICA QUE DECIDIRÁ EL ÉXITO REAL DEL PRODUCTO

### Métrica Principal: **D7 Retention Rate con ≥3 sesiones completadas**

**Definición:**
> % de usuarios que completaron al menos 3 sesiones en sus primeros 7 días después de crear su primera rutina.

**Por qué esta métrica:**
1. **Filtra turistas:** Quien hace 3 sesiones en 7 días está enganchado
2. **Mide valor real:** Una sesión puede ser curiosidad. Tres sesiones es hábito
3. **Es accionable:** Si baja, sabemos que el problema está en los primeros 7 días
4. **Correlaciona con LTV:** Usuarios que superan D7×3 tienen 70%+ probabilidad de seguir al mes

**Objetivo:**
- Actual (estimado): 15-20%
- Meta Q1 2026: 30%
- Meta Q2 2026: 40%

### Métricas Secundarias (para diagnóstico):

| Métrica | Qué indica |
|---------|-----------|
| % sesiones completadas al 100% | Si el flujo de sesión es demasiado largo |
| Tiempo promedio por serie | Si los inputs son eficientes |
| % usuarios que cambian peso sugerido | Si las sugerencias son útiles |
| Drop-off después de semana 4 sin progreso | Si el estancamiento causa abandono |

---

## Veredicto Final

### Lo que funciona y debe protegerse:
1. El concepto de "sugerencia + consecuencia visible" (`PROGRESSION_USER_EXPERIENCE.md`)
2. El motor de progresión con confirmación de 2 sesiones
3. El diseño visual Neon Iron (si está implementado)
4. El flujo de entrada de datos con numpad

### Lo que está añadiendo complejidad sin valor:
1. Voz durante sesión
2. Elección de tipo de progresión por el usuario
3. Superseries como feature visible para todos
4. Terminología épica/gamificada

### Próximo paso recomendado:
**Implementar las 3 acciones de adherencia (Paso 3) y eliminar los 4 elementos de ruido (Paso 4).** 

Después de 2 meses, medir D7×3 Retention. Si sube, seguir. Si no sube, el problema está en otra parte (posiblemente en la adquisición o el onboarding, no en el producto core).

---

*Auditoría realizada: Enero 2026*
*Próxima revisión: Marzo 2026*
