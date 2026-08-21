import SwiftUI
import WebKit
import ServiceManagement

struct SettingsView: View {
    @Binding var coordinator: AppCoordinator
    @AppStorage(UserDefaultsKeys.pageZoom.rawValue) private var pageZoom: Double = Constants.defaultPageZoom
    @AppStorage(UserDefaultsKeys.hideWindowAtLaunch.rawValue) private var hideWindowAtLaunch: Bool = false
    @AppStorage(UserDefaultsKeys.hideDockIcon.rawValue) private var hideDockIcon: Bool = false
    @AppStorage(UserDefaultsKeys.appTheme.rawValue) private var appTheme: String = AppTheme.system.rawValue
    @AppStorage(UserDefaultsKeys.userAgentOption.rawValue) private var userAgentOption: String = UserAgentOption.safari.rawValue
    @AppStorage(UserDefaultsKeys.customUserAgent.rawValue) private var customUserAgent: String = ""
    @AppStorage(UserDefaultsKeys.panelPosition.rawValue) private var panelPosition: String = PanelPosition.bottomCenter.rawValue
    @AppStorage(UserDefaultsKeys.alwaysOnTop.rawValue) private var alwaysOnTop: Bool = false

    @State private var showingResetAlert = false
    @State private var isClearing = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            chatBarTab
                .tabItem {
                    Label("Barra Flotante", systemImage: "rectangle.bottomthird.inset.filled")
                }

            appearanceTab
                .tabItem {
                    Label("Apariencia", systemImage: "paintbrush")
                }

            advancedTab
                .tabItem {
                    Label("Avanzado", systemImage: "slider.horizontal.3")
                }

            aboutTab
                .tabItem {
                    Label("Acerca de", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 380)
        .alert("¿Restablecer datos de navegación?", isPresented: $showingResetAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Restablecer", role: .destructive) { clearWebsiteData() }
        } message: {
            Text("Esto eliminará las cookies, la memoria caché y las sesiones activas. Tendrás que iniciar sesión en Gemini nuevamente.")
        }
    }

    // MARK: - General Tab
    private var generalTab: some View {
        Form {
            Section {
                Toggle("Iniciar Gemini Desktop al encender la Mac", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            try newValue ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                        } catch { launchAtLogin = !newValue }
                    }

                Toggle("Ocultar ventana principal al iniciar", isOn: $hideWindowAtLaunch)

                Toggle("Ocultar ícono del Dock (modo solo barra de menú)", isOn: $hideDockIcon)
                    .onChange(of: hideDockIcon) { _, newValue in
                        NSApp.setActivationPolicy(newValue ? .accessory : .regular)
                    }

                Toggle("Mantener ventana siempre al frente (Always on Top)", isOn: $alwaysOnTop)
                    .onChange(of: alwaysOnTop) { _, _ in
                        coordinator.applyAlwaysOnTop()
                    }
            } header: {
                Text("Comportamiento del Sistema")
            } footer: {
                Text("Si ocultas el ícono del Dock, la aplicación seguirá accesible desde el ícono de la barra de menús superior.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    // MARK: - Chat Bar Tab
    private var chatBarTab: some View {
        Form {
            Section("Ubicación y Visualización") {
                Picker("Posición en pantalla:", selection: $panelPosition) {
                    ForEach([PanelPosition.bottomCenter, .bottomLeft, .bottomRight], id: \.rawValue) { pos in
                        Text(pos.displayName).tag(pos.rawValue)
                    }
                    Divider()
                    Text(PanelPosition.rememberLast.displayName).tag(PanelPosition.rememberLast.rawValue)
                }
                .onChange(of: panelPosition) { _, _ in
                    coordinator.resetChatBarPosition()
                }

                HStack {
                    Text("Atajo de Teclado Global:")
                    Spacer()
                    Text("⌘ ⇧ G")
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(6)
                }
            }

            Section("Acciones Rápidas") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("•")
                        Text("Presiona **ESC** para ocultar el prompt flotante al instante.")
                    }
                    HStack {
                        Text("•")
                        Text("Presiona **⌘ N** dentro del prompt para iniciar una nueva consulta y compactar la vista.")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    // MARK: - Appearance Tab
    private var appearanceTab: some View {
        Form {
            Section("Tema de la Aplicación") {
                Picker("Tema:", selection: $appTheme) {
                    ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                        Text(theme.displayName).tag(theme.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: appTheme) { _, newValue in
                    (AppTheme(rawValue: newValue) ?? .system).apply()
                }
            }

            Section("Tamaño del Texto y Zoom") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Escala:")
                        Spacer()
                        Text("\(Int((pageZoom * 100).rounded()))%")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "textformat.size.smaller")
                            .foregroundStyle(.secondary)

                        Slider(
                            value: $pageZoom,
                            in: Constants.minPageZoom...Constants.maxPageZoom,
                            step: Constants.pageZoomStep
                        )
                        .onChange(of: pageZoom) { _, newValue in
                            coordinator.webViewModel.wkWebView.pageZoom = newValue
                        }

                        Image(systemName: "textformat.size.larger")
                            .foregroundStyle(.secondary)

                        Button("100%") {
                            pageZoom = Constants.defaultPageZoom
                            coordinator.webViewModel.wkWebView.pageZoom = Constants.defaultPageZoom
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    // MARK: - Advanced Tab
    private var advancedTab: some View {
        Form {
            Section("Identidad del Navegador (User Agent)") {
                Picker("Navegador:", selection: $userAgentOption) {
                    ForEach(UserAgentOption.allCases, id: \.rawValue) { option in
                        Text(option.displayName).tag(option.rawValue)
                    }
                }
                .onChange(of: userAgentOption) { _, _ in
                    coordinator.webViewModel.applyUserAgent()
                }

                if userAgentOption == UserAgentOption.custom.rawValue {
                    TextField("User Agent Personalizado", text: $customUserAgent, prompt: Text("Ej: Mozilla/5.0..."))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            coordinator.webViewModel.applyUserAgent()
                        }
                }

                Text(currentUserAgentDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Sesión y Caché") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Restablecer Datos Web")
                            .font(.body)
                        Text("Elimina cookies, caché de navegación y reinicia el login.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Restablecer...", role: .destructive) {
                        showingResetAlert = true
                    }
                    .disabled(isClearing)
                    .overlay {
                        if isClearing {
                            ProgressView().scaleEffect(0.6)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    // MARK: - About Tab
    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()

            if let img = Bundle.main.image(forResource: "NativeIcon") ??
                         Bundle.main.image(forResource: "AppIcon") ??
                         NSImage(contentsOfFile: "NativeIcon.png") ??
                         NSImage(contentsOfFile: "Resources/AppIcon.icns") ??
                         NSApp.applicationIconImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 84, height: 84)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            }

            VStack(spacing: 4) {
                Text("Gemini Desktop")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Versión 1.0.0 (Intel x86_64)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Diseñado para macOS Sonoma y Sequoia")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 12) {
                Text("WebKit Nativo")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(10)

                Text("Passkeys & Touch ID")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(10)

                Text("Swift 5.9+")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(10)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var currentUserAgentDescription: String {
        let option = UserAgentOption(rawValue: userAgentOption) ?? .safari
        return option.settingsDescription(custom: customUserAgent)
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

extension SettingsView {
    struct Constants {
        static let defaultPageZoom: Double = 1.0
        static let minPageZoom: Double = 0.6
        static let maxPageZoom: Double = 1.4
        static let pageZoomStep: Double = 0.05
    }
}

