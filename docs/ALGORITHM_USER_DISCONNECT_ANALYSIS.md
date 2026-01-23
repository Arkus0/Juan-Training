# 🔌 Análisis de Desconexión: Algoritmo ↔ Usuario

## Resumen Ejecutivo

| Aspecto | Algoritmo Decide | Usuario Cree | Conflicto |
|---------|------------------|--------------|-----------|
| **Cuándo subir peso** | 2 sesiones consecutivas exitosas | 1 sesión buena = subir | ⚠️ ALTO |
| **Qué es "éxito"** | ≥80% sets completos | Todas las series hechas | ⚠️ MEDIO |
| **Incremento de peso** | Variable por ejercicio (1.25-2.5kg) | Siempre 2.5kg | ⚠️ MEDIO |
| **Días malos** | No cambian nada (1er fallo) | "Perdí mi progreso" | ⚠️ ALTO |
| **Bajada de peso** | Tras 2 sesiones malas | Castigo por fallar | ⚠️ ALTO |

---

## 🔍 PUNTO 1: Confirmación de 2 Sesiones

### Lo que decide el algoritmo
```
Si (sesión_actual == COMPLETA && reps >= max_rango):
  Si (sesión_anterior TAMBIÉN fue COMPLETA en max_reps):
    → SUBIR PESO ✅
  Sino:
    → REPETIR (esperando confirmación)
```

### Lo que cree el usuario
> "Hice todas mis series a 12 reps, ¿por qué no sube el peso?"

### Momento de sorpresa negativa
- **Cuándo**: Primera sesión perfecta a reps máximas
- **Qué ve**: "Repite 80kg × 12. Si lo logras, subirás peso."
- **Qué esperaba**: "+2.5kg"

### Solución implementada ✅
```dart
userMessage: 'Repite ${weight}kg × $maxReps. Si lo logras, subirás peso.',
nextStepPreview: 'Si éxito: ${weight + increment}kg × $minReps',
```

### Mejora adicional sugerida
**Comunicación visual del estado de confirmación:**

```
┌─────────────────────────────────────────┐
│  🔄 CONFIRMANDO (1/2)                   │
│                                         │
│  80kg × 12                              │
│  ▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░ 50%              │
│                                         │
│  Próximo éxito → 82.5kg × 8             │
└─────────────────────────────────────────┘
```

---

## 🔍 PUNTO 2: Definición de "Éxito"

### Lo que decide el algoritmo
```dart
SessionResult.evaluate():
  100% sets OK → complete
  ≥80% sets OK → acceptable  
  50-79% → partial
  <50% → failed
```

### Lo que cree el usuario
> "Hice 3/4 series bien, ¿eso cuenta?"

### Datos ocultos al usuario
- El umbral 80% es invisible
- No sabe cuántas series "cuentan"
- No ve el cálculo en tiempo real

### Momento de sorpresa negativa
- **Cuándo**: 3/4 series completas (75%)
- **Qué ve**: "Repite el objetivo. Estás cerca."
- **Qué esperaba**: Crédito parcial o mensaje de progreso

### Solución propuesta
**Mostrar progreso de sesión en tiempo real:**

```
┌────────────────────────────┐
│  SESIÓN ACTUAL             │
│  ✅ ✅ ✅ ⬜  (75%)         │
│                            │
│  80% = éxito               │
│  Te falta: 1 serie más     │
└────────────────────────────┘
```

**Código necesario:**
```dart
// En exercise_card.dart o training_session_screen.dart
Widget _buildSessionProgressIndicator(List<SerieLog> logs, int targetReps) {
  final completed = logs.where((l) => l.completed && l.reps >= targetReps).length;
  final total = logs.length;
  final percent = total > 0 ? (completed / total * 100).round() : 0;
  final isSuccess = percent >= 80;
  
  return Row(
    children: [
      ...logs.map((l) => Icon(
        l.completed && l.reps >= targetReps 
          ? Icons.check_circle 
          : Icons.circle_outlined,
        size: 16,
        color: l.completed ? Colors.green : Colors.grey,
      )),
      Text(' ($percent%)', style: TextStyle(
        color: isSuccess ? Colors.green : Colors.amber,
      )),
    ],
  );
}
```

---

## 🔍 PUNTO 3: Incrementos Variables

### Lo que decide el algoritmo
```dart
ExerciseCategory.getIncrement(currentWeight):
  heavyCompound (≥60kg) → 2.5kg
  heavyCompound (<60kg) → 1.25kg
  lightCompound (≥40kg) → 2.5kg
  lightCompound (<40kg) → 1.25kg
  isolation → 1.25kg (siempre)
  machine → 2.5kg (pasos de máquina)
```

### Lo que cree el usuario
> "Siempre subo 2.5kg"

### Momento de sorpresa negativa
- **Cuándo**: Curl bíceps pasa de 12kg a 13.25kg (no a 14.5kg)
- **Qué ve**: "+1.25kg"
- **Qué esperaba**: "+2.5kg"

### Solución propuesta
**Mostrar incremento específico antes de que ocurra:**

```
┌─────────────────────────────────────┐
│  📊 CURL BÍCEPS                     │
│  Categoría: Aislamiento             │
│  Incremento: +1.25kg                │
│                                     │
│  Si éxito → 13.25kg                 │
└─────────────────────────────────────┘
```

**En el tooltip de información:**
```dart
// Añadir a ProgressionInfoTooltip
Text('Incremento para ${category.label}: ${increment}kg'),
```

---

## 🔍 PUNTO 4: Días Malos No Castigan

### Lo que decide el algoritmo
```dart
if (lastResult == SessionResult.partial || lastResult == SessionResult.failed) {
  if (context.consecutiveFailures >= 2) {
    → BAJAR PESO
  } else {
    → MANTENER (no castiga)
  }
}
```

### Lo que cree el usuario
> "Fallé hoy, perdí mi progreso"

### Momento de sorpresa negativa (positiva)
- **Cuándo**: Sesión mala tras buenas sesiones
- **Qué ve**: "Repite el objetivo. Un día malo no cambia nada."
- **Qué esperaba**: Retroceso

### El problema inverso
- Usuario puede **no entender por qué** mantiene
- Puede pensar que el sistema "no funciona"
- Puede forzarse a hacer más de lo que debe

### Solución propuesta
**Comunicar explícitamente la "protección":**

```
┌─────────────────────────────────────┐
│  🛡️ PROTEGIDO                       │
│                                     │
│  1 sesión difícil no afecta.        │
│  Tu baseline sigue en 80kg.         │
│                                     │
│  Próxima sesión: mismo objetivo     │
└─────────────────────────────────────┘
```

---

## 🔍 PUNTO 5: Bajada de Peso = Consolidación

### Lo que decide el algoritmo
```dart
if (consecutiveFailures >= 2) {
  suggestedWeight = confirmedWeight - increment
  userMessage: 'Bajamos a ${newWeight}kg para consolidar. Es parte del proceso.'
}
```

### Lo que cree el usuario
> "Bajar peso = fracaso"

### Momento de sorpresa negativa
- **Cuándo**: Segunda sesión consecutiva difícil
- **Qué ve**: "Bajamos a 77.5kg para consolidar"
- **Qué siente**: Frustración, vergüenza

### Solución implementada ✅
- Mensaje: "Es parte del proceso"
- Preview: "Objetivo: 77.5kg × 12 → volver a subir"

### Mejora adicional sugerida
**Reframear como "Deload inteligente":**

```
┌─────────────────────────────────────┐
│  🔄 DELOAD INTELIGENTE              │
│                                     │
│  77.5kg × 12 (2 semanas)            │
│  ↓                                  │
│  80kg × 8 (recuperar)               │
│  ↓                                  │
│  80kg × 12 (superar)                │
│                                     │
│  Tiempo estimado: 4-6 semanas       │
└─────────────────────────────────────┘
```

---

## 🔍 PUNTO 6: Peso Confirmado vs Peso Usado

### Lo que decide el algoritmo
```dart
confirmedWeight = peso más frecuente en historial (moda estadística)
// NO es el último peso usado
```

### Lo que cree el usuario
> "Mi peso es el que usé la última vez"

### Momento de sorpresa negativa
- **Cuándo**: Usuario usó 82.5kg una vez, falló, volvió a 80kg
- **Qué ve**: Sugerencia basada en 80kg (el confirmado)
- **Qué esperaba**: Referencia a 82.5kg

### Solución propuesta
**Mostrar claramente el peso "base":**

```
┌─────────────────────────────────────┐
│  📊 PRESS BANCA                     │
│                                     │
│  Peso base: 80kg                    │
│  Último intento: 82.5kg (1/2 ✗)     │
│                                     │
│  Objetivo hoy: 80kg × 12            │
└─────────────────────────────────────┘
```

---

## 📊 MATRIZ DE COMUNICACIÓN

### Acciones y sus mensajes

| Acción | Icono | Color | Mensaje Corto | Submensaje |
|--------|-------|-------|---------------|------------|
| SUBIR PESO | 🏋️ | Verde | "+2.5kg" | "¡Confirmado!" |
| SUBIR REPS | ➕ | Azul | "+1 rep" | "Progresando" |
| MANTENER | 🔄 | Amarillo | "Mismo objetivo" | "Confirmando" o "Protegido" |
| CONSOLIDAR | 📉 | Naranja | "Deload" | "Reconstruyendo base" |

### Estados y sus indicadores visuales

| Estado | Indicador Visual | Ubicación |
|--------|------------------|-----------|
| Calibrando | `⚙️ (1/2)` | Badge junto a ejercicio |
| Confirmando | `🔄 (1/2)` | Badge junto a ejercicio |
| Progresando | `📈` | Ninguno (estado normal) |
| Estancado | `⚠️` | Badge naranja |
| Deload | `🔄` | Badge naranja |

---

## 🛠️ IMPLEMENTACIÓN PRIORITARIA

### Prioridad 1: Indicador de sesión actual
```dart
// Mostrar en tiempo real: ✅ ✅ ✅ ⬜ (75%)
// Usuario sabe si va bien ANTES de terminar
```

### Prioridad 2: Estado de confirmación visible
```dart
// Badge: "CONFIRMANDO 1/2" 
// Usuario entiende por qué repite
```

### Prioridad 3: Incremento visible en preview
```dart
// "Próximo: +1.25kg (ejercicio de aislamiento)"
// Usuario no se sorprende por incremento pequeño
```

### Prioridad 4: Explicación de "protección"
```dart
// "🛡️ Tu baseline está protegido"
// Usuario entiende que un día malo es OK
```

---

## 📋 CHECKLIST DE COMUNICACIÓN

Para cada decisión del algoritmo, verificar:

- [ ] ¿El usuario puede predecir esta decisión ANTES de que ocurra?
- [ ] ¿El mensaje explica el POR QUÉ, no solo el QUÉ?
- [ ] ¿Hay un preview del SIGUIENTE paso?
- [ ] ¿Los colores comunican sin necesidad de leer?
- [ ] ¿El usuario sabe qué hacer para cambiar el resultado?

---

## 🎯 REGLA DE ORO

> **El usuario nunca debe preguntarse "¿por qué?"**
> 
> Si el algoritmo toma una decisión que el usuario no esperaba,
> la UI ha fallado en comunicar, no el algoritmo en decidir.

### Anti-patrón
```
Algoritmo: "Mantener 80kg"
Usuario: "¿Por qué no sube?"
```

### Patrón correcto
```
UI: "🔄 CONFIRMANDO (1/2) - Repite para subir a 82.5kg"
Usuario: "Ah, tengo que confirmar primero"
```
