//
//  LocalFolderManager.swift
//  GeminiCore
//
//  Autor: aagrandaz@gmail.com
//

import Foundation
import AppKit
import Observation

/// Gestor de carpetas locales conectadas que implementa `FolderManaging`.
/// Utiliza inyección de dependencias por constructor y el framework de reactividad `Observation`.
@Observable
@MainActor
public final class LocalFolderManager: FolderManaging {
    /// Colección reactiva de carpetas locales conectadas.
    public private(set) var folders: [ConnectedFolder] = []
    /// Carpeta actualmente activa o seleccionada por el usuario.
    public var selectedFolder: ConnectedFolder?

    /// Referencia al almacén de preferencias para persistir los cambios.
    private let preferences: PreferencesStoring

    /// Inicializador con inyección de dependencias.
    /// - Parameter preferences: Instancia conformante a `PreferencesStoring`.
    public init(preferences: PreferencesStoring) {
        self.preferences = preferences
        self.folders = preferences.connectedFolders
        self.selectedFolder = preferences.connectedFolders.first
    }

    /// Despliega el diálogo modal de selección de archivos del sistema (`NSOpenPanel`) para agregar directorios locales.
    public func addFolderFromPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = true
        panel.prompt = "Conectar carpeta"
        panel.message = "Selecciona una carpeta local de tu Mac para conectar con Gemini Spark"

        let response = panel.runModal()
        guard response == .OK else { return }

        for url in panel.urls {
            addFolder(url: url)
        }
    }

    /// Conecta una nueva carpeta a partir de su URL, resolviendo permisos y guardándola en preferencias.
    /// - Parameter url: URL local del directorio.
    public func addFolder(url: URL) {
        guard !folders.contains(where: { $0.path == url.path }) else { return }

        var bookmark: Data? = nil
        do {
            bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            print("[LocalFolderManager] Failed to create security bookmark for \(url.path): \(error)")
        }

        let fileCount = countFilesInDirectory(url: url)
        let folder = ConnectedFolder(
            path: url.path,
            name: url.lastPathComponent,
            bookmarkData: bookmark,
            fileCount: fileCount
        )

        folders.append(folder)
        if selectedFolder == nil {
            selectedFolder = folder
        }
        saveFolders()
    }

    /// Elimina una carpeta conectada dado su identificador único.
    /// - Parameter id: `UUID` de la carpeta a remover.
    public func removeFolder(id: UUID) {
        folders.removeAll(where: { $0.id == id })
        if selectedFolder?.id == id {
            selectedFolder = folders.first
        }
        saveFolders()
    }

    /// Elimina un conjunto de carpetas a partir de sus índices en la lista.
    /// - Parameter indexSet: Índices a eliminar.
    public func removeFolder(at indexSet: IndexSet) {
        for index in indexSet.sorted(by: >) where folders.indices.contains(index) {
            folders.remove(at: index)
        }
        if let selected = selectedFolder, !folders.contains(where: { $0.id == selected.id }) {
            selectedFolder = folders.first
        }
        saveFolders()
    }

    /// Escanea exhaustivamente y de forma no recursiva en paquetes los archivos de una carpeta conectada.
    /// - Parameter folder: Carpeta conectada a inspeccionar.
    /// - Returns: Lista de metadatos `LocalFileInfo`.
    public func scanFiles(in folder: ConnectedFolder) -> [LocalFileInfo] {
        let fileManager = FileManager.default
        let url = folder.url

        var isStale = false
        if let bookmark = folder.bookmarkData {
            if let resolvedURL = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                _ = resolvedURL.startAccessingSecurityScopedResource()
            }
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.nameKey, .fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var results: [LocalFileInfo] = []

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.nameKey, .fileSizeKey, .contentModificationDateKey, .isDirectoryKey]) else {
                continue
            }

            let isDir = resourceValues.isDirectory ?? false
            let name = resourceValues.name ?? fileURL.lastPathComponent
            let size = Int64(resourceValues.fileSize ?? 0)
            let modDate = resourceValues.contentModificationDate ?? Date()

            results.append(LocalFileInfo(
                name: name,
                path: fileURL.path,
                fileSize: size,
                fileExtension: fileURL.pathExtension.lowercased(),
                modificationDate: modDate,
                isDirectory: isDir
            ))
        }

        return results
    }

    /// Genera un resumen contextual comprensible del contenido de la carpeta para adjuntar al prompt de Gemini.
    /// - Parameter folder: Carpeta a resumir.
    /// - Returns: Texto con estadísticas y lista de los primeros 30 archivos.
    public func generateContextSummary(for folder: ConnectedFolder) -> String {
        let files = scanFiles(in: folder)
        let totalFiles = files.filter { !$0.isDirectory }.count
        let fileTypes = Set(files.map { $0.fileExtension.isEmpty ? "sin extensión" : $0.fileExtension }).sorted()

        var summary = "Carpeta Local Conectada: '\(folder.name)' (\(folder.path))\n"
        summary += "Total de archivos: \(totalFiles)\n"
        summary += "Formatos detectados: \(fileTypes.joined(separator: ", "))\n"
        summary += "Estructura principal:\n"

        let topFiles = files.prefix(30)
        for file in topFiles {
            let typeIndicator = file.isDirectory ? "📁" : "📄"
            summary += "- \(typeIndicator) \(file.name) (\(file.formattedSize))\n"
        }

        if files.count > 30 {
            summary += "... y \(files.count - 30) elementos adicionales.\n"
        }

        return summary
    }

    /// Cuenta el número de elementos visibles en un directorio.
    /// - Parameter url: URL del directorio.
    /// - Returns: Cantidad de archivos.
    private func countFilesInDirectory(url: URL) -> Int {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: url.path) else { return 0 }
        return files.filter { !$0.hasPrefix(".") }.count
    }

    /// Persiste la lista de carpetas en el repositorio de preferencias.
    private func saveFolders() {
        preferences.connectedFolders = folders
    }
}
