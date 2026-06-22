# Guardias

Aplicación macOS nativa para la gestión de calendarios de turnos de guardia.

## Tecnología
- **Plataforma:** macOS 14+ (Sonoma)
- **UI:** SwiftUI con patrón MVVM
- **Estado:** `@Observable` (Swift 5.9+ / Observation framework)
- **Persistencia:** JSON en Application Support (`~/Library/Application Support/Guardias/data.json`)
- **Build:** `swiftc` directo (sin Xcode) — ver sección "Cómo construir"

## Cómo construir y lanzar (sin Xcode)

**IMPORTANTE:** Hay que empaquetar el binario en un `.app` bundle antes de lanzarlo.
Si se lanza el binario directamente, los campos de texto pierden el foco (macOS no lo trata como app de primer plano).

```bash
# 1. Generar icono (.icns + xcassets)
swift scripts/generate_icon.swift   # genera build/AppIcon.icns

# 2. Compilar
SDK=$(xcrun --show-sdk-path --sdk macosx)
swiftc -sdk "$SDK" -target arm64-apple-macosx14.0 \
  -framework SwiftUI -framework AppKit -framework Foundation -framework UniformTypeIdentifiers \
  Guardias/Extensions/Date+Extensions.swift \
  Guardias/Models/Worker.swift \
  Guardias/Models/GuardAssignment.swift \
  Guardias/Models/AppData.swift \
  Guardias/Services/SchedulingEngine.swift \
  Guardias/Services/BizneoService.swift \
  Guardias/Services/M365Service.swift \
  Guardias/Store/GuardiasStore.swift \
  Guardias/Views/Sheets/ManualAssignSheet.swift \
  Guardias/Views/Sheets/SwapGuardSheet.swift \
  Guardias/Views/Calendar/WeekRowView.swift \
  Guardias/Views/Calendar/CalendarGridView.swift \
  Guardias/Views/Calendar/MonthSectionView.swift \
  Guardias/Views/Calendar/GuardCalendarView.swift \
  Guardias/Views/Workers/VacationCalendarView.swift \
  Guardias/Views/Settings/EditWorkerView.swift \
  Guardias/Views/Settings/M365ConnectView.swift \
  Guardias/Views/Settings/SettingsView.swift \
  Guardias/Views/ContentView.swift \
  Guardias/GuardiasApp.swift \
  -o build/GuardiasExec

# 3. Empaquetar en .app bundle
APP=build/Guardias.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/GuardiasExec "$APP/Contents/MacOS/Guardias"
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>Guardias</string>
  <key>CFBundleIdentifier</key><string>com.guardias.app</string>
  <key>CFBundleName</key><string>Guardias</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
EOF

# 4. Firma ad-hoc (necesaria para que Gatekeeper no muestre "dañado")
codesign --deep --force --sign - "$APP"

# 5. Lanzar
pkill -x Guardias 2>/dev/null; sleep 0.3
open "$APP"
```

## Crear DMG para distribución

```bash
# Requiere haber seguido los pasos de compilación anteriores

STAGING=build/dmg_staging
rm -rf "$STAGING"; mkdir -p "$STAGING"
cp -R build/Guardias.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "Guardias" -srcfolder "$STAGING" \
  -ov -format UDZO -imagekey zlib-level=9 build/Guardias-1.0.dmg

# Subir release a GitHub
gh release upload v1.0.0 build/Guardias-1.0.dmg --clobber
```

## Estructura del proyecto

```
Guardias/
├── Extensions/         Date helpers (startOfWeek, weekdays, isSameDay)
├── Models/             Modelos de datos puros (Codable, Hashable)
│   ├── Worker          Trabajador (id, name, fullName, colorIndex, bizneoUserId)
│   ├── GuardAssignment Asignación de guardia por semana
│   └── AppData         Raíz de datos + AppSettings
├── Store/
│   └── GuardiasStore   @Observable store principal, persiste y recomputa
├── Services/
│   ├── SchedulingEngine  Algoritmo de rotación de guardias (función pura)
│   ├── BizneoService     Integración Bizneo HR (importar vacaciones)
│   └── M365Service       Integración Microsoft 365 (sincronizar guardias)
└── Views/
    ├── Calendar/       Vista principal del calendario anual de guardias
    ├── Workers/        Calendarios de vacaciones por trabajador
    ├── Sheets/         Hojas modales (swap, asignación manual)
    └── Settings/       Gestión de trabajadores, Bizneo HR y Microsoft 365
```

## Algoritmo de planificación (`SchedulingEngine`)

1. Obtiene todas las semanas (lunes) en el rango de fechas configurado
2. Para cada semana:
   - Si hay asignación manual/swap, la usa (no altera la rotación)
   - Si no, busca el siguiente trabajador disponible (rota en orden)
   - **Primera pasada:** evita guardias consecutivas del mismo trabajador
   - **Segunda pasada (fallback):** permite consecutivas si es necesario
3. Un trabajador NO está disponible si:
   - Tiene algún día de vacaciones en esa semana (L–D) — manuales o de Bizneo
   - (Si toggle activo) Tiene vacaciones la semana siguiente

## Reglas de negocio

- **Rotación equitativa:** con N trabajadores, cada uno hace guardia cada N semanas
- **Vacaciones:** cualquier día suelto bloquea toda la semana de guardia
- **Toggle "semana previa":** si activo, también bloquea la semana anterior a vacaciones
- **Swaps:** prevalecen siempre sobre la rotación automática
- **Asignaciones manuales:** almacenadas en `appData.manualAssignments`; prevalecen sobre cálculo
- **Anti-consecutivo:** el motor evita activamente que el mismo trabajador tenga guardias seguidas
- **Bizneo vacaciones:** read-only (no se pueden borrar manualmente), se muestran en rojo intenso con icono nube

## Integración Bizneo HR

- Configuración: instancia (p.ej. `alzis`) + token API en Ajustes → Bizneo HR
- Vinculación: cada trabajador se vincula a su usuario Bizneo desde Ajustes → Editar trabajador
- Sincronización: botón en el calendario de vacaciones de cada trabajador
- API: `GET /api/v1/users` (paginado, búsqueda client-side) + `GET /api/v1/users/{id}/schedules`
- Auth: query param `?token=TOKEN`
- Vacaciones Bizneo: `kind=="absence"` + `absences[].name` contiene "Vacaciones"

## Integración Microsoft 365

- Configuración: Client ID + Tenant ID desde Azure portal (App registrations)
- Permiso Azure necesario: `Calendars.ReadWrite` (delegado, Microsoft Graph)
- Auth: OAuth 2.0 Device Code Flow — no necesita redirect URI
- Flujo conexión: introducir IDs → autorizar en navegador → elegir calendario del listado
- Sincronización: botón nube en cada fila de semana (WeekRowView) y context menu
- Semanas sincronizadas: icono `cloud.fill` azul en la cuadrícula mensual
- Evento creado: todo el día L–D, subject "Guardia {nombre}", showAs: free
- Token refresh automático (5 min de margen antes de expirar)
- `appData.m365SyncedWeeks`: `[ISO-weekStart: eventId]`

## Backup

- **Exportar:** Archivo > Exportar copia de seguridad... (⌘⇧E) → JSON
- **Importar:** Archivo > Importar copia de seguridad... (⌘⇧I) → JSON
- El JSON incluye trabajadores, vacaciones (manuales + Bizneo), asignaciones manuales, semanas M365 y ajustes

## Notas de desarrollo

- Los errores de SourceKit ("Cannot find X in scope") son siempre **falsos positivos** — `swiftc` con la lista explícita de archivos compila sin errores
- El orden de los archivos en `swiftc` importa: Extensions → Models → Services → Store → Views
- Entitlement `com.apple.security.network.client` requerido para Bizneo y M365
- La firma ad-hoc (`codesign --deep --force --sign -`) es necesaria para distribuir el DMG sin que Gatekeeper muestre "dañado"
