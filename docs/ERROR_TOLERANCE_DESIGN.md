# MANEJO DE ERRORES REALES DEL USUARIO

## Filosofía

> **El sistema debe ser más tolerante que un entrenador humano.**
> 
> Principios:
> 1. **NUNCA castigar** - Solo ajustar expectativas
> 2. **NUNCA romperse** - Siempre tener un fallback sensato
> 3. **NUNCA perder credibilidad** - Explicar cambios claramente

---

## REGLA 1: SERIE FALLIDA

### Situación
Usuario hace 5 reps cuando el objetivo era 8.

### Respuesta del sistema

| ❌ MAL | ✅ BIEN |
|--------|---------|
| "¡Fallaste! -1 punto" | (Silencio - registrar normalmente) |
| Notificación negativa | "No pasa nada" (si pregunta) |
| Color rojo en la serie | Color neutro |

### Regla de tolerancia
```
UNA serie mala NUNCA afecta directamente la progresión.
Solo afecta si es PATRÓN REPETIDO (3+ sesiones).
```

### Ejemplo de sesión real
```
Objetivo: 80kg × 8,8,8

Sesión 1: 8, 8, 5  → "Completado" (no menciona el 5)
                   → Próxima: 80kg (no sube, no baja)
                   → Interno: 72% completado, 1 día difícil

Sesión 2: 8, 8, 8  → "¡Bien hecho!"
                   → Próxima: ¿confirmar subida?
                   → Interno: Borrar flag de día difícil
```

### Código
```dart
// Una serie mala no genera mensaje negativo
if (reps < target) {
  return ToleranceResult(
    isValid: true,
    userMessage: null,  // ← SILENCIO
    affectsProgression: true,  // Cuenta, pero no castiga
  );
}
```

---

## REGLA 2: ERROR DE ENTRADA DE DATOS

### Situación
Usuario pone 500kg en curl de bíceps (claramente error de dedo).

### Respuesta del sistema

| ❌ MAL | ✅ BIEN |
|--------|---------|
| Guardar 500kg y romper gráficos | "¿Quisiste decir 50kg?" |
| Bloquear hasta corregir | Permitir confirmar si es real |
| Ignorar silenciosamente | Ofrecer corrección suave |

### Regla de tolerancia
```
- Peso > 150% del último conocido → Pedir confirmación
- Peso > máximo razonable para categoría → Sugerir corrección
- NUNCA bloquear, siempre permitir confirmar
```

### Umbrales por categoría
| Categoría | Máximo razonable | Cambio máximo/sesión |
|-----------|------------------|---------------------|
| Compuesto pesado | 400kg | ±30% |
| Compuesto ligero | 200kg | ±30% |
| Aislamiento | 100kg | ±30% |
| Máquina | 500kg | ±30% |

### Ejemplo de sesión real
```
Último peso conocido: 50kg (curl)

Usuario introduce: 500kg
Sistema: "¿Quisiste decir 50kg?"
         [ 50kg ]  [ Sí, 500kg ]

Usuario elige 50kg → Continúa normal
Usuario elige 500kg → Guarda 500kg, confía en usuario
```

### Detección de error de dedo
```dart
if (entered > lastKnown * 5) {
  // Probablemente un 0 de más: 800 → 80
  suggestedCorrection = entered / 10;
}
```

---

## REGLA 3: SESIÓN SALTADA

### Situación
Usuario no entrena en X días.

### Respuesta del sistema

| Días ausente | Respuesta |
|--------------|-----------|
| 1-6 días | Sin cambios |
| 7-13 días | "¡De vuelta!" + resetear confirmación |
| 14-29 días | Sugerir -5% (opcional) |
| 30+ días | Sugerir recalibración (opcional) |

### Regla de tolerancia
```
- < 7 días: Como si nada pasó
- 7-14 días: Perdonar, resetear estado "confirmando"
- 14-30 días: SUGERIR (no forzar) peso reducido
- > 30 días: SUGERIR (no forzar) recalibración
```

### Ejemplo de sesión real
```
Última sesión: 15 de enero, 80kg
Hoy: 30 de enero (15 días después)

Sistema: "¡De vuelta! Han pasado 15 días."
         "Sugerimos empezar con 76kg."
         
         [ 76kg (sugerido) ]  [ 80kg (mantener) ]

Si elige 76kg → Empieza con 76kg
Si elige 80kg → Empieza con 80kg, sin penalización
```

### Nunca decir
- ❌ "Has perdido progreso"
- ❌ "Reiniciando desde cero"
- ❌ "Debes recalibrar" (obligatorio)

---

## REGLA 4: DÍA MALO (TODAS LAS SERIES MALAS)

### Situación
Usuario normalmente hace 8,8,8 pero hoy hace 5,4,4.

### Respuesta del sistema

| ❌ MAL | ✅ BIEN |
|--------|---------|
| "Rendimiento -40%" | "Día difícil. No afecta tu progreso." |
| Bajar peso automático | Mantener peso, dar ánimo |
| Notificación de advertencia | Mensaje empático |

### Regla de tolerancia
```
1 día malo aislado = NO afecta progresión
2 días malos consecutivos = Cuenta como 1 fracaso
3+ días malos = Sugerir (no forzar) deload
```

### Ejemplo de sesión real
```
Objetivo: 80kg × 8,8,8 (24 reps total)

Sesión normal: 8, 8, 8 = 24 reps (100%)
Hoy:          5, 4, 4 = 13 reps (54%)

Sistema: "Día difícil. Todos los tenemos."
         "No afecta tu progreso."
         "Próxima: 80kg × 8" (SIN cambios)

Interno: Flag "badDay = true"
         Si próxima sesión también < 80%:
         → Entonces sí cuenta como fracaso
```

### La diferencia
```
Día malo aislado:
  Sesión 1: 5,4,4 → "No afecta" → Próxima: 80kg
  Sesión 2: 8,8,8 → Borrar flag → Todo normal

Patrón de días malos:
  Sesión 1: 5,4,4 → Flag día malo
  Sesión 2: 5,5,4 → 2do día malo → "Considera descansar"
  Sesión 3: 4,4,4 → 3er día malo → Sugerir deload
```

---

## REGLA 5: RENDIMIENTO SOSPECHOSO (TRAMPAS)

### Situación
- Usuario siempre reporta exactamente el objetivo
- O de repente reporta 20 reps cuando hacía 8

### Respuesta del sistema

| ❌ MAL | ✅ BIEN |
|--------|---------|
| "¡Trampa detectada!" | Confiar silenciosamente |
| Ignorar datos | Pedir confirmación suave |
| Advertencia acusatoria | Ajustar modelo interno |

### Regla de tolerancia
```
SIEMPRE confiar en el usuario.
Si es sospechoso:
- Pedir confirmación SIN acusar
- Ajustar expectativas internas silenciosamente
```

### Casos específicos

#### Caso A: Rendimiento "demasiado bueno"
```
Historial: 8, 8, 8, 8, 8 (siempre exacto)
Hoy: 15, 14, 14

Sistema: "¡Gran sesión! ¿15, 14, 14 reps es correcto?"
         [ Sí, correcto ]  [ Editar ]

→ Si confirma: Guardar y progresar normalmente
→ Interno: Nota de "posible sobre-reporte"
```

#### Caso B: Siempre exacto (sospecha de datos inventados)
```
Últimas 10 sesiones: Todas exactamente 8,8,8

Sistema: (NADA - no decir nada al usuario)

Interno: 
- Nota: "Datos muy consistentes"
- Ajustar: Requerir confirmación extra antes de subir
- Pero NUNCA acusar
```

### Nunca decir
- ❌ "Datos sospechosos"
- ❌ "Parece que estás inventando"
- ❌ "Rendimiento imposible"

---

## REGLA 6: OVERRIDE MANUAL

### Situación
El sistema sugiere 80kg, usuario cambia a 70kg.

### Respuesta del sistema

| ❌ MAL | ✅ BIEN |
|--------|---------|
| "Ignorando tu cambio" | "OK. Usando 70kg." |
| Revertir silenciosamente | Recordar preferencia |
| Advertencia de "sub-óptimo" | Aprender de la preferencia |

### Regla de tolerancia
```
El usuario SIEMPRE tiene la última palabra.
El sistema APRENDE de sus preferencias.
```

### Tipos de override

| Acción usuario | Respuesta sistema |
|----------------|-------------------|
| Baja peso un poco | "OK. Recordaré." |
| Baja peso mucho (>20%) | Ajustar baseline interno |
| Sube peso | Confiar completamente |

### Ejemplo de sesión real
```
Sistema sugiere: 80kg
Usuario cambia: 70kg

Sistema: "OK. Usando 70kg."
         (Sin mensaje de advertencia)
         (Sin explicación de por qué 80kg era "mejor")

Interno:
- Guardar preferencia: ejercicio X → usuario prefiere conservador
- Próxima sugerencia: 72.5kg (más conservadora)
```

---

## EJEMPLOS DE SESIONES REALES

### Ejemplo 1: Semana típica con altibajos
```
Lunes:    80kg × 8, 8, 8  ✓  → Próxima: confirmar 80kg
Miércoles: 80kg × 8, 6, 5     → "Día difícil. Próxima: 80kg" (no afecta)
Viernes:  80kg × 8, 8, 8  ✓  → "¡Confirmado! Próxima: 82.5kg"
```

### Ejemplo 2: Vuelta de vacaciones
```
Última sesión: 1 de agosto, 80kg
Hoy: 1 de septiembre (31 días)

Sistema: "¡Bienvenido de nuevo!"
         "Sugerimos empezar con 68kg y recalibrar."
         
Usuario elige: 75kg (entre medio)
Sistema: "OK. Usando 75kg."

Resultado: 75kg × 8, 7, 6
Sistema: "Buen regreso. Próxima: 75kg"
```

### Ejemplo 3: Error de entrada corregido
```
Ejercicio: Press mancuerna
Último peso: 30kg

Usuario introduce: 300kg (error de dedo)

Sistema: "¿Quisiste decir 30kg?"
Usuario: "Sí, 30kg"
Sistema: (continúa normalmente)
```

### Ejemplo 4: Días malos consecutivos + recuperación
```
Sesión 1: 80kg × 5, 4, 4 → "Día difícil" (no afecta)
Sesión 2: 80kg × 5, 5, 4 → "Segunda sesión difícil. Considera descansar."
Sesión 3: 80kg × 4, 4, 3 → "Te sugerimos bajar a 75kg para consolidar."
                          [ Aceptar 75kg ]  [ Mantener 80kg ]

Usuario acepta 75kg:
Sesión 4: 75kg × 8, 8, 8 → "¡Bien hecho! Próxima: 77.5kg"
Sesión 5: 77.5kg × 8, 8, 8 → "Próxima: 80kg" (recuperado)
```

### Ejemplo 5: Usuario "tramposo" (reporta siempre perfecto)
```
10 sesiones consecutivas: Exactamente 8, 8, 8

Sistema al usuario: (NADA - no dice nada)

Sistema interno:
- Flag: "very_consistent_reporter"
- Acción: Requerir 3 sesiones de confirmación en vez de 2
- Próxima subida: Pedir confirmación extra

Usuario ve: Misma experiencia
Sistema: Más cauteloso silenciosamente
```

---

## CÓMO SE RECUPERA EL SISTEMA

### Árbol de recuperación

```
                    ┌─────────────────┐
                    │  PROBLEMA       │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
   ┌───────────┐      ┌───────────┐      ┌───────────┐
   │ 1 sesión  │      │ 2 sesiones│      │ 3+ sesiones│
   │   mala    │      │   malas   │      │   malas   │
   └─────┬─────┘      └─────┬─────┘      └─────┬─────┘
         │                  │                  │
         ▼                  ▼                  ▼
   ┌───────────┐      ┌───────────┐      ┌───────────┐
   │ "No pasa  │      │"Considera │      │ Sugerir   │
   │   nada"   │      │ descansar"│      │  deload   │
   │           │      │           │      │ (opción)  │
   └─────┬─────┘      └─────┬─────┘      └─────┬─────┘
         │                  │                  │
         ▼                  ▼                  ▼
   Próxima sesión     Próxima sesión     Usuario decide
   normal             normal             ↓
         │                  │            ┌──────┴──────┐
         └─────────┬────────┘            ▼             ▼
                   │              Acepta deload   Mantiene
                   ▼                    │             │
            ┌───────────┐               ▼             ▼
            │ Si OK →   │         75kg × 8,8,8   80kg × ?
            │ borrar    │               │             │
            │ flags     │               ▼             ▼
            └───────────┘         Recuperado    Respetamos
```

### Estados de recuperación

| Problema | Acción inmediata | Recuperación |
|----------|------------------|--------------|
| 1 día malo | Ignorar | Próxima OK → olvidado |
| 2 días malos | Mensaje suave | Próxima OK → olvidado |
| 3 días malos | Sugerir deload | Aceptar → progresar |
| Ausencia corta | Nada | Continúa normal |
| Ausencia larga | Sugerir recalibrar | Usuario decide |
| Error datos | Pedir confirmación | Usuario corrige o confirma |
| Override manual | Recordar | Ajustar sugerencias futuras |

---

## RESUMEN: TABLA DE RESPUESTAS

| Situación | Mensaje al usuario | Afecta progresión |
|-----------|-------------------|-------------------|
| 1 serie mala | (silencio) | Sí, pero no castiga |
| Todas series malas (1 vez) | "Día difícil" | NO |
| 2 días malos seguidos | "Considera descansar" | Cuenta como 1 fracaso |
| 3+ días malos | Sugerir deload | Sí, si acepta |
| Error de datos obvio | "¿Quisiste decir X?" | No hasta confirmar |
| Ausencia < 7 días | (nada) | No |
| Ausencia 7-14 días | "¡De vuelta!" | Reset confirmación |
| Ausencia > 14 días | Sugerir reducción | Usuario decide |
| Usuario baja peso | "OK. Usando X kg." | Recordar preferencia |
| Usuario sube peso | "OK. Usando X kg." | Confiar |
| Rendimiento sospechoso | Confirmación suave | Sí, si confirma |

---

## IMPLEMENTACIÓN

Ver: [lib/services/error_tolerance_system.dart](../lib/services/error_tolerance_system.dart)

Clases principales:
- `ErrorToleranceRules` - Evaluadores para cada situación
- `RecoverySystem` - Planes de recuperación
- `ToleranceResult` - Resultado de evaluación con mensaje
