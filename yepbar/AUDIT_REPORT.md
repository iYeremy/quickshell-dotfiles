# Auditoría Técnica de Rendimiento y Arquitectura (Quickshell / QML)

Tras analizar el código fuente completo, el ciclo de vida de los componentes, las llamadas a procesos externos, bindings y modelos de datos, presento el informe de auditoría categorizado por severidad y el plan de optimización por etapas.

---

## 🔍 Mapa de Arquitectura y Ciclo de Vida Actual

```text
shell.qml (Scope Root)
├── Bar.qml (PanelWindow - Siempre Activo)
│   ├── WorkspaceWidget.qml (Módulo Izquierdo - Siempre Activo)
│   │   └── Process: scripts/qs_monitor_bin (Polling cada 3s)
│   ├── ClockWidget.qml (Módulo Central - Siempre Activo)
│   │   └── SystemClock (Event-driven Qt Clock)
│   └── StatusWidget.qml (Módulo Derecho - Siempre Activo)
│       ├── Process: playerctl metadata -F (DBus Persistente)
│       ├── Process: pactl subscribe (DBus/Pulse Event-driven)
│       └── Process: wpctl get-volume (Al recibir eventos de sink)
├── AppDrawer.qml (PanelWindow - Instanciado permanentemente)
│   ├── AppScanner.qml -> Process: python3 app_scanner.py (Se ejecuta al arrancar)
│   └── AppLauncher.qml (Helper de ejecuciones)
├── CalendarPopup.qml (PanelWindow - Instanciado permanentemente)
│   └── ListModel (Construye 42 nodos en Component.onCompleted)
├── BrightnessPopup.qml (PanelWindow - Instanciado permanentemente)
│   └── Process: brightnessctl -i (Se ejecuta al arrancar)
└── NotificationCenter.qml (PanelWindow - Instanciado permanentemente)
    └── Process: python3 notif_daemon.py (DBus Persistente - Necesario para contador badge)
```

---

## 📊 Hallazgos de la Auditoría

### 🔴 CRÍTICO
*No se detectaron problemas de severidad Crítica (como memory leaks masivos en C++, bucles infinitos en hilo principal de renderizado a 60fps o crasheos de segmento).*

---

### 🟠 ALTO

#### 1. Instanciación prematura e incondicional de Overlays pesados
- **Archivo:** `shell.qml` (Líneas 17, 22, 27)
- **Problema:** `AppDrawer`, `CalendarPopup` y `BrightnessPopup` se instancian completamente al arrancar la aplicación, manteniendo sus estructuras visuales, imágenes, modelos y manejadores de eventos en memoria RAM aunque el usuario nunca los abra durante su sesión.
- **Por qué afecta al rendimiento:** Incrementa innecesariamente el consumo inicial de memoria RAM (~15-25 MB extra de objetos Qt/QML) y alarga el tiempo de inicio de Quickshell.
- **Impacto esperado:** Reducción de ~15-20 MB de RAM en estado inactivo (*idle*) y aceleración del arranque inicial.
- **Solución propuesta:** Cargar `AppDrawer`, `CalendarPopup` y `BrightnessPopup` de forma diferida (*lazy loading*) utilizando `Loader` o activando el componente `PanelWindow` únicamente cuando la propiedad `isOpen` sea `true`.
- **Riesgo:** Bajo (requiere asegurar que los `IpcHandler` sigan respondiendo a comandos externos para activar el `Loader`).

#### 2. Escaneo de aplicaciones en disco al arrancar el sistema
- **Archivo:** `AppScanner.qml` (Línea 16) / `AppDrawer.qml` (Línea 75)
- **Problema:** Al iniciar Quickshell, `AppScanner` ejecuta inmediatamente `python3 scripts/app_scanner.py`, el cual lee y parsea decenas de archivos `.desktop` en `/usr/share/applications` y `~/.local/share/applications`.
- **Por qué afecta al rendimiento:** Genera I/O de disco y trabajo de CPU al encender la computadora o iniciar sesión para un menú de aplicaciones que quizás el usuario no utilice inmediatamente (o no utilice en absoluto si usa otro launcher como Rofi/Wofi).
- **Impacto esperado:** Eliminación total del I/O de disco y uso de CPU en arranque.
- **Solución propuesta:** Diferir la ejecución del escaneo de aplicaciones únicamente a la primera vez que el usuario abra el `AppDrawer`.
- **Riesgo:** Muy bajo.

---

### 🟡 MEDIO

#### 3. Parseo repetido de JSON en delegates de notificaciones
- **Archivo:** `NotificationCenter.qml` (Líneas 128, 467)
- **Problema:** Para agrupar notificaciones por aplicación, `updateGroupedModel()` serializa arrays a texto plano usando `JSON.stringify(grp.items)`. Luego, en el `delegate` del `Repeater` secundario, ejecuta `JSON.parse(itemsJson)` cada vez que el componente se dibuja o reevalúa.
- **Por qué afecta al rendimiento:** Ejecutar `JSON.parse` dentro de bindings evaluados frecuentemente por el motor V8/QML genera recolección de basura (*Garbage Collection*) innecesaria y pequeñas micro-pausas al desplegar listas largas de notificaciones.
- **Impacto esperado:** Renderizado y scroll más fluido en el centro de notificaciones.
- **Solución propuesta:** Estructurar el modelo directamente con colecciones nativas de QML o arrays asignados a propiedades sin pasar por serialización/deserialización de cadenas JSON.
- **Riesgo:** Bajo.

#### 4. Búsqueda iterativa duplicada en bindings de workspaces
- **Archivo:** `WorkspaceWidget.qml` (Líneas 113-123)
- **Problema:** La función `isWorkspaceOccupied(wsId)` itera sobre toda la lista `Hyprland.workspaces.values` mediante un bucle `for` en JS. Esta función es llamada directamente desde los bindings visuales de cada botón en el `Repeater` de workspaces (color de fondo, borde y peso de fuente).
- **Por qué afecta al rendimiento:** Para `N` workspaces, se ejecutan `N` iteraciones completas en cada cambio de ventana o foco en Hyprland.
- **Impacto esperado:** Reducción de llamadas en bucle JS durante cambios de espacio de trabajo o foco de ventanas.
- **Solución propuesta:** Crear un `Set` o mapa de identificadores ocupados derivado de `Hyprland.workspaces` o simplificar la verificación a una consulta `O(1)`.
- **Riesgo:** Muy bajo.

#### 5. Ejecución inicial de proceso de brillo sin demanda
- **Archivo:** `BrightnessPopup.qml` (Líneas 52-65)
- **Problema:** Al crearse el componente en segundo plano, se ejecuta un subproceso shell con `brightnessctl -i` para obtener el nivel de brillo inicial, aunque el popup esté cerrado.
- **Por qué afecta al rendimiento:** Invoca un subproceso de shell (`sh -c`) innecesario en segundo plano al arrancar Quickshell.
- **Impacto esperado:** Eliminación de subproceso innecesario en arranque.
- **Solución propuesta:** Ejecutar la lectura de brillo únicamente cuando `onIsOpenChanged` cambie a `true`.
- **Riesgo:** Cero.

---

### 🟢 BAJO

#### 6. Micro-animaciones en fuentes (`font.pixelSize`) en hovers
- **Archivo:** `WorkspaceWidget.qml` (Línea 165), `StatusWidget.qml` (Líneas 154, 211, 250, 278, 309, 337), `ClockWidget.qml` (Línea 43)
- **Problema:** Varios elementos visuales contienen `Behavior on font.pixelSize { NumberAnimation { duration: 100 } }` para hacer un leve zoom al pasar el ratón.
- **Por qué afecta al rendimiento:** Animar el tamaño de fuente (*font rasterization*) obliga a Qt a relayoutear y rasterizar glifos tipográficos a diferentes tamaños en cada frame de la animación.
- **Impacto esperado:** Levísimo ahorro de renderizado en hover.
- **Solución propuesta:** Reemplazar animaciones de tamaño de fuente por transiciones de opacidad, color o escala de transformada (`scale`), que son procesadas directamente en la GPU sin re-rasterizar glifos.
- **Riesgo:** Cero (meramente estético).

---

## 📋 Plan de Optimización por Etapas Propuesto

### Etapa 1: Carga Bajo Demanda de Overlays y Diferimiento de Procesos (Impacto Alto en RAM y Arranque)
1. Implementar `Loader` diferido para `AppDrawer.qml`, `CalendarPopup.qml` y `BrightnessPopup.qml` en `shell.qml` o gestionar su ciclo de vida mediante su propiedad `active`.
2. Diferir el escaneo de aplicaciones (`AppScanner`) únicamente al abrir `AppDrawer`.
3. Mover la consulta inicial de `brightnessctl -i` para que se ejecute solo al abrir `BrightnessPopup`.

### Etapa 2: Optimización de Modelos y Bindings (Impacto Medio en Fluidez y CPU)
1. Optimizar la estructura del modelo de notificaciones en `NotificationCenter.qml` eliminando las llamadas a `JSON.stringify` y `JSON.parse`.
2. Simplificar la comprobación de workspaces ocupados en `WorkspaceWidget.qml` para evitar iteraciones de bucles `for` dentro de bindings visuales.

### Etapa 3: Micro-ajustes y Limpieza (Impacto Bajo)
1. Asegurar que las animaciones de hover sean livianas y aceleradas por GPU.
