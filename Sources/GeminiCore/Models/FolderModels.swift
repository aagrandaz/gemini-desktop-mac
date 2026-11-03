//
//  FolderModels.swift
//  GeminiCore
//
//  Autor: aagrandaz@gmail.com
//

import Foundation

/// Representa la metadata resumida de un archivo o directorio local dentro de una carpeta conectada.
public struct LocalFileInfo: Identifiable, Hashable, Sendable {
    /// Identificador único del archivo basado en su ruta absoluta.
    public var id: String { path }
    /// Nombre visible del archivo o carpeta.
    public let name: String
    /// Ruta absoluta en el sistema de archivos de macOS.
    public let path: String
    /// Tamaño del archivo en bytes.
    public let fileSize: Int64
    /// Extensión del archivo en minúsculas (sin punto).
    public let fileExtension: String
    /// Fecha de última modificación registrada en el sistema de archivos.
    public let modificationDate: Date
    /// Indica si el elemento es un directorio en lugar de un archivo regular.
    public let isDirectory: Bool

    /// Inicializador completo de la estructura de archivo local.
    /// - Parameters:
    ///   - name: Nombre del archivo o directorio.
    ///   - path: Ruta absoluta del sistema de archivos.
    ///   - fileSize: Tamaño en bytes.
    ///   - fileExtension: Extensión del archivo (ej. "swift", "md").
    ///   - modificationDate: Fecha de modificación.
    ///   - isDirectory: Verdadero si se trata de un subdirectorio.
    public init(
        name: String,
        path: String,
        fileSize: Int64,
        fileExtension: String,
        modificationDate: Date,
        isDirectory: Bool
    ) {
        self.name = name
        self.path = path
        self.fileSize = fileSize
        self.fileExtension = fileExtension
        self.modificationDate = modificationDate
        self.isDirectory = isDirectory
    }

    /// Retorna una representación legible del tamaño del archivo (ej. "1.2 MB", "45 KB").
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

/// Modelo de datos persistente que representa una carpeta conectada de macOS sincronizada con Gemini Spark.
public struct ConnectedFolder: Identifiable, Codable, Equatable, Sendable {
    /// Identificador único de la carpeta conectada.
    public var id: UUID
    /// Ruta absoluta en el disco del usuario.
    public var path: String
    /// Nombre para mostrar de la carpeta (generalmente `lastPathComponent`).
    public var name: String
    /// Fecha en que se agregó la carpeta a la aplicación.
    public var dateAdded: Date
    /// Datos binarios del Security-Scoped Bookmark para conservar acceso a través del Sandbox de macOS.
    public var bookmarkData: Data?
    /// Cantidad aproximada de archivos contenidos en el directorio.
    public var fileCount: Int

    /// URL del sistema de archivos construida a partir de la ruta.
    public var url: URL {
        URL(fileURLWithPath: path)
    }

    /// Inicializador de una carpeta conectada.
    /// - Parameters:
    ///   - id: Identificador único opcional (por defecto genera un UUID nuevo).
    ///   - path: Ruta absoluta en el disco.
    ///   - name: Nombre de la carpeta.
    ///   - dateAdded: Fecha de conexión (por defecto es la fecha actual).
    ///   - bookmarkData: Bookmark con permisos de seguridad de AppKit/Sandbox.
    ///   - fileCount: Conteo de archivos no ocultos.
    public init(
        id: UUID = UUID(),
        path: String,
        name: String,
        dateAdded: Date = Date(),
        bookmarkData: Data? = nil,
        fileCount: Int = 0
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.dateAdded = dateAdded
        self.bookmarkData = bookmarkData
        self.fileCount = fileCount
    }
}
