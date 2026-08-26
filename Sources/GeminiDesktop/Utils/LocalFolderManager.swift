//
//  LocalFolderManager.swift
//  GeminiDesktop
//
//  Created on 2026-08-25.
//

import Foundation
import AppKit

public struct LocalFileInfo: Identifiable, Hashable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let fileSize: Int64
    public let fileExtension: String
    public let modificationDate: Date
    public let isDirectory: Bool

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

public struct ConnectedFolder: Identifiable, Codable, Equatable {
    public var id: UUID
    public var path: String
    public var name: String
    public var dateAdded: Date
    public var bookmarkData: Data?
    public var fileCount: Int

    public var url: URL {
        URL(fileURLWithPath: path)
    }

    public init(id: UUID = UUID(), path: String, name: String, dateAdded: Date = Date(), bookmarkData: Data? = nil, fileCount: Int = 0) {
        self.id = id
        self.path = path
        self.name = name
        self.dateAdded = dateAdded
        self.bookmarkData = bookmarkData
        self.fileCount = fileCount
    }
}

@MainActor
public class LocalFolderManager: ObservableObject {
    public static let shared = LocalFolderManager()

    @Published public var folders: [ConnectedFolder] = []
    @Published public var selectedFolder: ConnectedFolder?

    private let storageKey = UserDefaultsKeys.connectedFoldersData.rawValue

    public init() {
        loadFolders()
    }

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
            // Avoid duplicate paths
            if folders.contains(where: { $0.path == url.path }) {
                continue
            }

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
        }

        saveFolders()
    }

    public func removeFolder(id: UUID) {
        folders.removeAll(where: { $0.id == id })
        if selectedFolder?.id == id {
            selectedFolder = folders.first
        }
        saveFolders()
    }

    public func removeFolder(at indexSet: IndexSet) {
        folders.remove(atOffsets: indexSet)
        if let selected = selectedFolder, !folders.contains(where: { $0.id == selected.id }) {
            selectedFolder = folders.first
        }
        saveFolders()
    }

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

    public func generateContextSummary(for folder: ConnectedFolder) -> String {
        let files = scanFiles(in: folder)
        let totalFiles = files.filter { !$0.isDirectory }.count
        let fileTypes = Set(files.map { $0.fileExtension.isEmpty ? "sin extensión" : $0.fileExtension })

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

    private func countFilesInDirectory(url: URL) -> Int {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: url.path) else { return 0 }
        return files.filter { !$0.hasPrefix(".") }.count
    }

    private func saveFolders() {
        if let encoded = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func loadFolders() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ConnectedFolder].self, from: data) else {
            return
        }
        self.folders = decoded
        self.selectedFolder = decoded.first
    }
}
