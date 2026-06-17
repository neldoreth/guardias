# Guardias

Aplicación macOS nativa para la gestión de calendarios de turnos de guardia.

## Tecnología
- **Plataforma:** macOS 14+ (Sonoma)
- **UI:** SwiftUI con patrón MVVM
- **Estado:** `@Observable` (Swift 5.9+ / Observation framework)
- **Persistencia:** JSON en Application Support (`~/Library/Application Support/Guardias/data.json`)
- **Build:** XcodeGen → Xcode

## Cómo construir

```bash
# 1. Generar proyecto Xcode
xcodegen generate

# 2. Generar icono (requiere Swift CLI)
swift scripts/generate_icon.swift

# 3. Abrir en Xcode
open Guardias.xcodeproj
```

## Estructura del proyecto

```
Guardias/
├── Extensions/         Date helpers (startOfWeek, weekdays, isSameDay)
├── Models/             Modelos de datos puros (Codable, Hashable)
│   ├── Worker          Trabajador (id, name, colorIndex)
│   ├── GuardAssignment Asignación de guardia por semana
│   └── AppData         Raíz de datos + AppSettings
├── Store/
│   └── GuardiasStore   @Observable store principal, persiste y recomputa
├── Services/
│   └── SchedulingEngine Algoritmo de rotación de guardias (pura función)
└── Views/
    ├── Calendar/       Vista principal del calendario anual de guardias
    ├── Workers/        Calendarios de vacaciones por trabajador
    ├── Sheets/         Hojas modales (swap, asignación manual)
    └── Settings/       Gestión de trabajadores y ajustes
```

## Algoritmo de planificación (`SchedulingEngine`)

1. Obtiene todas las semanas (lunes) en el rango de fechas configurado
2. Para cada semana:
   - Si hay asignación manual/swap, la usa (no altera la rotación)
   - Si no, busca el siguiente trabajador disponible (rota en orden)
   - **Primera pasada:** evita guardias consecutivas del mismo trabajador
   - **Segunda pasada (fallback):** permite consecutivas si es necesario
3. Un trabajador NO está disponible si:
   - Tiene algún día de vacaciones en esa semana (L–D)
   - (Si toggle activo) Tiene vacaciones la semana siguiente

## Reglas de negocio

- **Rotación equitativa:** con N trabajadores, cada uno hace guardia cada N semanas
- **Vacaciones:** cualquier día suelto bloquea toda la semana de guardia
- **Toggle "semana previa":** si activo, también bloquea la semana anterior a vacaciones
- **Swaps:** prevalecen siempre sobre la rotación automática
- **Asignaciones manuales:** almacenadas en `appData.manualAssignments`; prevalecen sobre cálculo
- **Anti-consecutivo:** el motor evita activamente que el mismo trabajador tenga guardias seguidas

## Integración Microsoft 365 (futura)

Prevista para fase 2. La arquitectura está preparada:
- `BackupService` puede extenderse para sincronizar con MS Graph API
- Los `GuardAssignment` tienen estructura compatible con iCal/CalDAV
- Añadir entitlement `com.apple.security.network.client` cuando sea necesario

## Backup

- **Exportar:** Archivo > Exportar copia de seguridad... (⌘⇧E) → JSON
- **Importar:** Archivo > Importar copia de seguridad... (⌘⇧I) → JSON
- El JSON incluye trabajadores, vacaciones, asignaciones manuales y ajustes
