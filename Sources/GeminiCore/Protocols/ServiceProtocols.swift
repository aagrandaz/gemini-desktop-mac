//
//  ServiceProtocols.swift
//  GeminiCore
//
//  Autor: aagrandaz@gmail.com
//

import Foundation

/// Contrato para la administración e inspección de carpetas locales conectadas a Gemini.
@MainActor
public protocol FolderManaging: AnyObject {
    /// Lista de carpetas actualmente vinculadas y persistidas en preferencias.
    var folders: [ConnectedFolder] { get }
    /// Carpeta actualmente seleccionada en la interfaz de usuario.
    var selectedFolder: ConnectedFolder? { get set }

    /// Abre un panel modal del sistema (`NSOpenPanel`) para que el usuario elija carpetas locales.
    func addFolderFromPicker()
    /// Vincula una carpeta local a partir de su URL de archivo y genera un bookmark de seguridad.
    /// - Parameter url: URL local del directorio a agregar.
    func addFolder(url: URL)
    /// Elimina una carpeta conectada dado su identificador único.
    /// - Parameter id: Identificador único `UUID` de la carpeta a remover.
    func removeFolder(id: UUID)
    /// Elimina carpetas conectadas en las posiciones especificadas por un conjunto de índices.
    /// - Parameter indexSet: Índices a remover de la colección de carpetas.
    func removeFolder(at indexSet: IndexSet)
    /// Escanea de forma recursiva los archivos contenidos en la carpeta especificada.
    /// - Parameter folder: Carpeta conectada a inspeccionar.
    /// - Returns: Arreglo de estructuras `LocalFileInfo` con el detalle de archivos encontrados.
    func scanFiles(in folder: ConnectedFolder) -> [LocalFileInfo]
    /// Genera un resumen textual formateado con el árbol y estadísticas de archivos para inyectar como prompt a Gemini.
    /// - Parameter folder: Carpeta cuyo contexto será resumido.
    /// - Returns: Texto descriptivo estructurado listo para ser consumido por el modelo.
    func generateContextSummary(for folder: ConnectedFolder) -> String
}

/// Contrato para el registro y gestión de atajos de teclado globales a nivel de sistema operativo.
public protocol HotkeyManaging: AnyObject {
    /// Clausura ejecutada cuando el atajo de teclado configurado es detectado por el sistema.
    var onHotKeyTriggered: (() -> Void)? { get set }
    /// Registra el atajo de teclado global por defecto con el manejador de eventos del sistema operativo.
    /// - Parameter action: Clausura a ejecutar cada vez que se presione la combinación de teclas.
    func registerDefaultShortcut(action: @escaping () -> Void)
    /// Desregistra el atajo activo liberando los recursos de Carbon / EventDispatcher.
    func unregister()
}

/// Contrato único de persistencia y fuente de verdad (Single Source of Truth) para las preferencias de la aplicación.
@MainActor
public protocol PreferencesStoring: AnyObject {
    /// Ancho en puntos de la barra de chat emergente.
    var panelWidth: Double { get set }
    /// Alto en puntos de la barra de chat emergente.
    var panelHeight: Double { get set }
    /// Coordenada horizontal X opcional de la última posición del panel flotante.
    var panelX: Double? { get set }
    /// Coordenada vertical Y opcional de la última posición del panel flotante.
    var panelY: Double? { get set }
    /// Posición configurada para la barra emergente en pantalla.
    var panelPosition: PanelPosition { get set }
    /// Factor de escala visual o zoom del contenido web.
    var pageZoom: Double { get set }
    /// Indica si la ventana principal debe permanecer oculta tras el arranque.
    var hideWindowAtLaunch: Bool { get set }
    /// Indica si el ícono de la app debe ocultarse del Dock de macOS.
    var hideDockIcon: Bool { get set }
    /// Determina si la ventana principal se mantiene sobre las demás aplicaciones.
    var alwaysOnTop: Bool { get set }
    /// Tema visual preferido (sistema, claro, oscuro).
    var appTheme: AppTheme { get set }
    /// Estrategia de identificación de navegador web (User Agent).
    var userAgentOption: UserAgentOption { get set }
    /// Cadena User Agent personalizada cuando se activa la opción correspondiente.
    var customUserAgent: String { get set }
    /// Resuelve la cadena final de User Agent lista para asignarse a `WKWebView`.
    var currentUserAgentString: String { get }

    // Spark & Intelligence Settings
    /// Controla la presencia del ícono de estado en la barra de menús de macOS.
    var showInMenuBar: Bool { get set }
    /// Determina si la app se ejecuta al iniciar sesión en el equipo.
    var openAtLogin: Bool { get set }
    /// Habilita la recepción y procesamiento de tareas remotas en segundo plano.
    var sparkRemoteTasksEnabled: Bool { get set }
    /// Impide que la Mac entre en reposo durante el procesamiento de tareas.
    var sparkKeepMacAwake: Bool { get set }
    /// Muestra advertencias de respaldo preventivo antes de modificaciones en disco.
    var sparkBackupAlertEnabled: Bool { get set }
    /// Habilita la memoria persistente contextual de Gemini.
    var memoryEnabled: Bool { get set }
    /// Aplica análisis y razonamiento previo en el dictado por voz Speak-to-Window.
    var speakToWindowReasoning: Bool { get set }
    /// Nombre de la voz sintetizada configurada para respuestas de audio.
    var voiceSelection: String { get set }

    // Connected Apps
    /// Habilita la extensión de Google Workspace en la interfaz web.
    var appGoogleWorkspaceEnabled: Bool { get set }
    /// Habilita la extensión de Búsqueda de Google en la interfaz web.
    var appSearchServicesEnabled: Bool { get set }
    /// Habilita la extensión de Google Fotos en la interfaz web.
    var appGooglePhotosEnabled: Bool { get set }
    /// Habilita la extensión de YouTube en la interfaz web.
    var appYouTubeEnabled: Bool { get set }

    // Debug & Connected Folders
    /// Controla el envío de reportes de diagnóstico y telemetría.
    var debugTelemetryEnabled: Bool { get set }
    /// Colección de carpetas de macOS conectadas persistidas.
    var connectedFolders: [ConnectedFolder] { get set }
}
