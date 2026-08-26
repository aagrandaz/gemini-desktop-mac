//
//  SettingsView.swift
//  GeminiDesktop
//
//  Created on 2026-08-25.
//

import SwiftUI
import WebKit
import ServiceManagement

public enum SettingsCategory: String, CaseIterable, Identifiable {
    case appearance = "Apariencia"
    case shortcuts = "Accesos directos"
    case customIntelligence = "Inteligencia personalizada"
    case connectedApps = "Apps conectadas"
    case geminiVoice = "Voz de Gemini"
    case speakToWindow = "Speak to Window"
    case geminiSpark = "Gemini Spark"
    case usageLimits = "Límites de uso"
    case about = "Acerca de la app"
    case debug = "Depuración"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .appearance: return "paintbrush"
        case .shortcuts: return "command"
        case .customIntelligence: return "brain"
        case .connectedApps: return "square.stack.3d.up"
        case .geminiVoice: return "waveform"
        case .speakToWindow: return "mic.and.signal.meter"
        case .geminiSpark: return "sparkles"
        case .usageLimits: return "chart.bar"
        case .about: return "info.circle"
        case .debug: return "ladybug"
        }
    }
}

struct SettingsView: View {
    @Binding var coordinator: AppCoordinator

    // Settings Storage
    @AppStorage(UserDefaultsKeys.appTheme.rawValue) private var appTheme: String = AppTheme.system.rawValue
    @AppStorage(UserDefaultsKeys.showInMenuBar.rawValue) private var showInMenuBar: Bool = true
    @AppStorage(UserDefaultsKeys.openAtLogin.rawValue) private var openAtLogin: Bool = false
    @AppStorage(UserDefaultsKeys.panelPosition.rawValue) private var panelPosition: String = PanelPosition.bottomCenter.rawValue
    @AppStorage(UserDefaultsKeys.pageZoom.rawValue) private var pageZoom: Double = 1.0

    // Spark & Intelligence Settings
    @AppStorage(UserDefaultsKeys.sparkRemoteTasksEnabled.rawValue) private var sparkRemoteTasks: Bool = true
    @AppStorage(UserDefaultsKeys.sparkKeepMacAwake.rawValue) private var sparkKeepAwake: Bool = true
    @AppStorage(UserDefaultsKeys.sparkBackupAlertEnabled.rawValue) private var sparkBackupAlert: Bool = true
    @AppStorage(UserDefaultsKeys.memoryEnabled.rawValue) private var memoryEnabled: Bool = true
    @AppStorage(UserDefaultsKeys.speakToWindowReasoning.rawValue) private var speakToWindowReasoning: Bool = true
    @AppStorage(UserDefaultsKeys.voiceSelection.rawValue) private var voiceSelection: String = "Orbit"

    // Connected Apps
    @AppStorage(UserDefaultsKeys.appGoogleWorkspaceEnabled.rawValue) private var appWorkspace: Bool = true
    @AppStorage(UserDefaultsKeys.appSearchServicesEnabled.rawValue) private var appSearch: Bool = true
    @AppStorage(UserDefaultsKeys.appGooglePhotosEnabled.rawValue) private var appPhotos: Bool = true
    @AppStorage(UserDefaultsKeys.appYouTubeEnabled.rawValue) private var appYouTube: Bool = true

    // Advanced & Debug
    @AppStorage(UserDefaultsKeys.userAgentOption.rawValue) private var userAgentOption: String = UserAgentOption.safari.rawValue
    @AppStorage(UserDefaultsKeys.customUserAgent.rawValue) private var customUserAgent: String = ""
    @AppStorage(UserDefaultsKeys.debugTelemetryEnabled.rawValue) private var debugTelemetry: Bool = true

    @State private var selectedCategory: SettingsCategory = .appearance
    @State private var showingResetAlert = false
    @State private var isClearing = false

    var body: some View {
        NavigationSplitView {
            List(SettingsCategory.allCases, selection: $selectedCategory) { category in
                NavigationLink(value: category) {
                    Label(category.rawValue, systemImage: category.icon)
                        .font(.system(size: 13))
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200, idealWidth: 220)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    categoryDetailView(for: selectedCategory)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 720, height: 480)
        .alert("¿Restablecer datos de navegación?", isPresented: $showingResetAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Restablecer", role: .destructive) { clearWebsiteData() }
        } message: {
            Text("Esto eliminará cookies, caché y sesiones activas de Gemini.")
        }
    }

    @ViewBuilder
    private func categoryDetailView(for category: SettingsCategory) -> some View {
        switch category {
        case .appearance:
            appearanceSection
        case .shortcuts:
            shortcutsSection
        case .customIntelligence:
            customIntelligenceSection
        case .connectedApps:
            connectedAppsSection
        case .geminiVoice:
            geminiVoiceSection
        case .speakToWindow:
            speakToWindowSection
        case .geminiSpark:
            geminiSparkSection
        case .usageLimits:
            usageLimitsSection
        case .about:
            aboutSection
        case .debug:
            debugSection
        }
    }

    // MARK: - 1. Apariencia
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Apariencia")
                .font(.title2).bold()

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tema")
                        .font(.headline)
                    Picker("", selection: $appTheme) {
                        ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                            Text(theme.displayName).tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: appTheme) { _, newValue in
                        (AppTheme(rawValue: newValue) ?? .system).apply()
                    }
                }

                Divider()

                Toggle("Mostrar en la barra de menú", isOn: $showInMenuBar)

                Toggle("Abrir al acceder", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, newValue in
                        try? (newValue ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister())
                    }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Escala del Zoom Web:")
                        Spacer()
                        Text("\(Int((pageZoom * 100).rounded()))%")
                            .fontWeight(.semibold)
                    }
                    Slider(value: $pageZoom, in: 0.7...1.3, step: 0.05)
                        .onChange(of: pageZoom) { _, val in
                            coordinator.webViewModel.wkWebView.pageZoom = val
                        }
                }
            }
        }
    }

    // MARK: - 2. Accesos Directos
    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Accesos directos")
                .font(.title2).bold()

            VStack(alignment: .leading, spacing: 14) {
                ShortcutRow(title: "Combinación de teclas para el chat pequeño", shortcut: "⌥ Espacio")
                ShortcutRow(title: "Combinación de teclas para abrir el chat completo", shortcut: "⌥⇧ Espacio")

                Divider()

                Picker("Posición en la pantalla:", selection: $panelPosition) {
                    ForEach([PanelPosition.bottomCenter, .bottomLeft, .bottomRight, .rememberLast], id: \.rawValue) { pos in
                        Text(pos.displayName).tag(pos.rawValue)
                    }
                }

                Divider()

                ShortcutRow(title: "Atajo para realizar capturas de pantalla con Lazo", shortcut: "⇧⌘6")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Speak to Window")
                        .font(.headline)
                    HStack {
                        Text("Presionar dos veces fn / 🌐")
                        Spacer()
                        Text("Activo").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Mantener presionado fn / 🌐")
                        Spacer()
                        Text("Hablar mientras se presiona").foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - 3. Inteligencia Personalizada
    private var customIntelligenceSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Inteligencia personalizada")
                .font(.title2).bold()

            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $memoryEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Memoria")
                            .font(.headline)
                        Text("Gemini recuerda detalles y preferencias compartidos para personalizar futuras respuestas.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Instrucciones para Gemini")
                            .font(.headline)
                        Text("Personaliza el comportamiento, tono y estilo de respuesta de Gemini.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Administrar") {
                        coordinator.loadURL("https://gemini.google.com/app")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - 4. Apps Conectadas
    private var connectedAppsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Apps conectadas")
                .font(.title2).bold()

            Text("Conecta las extensiones de Google para acceder a tus contenidos e información en tiempo real.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                ConnectedAppToggle(title: "Google Workspace", subtitle: "Gmail, Google Docs y Google Drive", icon: "doc.text", isOn: $appWorkspace)
                ConnectedAppToggle(title: "Servicios de la Búsqueda", subtitle: "Información y datos actualizados de la Web", icon: "globe", isOn: $appSearch)
                ConnectedAppToggle(title: "Google Fotos", subtitle: "Buscar y hacer referencia a tus fotografías", icon: "photo.stack", isOn: $appPhotos)
                ConnectedAppToggle(title: "YouTube", subtitle: "Buscar videos, transcripciones y música", icon: "play.rectangle", isOn: $appYouTube)
            }
        }
    }

    // MARK: - 5. Voz de Gemini
    private var geminiVoiceSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Voz de Gemini")
                .font(.title2).bold()

            Text("Elige la voz que utilizará Gemini cuando responda de forma hablada.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 10) {
                ForEach(["Orbit", "Mira", "Vega", "Lyra", "Capella"], id: \.self) { voice in
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.blue)
                        Text(voice)
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        if voiceSelection == voice {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(voiceSelection == voice ? Color.blue.opacity(0.12) : Color.white.opacity(0.04))
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .onTapGesture { voiceSelection = voice }
                }
            }
        }
    }

    // MARK: - 6. Speak to Window
    private var speakToWindowSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Speak to Window")
                .font(.title2).bold()

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $speakToWindowReasoning) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Usar razonamiento")
                            .font(.headline)
                        Text("Permite a Gemini analizar el contexto antes de transcribir o ejecutar la acción de voz.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Escribe en cualquier lugar solo con tu voz.")
                        .font(.headline)
                    Text("Te presentamos Habla en la ventana. Mantén presionada la tecla Fn para dictar en cualquier campo de texto o aplicación activa en tu Mac.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
            }
        }
    }

    // MARK: - 7. Gemini Spark
    private var geminiSparkSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Gemini Spark")
                    .font(.title2).bold()
                Text("BETA")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $sparkRemoteTasks) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ejecuta tareas de forma remota desde otros dispositivos")
                            .font(.headline)
                        Text("Permite coordinar tareas y agentes autónomos de Spark entre tus Macs y teléfonos.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                Toggle(isOn: $sparkKeepAwake) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mantener esta Mac activa para ejecutar tareas")
                            .font(.headline)
                        Text("Evita que la Mac entre en reposo mientras Spark procesa flujos de trabajo largos.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                Toggle(isOn: $sparkBackupAlert) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recibir una alerta cuando no se pueda crear una copia de seguridad")
                            .font(.headline)
                        Text("Gemini pide aprobación antes de continuar con una tarea cuando no puede crear una copia de seguridad de un archivo en una carpeta conectada.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - 8. Límites de Uso
    private var usageLimitsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Límites de uso")
                .font(.title2).bold()

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Uso actual")
                            .font(.headline)
                        Spacer()
                        Text("18% usado")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    ProgressView(value: 0.18)
                        .tint(.blue)
                    Text("Se restablece a las 00:00 UTC")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Límite semanal")
                            .font(.headline)
                        Spacer()
                        Text("1% usado")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    ProgressView(value: 0.01)
                        .tint(.green)
                    Text("Se restablece el próximo lunes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
            }
        }
    }

    // MARK: - 9. Acerca de la App
    private var aboutSection: some View {
        VStack(spacing: 16) {
            if let icon = NSImage(contentsOfFile: "/Users/aagrandaz/gemini-desktop-mac/AppIcon.icns") ?? NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 80, height: 80)
            }

            VStack(spacing: 4) {
                Text("Gemini Desktop")
                    .font(.title2).bold()
                Text("Versión 1.1.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Optimizado para macOS con soporte completo de Apple Silicon e Intel")
                    .font(.caption)
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }

            HStack(spacing: 10) {
                Text("Spark BETA")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(6)

                Text("Carpetas Conectadas")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(6)

                Text("Passkeys & WebKit")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 20)
    }

    // MARK: - 10. Depuración
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Depuración")
                .font(.title2).bold()

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $debugTelemetry) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enviar automáticamente informes de fallas y estadísticas de uso a Google")
                            .font(.headline)
                        Text("Ayuda a mejorar la estabilidad y rendimiento de la app.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Identidad del Navegador (User Agent)")
                        .font(.headline)
                    Picker("", selection: $userAgentOption) {
                        ForEach(UserAgentOption.allCases, id: \.rawValue) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    }
                    .onChange(of: userAgentOption) { _, _ in
                        coordinator.webViewModel.applyUserAgent()
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Restablecer Datos Web y Sesiones")
                            .font(.headline)
                        Text("Borra cookies, caché y reinicia el inicio de sesión.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Restablecer...", role: .destructive) {
                        showingResetAlert = true
                    }
                }
            }
        }
    }

    private func clearWebsiteData() {
        isClearing = true
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        dataStore.fetchDataRecords(ofTypes: types) { records in
            dataStore.removeData(ofTypes: types, for: records) {
                DispatchQueue.main.async {
                    isClearing = false
                    coordinator.webViewModel.reload()
                }
            }
        }
    }
}

// MARK: - Helper Views
struct ShortcutRow: View {
    let title: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
        }
    }
}

struct ConnectedAppToggle: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}
