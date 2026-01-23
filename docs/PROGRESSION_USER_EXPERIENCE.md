# PROGRESIÓN DESDE LA EXPERIENCIA DEL USUARIO

## Filosofía de Diseño

> **El usuario no entrena para ver números. Entrena para mejorar.**
> 
> La app debe ser un entrenador silencioso que solo habla cuando tiene algo útil que decir.

---

## 1. ANTES DE ENTRENAR

### Lo que el usuario ve al abrir el ejercicio:

```
┌─────────────────────────────────────────────┐
│  SENTADILLA                                 │
│                                             │
│        ┌───────────────────┐                │
│        │      80 kg        │  ← Peso claro  │
│        │     × 8 reps      │                │
│        └───────────────────┘                │
│                                             │
│  ✓ Si lo logras: siguiente vez 82.5kg      │  ← Consecuencia visible
│                                             │
│          [ EMPEZAR ]                        │
│                                             │
└─────────────────────────────────────────────┘
```

### Estados posibles (solo uno visible):

| Situación | Lo que ve | Lo que entiende |
|-----------|-----------|-----------------|
| Normal | "Si lo logras: +2.5kg" | "Mi esfuerzo tiene recompensa clara" |
| Confirmando | "Repite para confirmar subida" | "Estoy cerca de progresar" |
| Deload | "Peso reducido para recuperar" | "Esto es estratégico, no fracaso" |
| Récord personal | "🎯 Tu mejor marca con este peso" | "Momento importante" |

### Lo que NO ve:
- ❌ "Sesión 3 de fase de acumulación"
- ❌ "RPE objetivo: 7-8"
- ❌ "Volumen semanal: 15 series"
- ❌ Gráficos de progresión

### Modelo mental del usuario:
```
"Voy a hacer 80kg × 8. Si lo hago bien, subo. Simple."
```

---

## 2. DURANTE EL ENTRENAMIENTO

### Serie por serie - Feedback mínimo:

```
┌─────────────────────────────────────────────┐
│  SERIE 1 de 3                               │
│                                             │
│        ┌───────────────────┐                │
│        │      80 kg        │                │
│        │     × 8 reps      │                │
│        └───────────────────┘                │
│                                             │
│     ┌──────────────────────────┐            │
│     │  REPS COMPLETADAS:  [8]  │            │
│     └──────────────────────────┘            │
│                                             │
│              [ ✓ LISTO ]                    │
│                                             │
└─────────────────────────────────────────────┘
```

### Después de cada serie - Solo si relevante:

**Caso: Todo bien**
```
Serie 1: ✓ 8 reps
         (sin mensaje - silencio = OK)
```

**Caso: Menos reps de las esperadas**
```
Serie 2: ✓ 6 reps
         "No pasa nada. Completa lo que puedas."
```

**Caso: Todas las series perfectas**
```
Serie 3: ✓ 8 reps
         ✨ "¡Objetivo cumplido!"
```

### Barra de progreso sutil:

```
Objetivo: 8 + 8 + 8 = 24 reps totales

┌────────────────────────────────────────┐
│  ████████████████░░░░░░░░░░░░░░  67%   │  ← Solo si ayuda
└────────────────────────────────────────┘
     16 de 24 reps
```

### Cuándo puede intervenir el usuario:

| Momento | Acción disponible | Resultado |
|---------|-------------------|-----------|
| Antes de serie | "Cambiar peso" | Ajusta peso (app recuerda) |
| Después de serie | "Fue muy fácil/difícil" | Nota para próxima vez |
| Final del ejercicio | "Repetir última serie" | No penaliza |

### Intervención de peso:

```
┌─────────────────────────────────────────────┐
│  ⚖️ AJUSTAR PESO                            │
│                                             │
│   Sugerido: 80 kg                           │
│                                             │
│   [ -2.5 ]  [ 80 kg ]  [ +2.5 ]             │
│                                             │
│   ℹ️ El sistema recordará tu ajuste         │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 3. DESPUÉS DEL EJERCICIO

### Resumen inmediato (máximo 3 segundos de lectura):

**Caso: Éxito**
```
┌─────────────────────────────────────────────┐
│                                             │
│           ✅ ¡Bien hecho!                   │
│                                             │
│        80 kg × 8, 8, 8                      │
│                                             │
│   ┌─────────────────────────────────┐       │
│   │  📈 Próxima vez: 82.5 kg        │       │
│   └─────────────────────────────────┘       │
│                                             │
│           [ SIGUIENTE EJERCICIO ]           │
│                                             │
└─────────────────────────────────────────────┘
```

**Caso: Día difícil (pero no pasa nada)**
```
┌─────────────────────────────────────────────┐
│                                             │
│           ✓ Completado                      │
│                                             │
│        80 kg × 8, 6, 5                      │
│                                             │
│   ┌─────────────────────────────────┐       │
│   │  → Próxima vez: mismo objetivo  │       │
│   │    Un día difícil no cambia nada│       │
│   └─────────────────────────────────┘       │
│                                             │
│           [ SIGUIENTE EJERCICIO ]           │
│                                             │
└─────────────────────────────────────────────┘
```

**Caso: Confirmación lograda (subida de peso)**
```
┌─────────────────────────────────────────────┐
│                                             │
│        🎉 ¡NUEVO PESO DESBLOQUEADO!         │
│                                             │
│        80 kg × 8, 8, 8                      │
│                                             │
│   ┌─────────────────────────────────┐       │
│   │  Confirmaste 2 sesiones seguidas│       │
│   │                                 │       │
│   │  📈 Próxima vez: 82.5 kg        │       │
│   └─────────────────────────────────┘       │
│                                             │
│           [ SIGUIENTE EJERCICIO ]           │
│                                             │
└─────────────────────────────────────────────┘
```

**Caso: Deload sugerido**
```
┌─────────────────────────────────────────────┐
│                                             │
│           ⚡ Hora de recuperar              │
│                                             │
│   Llevas varias sesiones luchando.          │
│   Es normal y parte del proceso.            │
│                                             │
│   ┌─────────────────────────────────┐       │
│   │  📉 Próxima vez: 75 kg          │       │
│   │     Peso reducido para          │       │
│   │     reconstruir fuerza          │       │
│   └─────────────────────────────────┘       │
│                                             │
│   [ ACEPTAR ]        [ MANTENER 80kg ]      │
│                                             │
└─────────────────────────────────────────────┘
```

### Lo que el usuario sabe de la siguiente sesión:

| Después de... | Sabe que... |
|---------------|-------------|
| Éxito | "Próxima vez subo peso" |
| Éxito parcial | "Repito el mismo peso" |
| Confirmación | "¡Subí! Nueva base" |
| Deload | "Bajo para recuperar, es estrategia" |

---

## MICROINTERACCIONES CLAVE

### 1. Entrada al ejercicio (500ms)

```
                    ↓
         ┌─────────────────┐
         │                 │
    →    │     80 kg       │    ← Peso aparece primero (grande)
         │                 │
         └─────────────────┘
                    ↓
              × 8 reps          ← Reps aparecen después (más pequeño)
                    ↓
         "Si lo logras: +2.5kg" ← Consecuencia aparece último (sutil)
```

**Timing:**
- 0ms: Peso visible inmediatamente
- 200ms: Reps fade in
- 400ms: Consecuencia slide up

### 2. Registro de serie (300ms)

```
   Toca "8 reps"
        ↓
   ┌─────────┐
   │ ✓  8    │  ← Check aparece con bounce
   └─────────┘
        ↓
   Slide a siguiente serie (si hay)
```

**Feedback háptico:** Vibración corta (50ms) al registrar

### 3. Objetivo cumplido (800ms)

```
   Última serie completada con éxito
        ↓
   ╔═══════════════════╗
   ║   ✨ ¡Perfecto!   ║  ← Confetti sutil (no exagerado)
   ╚═══════════════════╝
        ↓
   Próximo peso: 82.5kg   ← Número nuevo pulsa 2x
```

**Sonido:** Tono corto de éxito (opcional, respeta ajustes)

### 4. Día difícil (sin dramatismo)

```
   Serie con menos reps
        ↓
   ┌─────────────────────────┐
   │  ✓ 6 reps              │
   │  ─────────────────────  │
   │  No pasa nada.         │  ← Mensaje tranquilizador
   └─────────────────────────┘
        ↓
   (Sin animación especial - normalizar)
```

**Sin:** sonidos negativos, colores rojos, iconos de advertencia

### 5. Subida de peso confirmada (1200ms)

```
   Segunda sesión exitosa consecutiva
        ↓
   ┌─────────────────────────┐
   │                         │
   │   🎉                    │  ← Emoji primero
   │                         │
   │   ¡NUEVO PESO!          │  ← Texto grande
   │                         │
   │   80 kg → 82.5 kg       │  ← Transición animada
   │                         │
   └─────────────────────────┘
```

**Animación del peso:**
```
80.0 → 80.5 → 81.0 → 81.5 → 82.0 → 82.5
(contador animado, 400ms total)
```

### 6. Deload sugerido (con empatía)

```
   Tercera sesión difícil
        ↓
   ┌─────────────────────────┐
   │                         │
   │   ⚡ Momento de          │
   │      recuperar          │
   │                         │
   │   Esto es parte del     │  ← Mensaje empático
   │   proceso. Los mejores  │
   │   atletas lo hacen.     │
   │                         │
   │   ┌─────────────────┐   │
   │   │ 80 → 75 kg      │   │
   │   └─────────────────┘   │
   │                         │
   │   [ Sí ]   [ Mantener ] │  ← Siempre dar opción
   │                         │
   └─────────────────────────┘
```

**Importante:** El usuario SIEMPRE puede rechazar el deload

---

## FLUJO UX COMPLETO

```
                        ABRIR APP
                            │
                            ▼
               ┌────────────────────────┐
               │   VER ENTRENAMIENTO    │
               │   DEL DÍA              │
               │                        │
               │   • Sentadilla 80kg    │
               │   • Press banca 60kg   │
               │   • Remo 50kg          │
               └──────────┬─────────────┘
                          │
                          ▼
               ┌────────────────────────┐
               │   SELECCIONAR          │
               │   EJERCICIO            │
               │                        │
               │   ┌──────────────────┐ │
               │   │     80 kg        │ │
               │   │    × 8 reps      │ │
               │   └──────────────────┘ │
               │                        │
               │   Si éxito: +2.5kg     │
               │                        │
               │   [ EMPEZAR ]          │
               └──────────┬─────────────┘
                          │
            ┌─────────────┴─────────────┐
            │                           │
            ▼                           ▼
    ┌───────────────┐          ┌───────────────┐
    │  HACER SERIE  │          │ AJUSTAR PESO  │ (opcional)
    │               │          │               │
    │  [  8  ]      │          │ [ -2.5 ] [+2.5]│
    │               │          │               │
    │  [ ✓ LISTO ]  │          └───────────────┘
    └───────┬───────┘
            │
            ▼
    ┌───────────────────────────────────┐
    │  ¿MÁS SERIES?                     │
    │                                   │
    │  SÍ ──────────┐                   │
    │               │                   │
    │  NO ──────────┼───────────────────┤
    └───────────────┴───────────────────┘
                    │
                    ▼
    ┌───────────────────────────────────┐
    │   RESUMEN                         │
    │                                   │
    │   ✓ 80 kg × 8, 8, 8              │
    │                                   │
    │   ┌─────────────────────┐         │
    │   │ Próxima: 82.5 kg    │         │
    │   └─────────────────────┘         │
    │                                   │
    │   [ SIGUIENTE ]                   │
    └───────────────────────────────────┘
                    │
                    ▼
              SIGUIENTE EJERCICIO
              (repetir flujo)
```

---

## PRINCIPIOS DE COMUNICACIÓN

### 1. Usar el lenguaje del usuario

| ❌ Técnico | ✅ Natural |
|-----------|-----------|
| "Incremento de carga" | "Sube peso" |
| "Deload programado" | "Peso reducido para recuperar" |
| "Sesión de confirmación" | "Repite para confirmar" |
| "Volumen insuficiente" | "Intenta una serie más" |
| "RPE 9" | "Fue muy difícil" |

### 2. Mostrar consecuencias, no métricas

| ❌ Métrica | ✅ Consecuencia |
|-----------|----------------|
| "80% completado" | "Próxima vez: mismo peso" |
| "2/2 sesiones" | "¡Subida confirmada!" |
| "3 fracasos" | "Hora de recuperar" |
| "Incremento: 2.5kg" | "Próxima vez: 82.5kg" |

### 3. Normalizar los días difíciles

| Situación | Mensaje |
|-----------|---------|
| Menos reps | "No pasa nada. Completa lo que puedas." |
| Serie fallida | "Un día difícil no cambia tu progreso." |
| Deload | "Los mejores atletas descansan estratégicamente." |

### 4. Celebrar sin exagerar

| Logro | Celebración |
|-------|-------------|
| Serie completa | ✓ (check silencioso) |
| Ejercicio completo | "¡Bien hecho!" |
| Subida de peso | "🎉 ¡Nuevo peso!" |
| Récord personal | "🏆 ¡Tu mejor marca!" |

---

## RESUMEN: LO QUE EL USUARIO EXPERIMENTA

```
ANTES:      "Hoy hago 80kg. Si lo logro, subo."
            (Expectativa clara, consecuencia visible)

DURANTE:    "Serie 1 ✓, Serie 2 ✓, Serie 3 ✓"
            (Feedback mínimo, sin distracciones)

DESPUÉS:    "Lo logré. Próxima vez 82.5kg."
            (Conclusión inmediata, futuro predecible)
```

**El usuario nunca debería:**
- Preguntarse "¿por qué este peso?"
- Sentirse juzgado por un día malo
- Tomar decisiones técnicas
- Buscar información para entender qué hacer
