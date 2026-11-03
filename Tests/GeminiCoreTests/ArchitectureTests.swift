//
//  ArchitectureTests.swift
//  GeminiCoreTests
//
//  Autor: aagrandaz@gmail.com
//

import XCTest
import Foundation
import WebKit
@testable import GeminiCore
@testable import GeminiWebBridge
@testable import GeminiAppKit

/// Suite de pruebas automatizadas que valida los contratos arquitectónicos, desacoplamiento de dependencias y reactividad.
final class ArchitectureTests: XCTestCase {

    /// Valida que `PreferencesRepository` persista adecuadamente valores primitivos y estructuras complejas en `UserDefaults`.
    @MainActor
    func testPreferencesRepositoryPersistence() {
        let testSuiteName = "com.geminidesktop.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: testSuiteName)!
        defer { defaults.removePersistentDomain(forName: testSuiteName) }

        let repo = PreferencesRepository(defaults: defaults)

        // Verificación de valores por defecto
        XCTAssertEqual(repo.appTheme, .system)
        XCTAssertEqual(repo.pageZoom, 1.0)
        XCTAssertTrue(repo.showInMenuBar)

        // Mutación y persistencia
        repo.appTheme = .dark
        repo.pageZoom = 1.25
        repo.alwaysOnTop = true
        repo.panelWidth = 650
        repo.panelHeight = 350

        // Nueva instancia leyendo del mismo suite
        let reloadedRepo = PreferencesRepository(defaults: defaults)
        XCTAssertEqual(reloadedRepo.appTheme, .dark)
        XCTAssertEqual(reloadedRepo.pageZoom, 1.25)
        XCTAssertTrue(reloadedRepo.alwaysOnTop)
        XCTAssertEqual(reloadedRepo.panelWidth, 650)
        XCTAssertEqual(reloadedRepo.panelHeight, 350)
    }

    /// Valida que `LocalFolderManager` gestione correctamente la colección de carpetas sincronizándose con `PreferencesStoring`.
    @MainActor
    func testLocalFolderManagerWithMockPreferences() {
        let mockPrefs = MockPreferences()
        let manager = LocalFolderManager(preferences: mockPrefs)

        XCTAssertTrue(manager.folders.isEmpty)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        manager.addFolder(url: tempDir)

        XCTAssertEqual(manager.folders.count, 1)
        XCTAssertEqual(manager.folders.first?.path, tempDir.path)
        XCTAssertEqual(mockPrefs.connectedFolders.count, 1)

        if let firstID = manager.folders.first?.id {
            manager.removeFolder(id: firstID)
            XCTAssertTrue(manager.folders.isEmpty)
            XCTAssertTrue(mockPrefs.connectedFolders.isEmpty)
        }
    }

    /// Valida que `AppEventBus` transmita eventos a través de `AsyncStream` sin pérdidas ni bloqueos en concurrencia.
    @MainActor
    func testAppEventBusAsyncStream() async {
        let bus = AppEventBus()
        let expectation = XCTestExpectation(description: "Event received")

        let task = Task { @MainActor in
            for await event in bus.stream() {
                if event == .openMainWindow {
                    expectation.fulfill()
                    break
                }
            }
        }

        // Permite que la tarea inicie su iteración en el stream
        try? await Task.sleep(nanoseconds: 50_000_000)

        bus.send(.openMainWindow)

        await fulfillment(of: [expectation], timeout: 2.0)
        task.cancel()
    }

    /// Valida la decodificación defensiva de mensajes WebKit en `WebScriptMessageHandler`.
    func testWebScriptMessageHandlerParsing() {
        let validAdd: [String: Any] = ["action": "addFolder"]
        XCTAssertEqual(WebScriptMessageHandler.parseSparkFolderAction(from: validAdd), .addFolder)

        let testUUID = UUID()
        let validRemove: [String: Any] = ["action": "removeFolder", "id": testUUID.uuidString]
        XCTAssertEqual(WebScriptMessageHandler.parseSparkFolderAction(from: validRemove), .removeFolder(testUUID))

        let validGet: [String: Any] = ["action": "getConnectedFolders"]
        XCTAssertEqual(WebScriptMessageHandler.parseSparkFolderAction(from: validGet), .getConnectedFolders)

        let validAttach: [String: Any] = ["action": "attachFolderContext", "id": testUUID.uuidString]
        XCTAssertEqual(WebScriptMessageHandler.parseSparkFolderAction(from: validAttach), .attachFolderContext(testUUID))

        let invalid: [String: Any] = ["action": "unknownAction"]
        XCTAssertNil(WebScriptMessageHandler.parseSparkFolderAction(from: invalid))
    }

    /// Valida que `GeminiWebBridge` interactúe correctamente con el protocolo `FolderManaging` inyectado.
    @MainActor
    func testGeminiWebBridgeUsesInjectedFolderManager() {
        let mockFolderManager = MockFolderManager()
        let bridge = GeminiWebBridge(folderManager: mockFolderManager)

        let testID = UUID()
        let dummyFolder = ConnectedFolder(id: testID, path: "/tmp/mock", name: "mock", fileCount: 2)
        mockFolderManager.folders = [dummyFolder]

        let webView = WKWebView()

        // Ejecutar addFolder
        bridge.handleSparkFolderAction(.addFolder, in: webView)
        XCTAssertTrue(mockFolderManager.addFolderPickerCalled)

        // Ejecutar removeFolder
        bridge.handleSparkFolderAction(.removeFolder(testID), in: webView)
        XCTAssertEqual(mockFolderManager.lastRemovedFolderID, testID)
    }
}

// MARK: - Mocks de Prueba

/// Mock en memoria para `PreferencesStoring`.
@MainActor
final class MockPreferences: PreferencesStoring {
    var panelWidth: Double = 500
    var panelHeight: Double = 200
    var panelX: Double? = nil
    var panelY: Double? = nil
    var panelPosition: PanelPosition = .bottomCenter
    var pageZoom: Double = 1.0
    var hideWindowAtLaunch: Bool = false
    var hideDockIcon: Bool = false
    var alwaysOnTop: Bool = false
    var appTheme: AppTheme = .system
    var userAgentOption: UserAgentOption = .safari
    var customUserAgent: String = ""
    var currentUserAgentString: String { userAgentOption.userAgentString(custom: customUserAgent) }
    var showInMenuBar: Bool = true
    var openAtLogin: Bool = false
    var sparkRemoteTasksEnabled: Bool = true
    var sparkKeepMacAwake: Bool = true
    var sparkBackupAlertEnabled: Bool = true
    var memoryEnabled: Bool = true
    var speakToWindowReasoning: Bool = true
    var voiceSelection: String = "Orbit"
    var appGoogleWorkspaceEnabled: Bool = true
    var appSearchServicesEnabled: Bool = true
    var appGooglePhotosEnabled: Bool = true
    var appYouTubeEnabled: Bool = true
    var debugTelemetryEnabled: Bool = true
    var connectedFolders: [ConnectedFolder] = []
}

/// Mock en memoria para `FolderManaging`.
@MainActor
final class MockFolderManager: FolderManaging {
    var folders: [ConnectedFolder] = []
    var selectedFolder: ConnectedFolder?

    var addFolderPickerCalled = false
    var lastRemovedFolderID: UUID?

    func addFolderFromPicker() {
        addFolderPickerCalled = true
    }

    func addFolder(url: URL) {
        folders.append(ConnectedFolder(path: url.path, name: url.lastPathComponent))
    }

    func removeFolder(id: UUID) {
        lastRemovedFolderID = id
        folders.removeAll { $0.id == id }
    }

    func removeFolder(at indexSet: IndexSet) {
        for index in indexSet.sorted(by: >) {
            folders.remove(at: index)
        }
    }

    func scanFiles(in folder: ConnectedFolder) -> [LocalFileInfo] {
        return []
    }

    func generateContextSummary(for folder: ConnectedFolder) -> String {
        return "Resumen Mock"
    }
}
