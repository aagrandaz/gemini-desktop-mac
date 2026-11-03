//
//  AppEventBus.swift
//  GeminiCore
//
//  Autor: aagrandaz@gmail.com
//

import Foundation

/// Tipos de eventos fuertemente tipados que reemplazan las notificaciones basadas en cadenas de NotificationCenter.
/// Representa acciones globales de navegación e interacción entre vistas desacopladas.
public enum AppEvent: Sendable, Equatable {
    /// Solicita abrir o traer al frente la ventana principal de la aplicación.
    case openMainWindow
    /// Solicita abrir la ventana de ajustes/preferencias de la aplicación.
    case openSettings
    /// Alterna la visibilidad de la barra lateral en la interfaz web de Gemini.
    case toggleSidebar
}

/// Contrato para publicar y suscribirse a flujos reactivos de eventos mediante Swift Concurrency.
@MainActor
public protocol AppEventStreaming: AnyObject {
    /// Emite un evento a todos los consumidores suscritos al bus.
    /// - Parameter event: Instancia de `AppEvent` a despachar.
    func send(_ event: AppEvent)

    /// Produce un flujo asíncrono desacoplado para escuchar eventos emitidos por el bus.
    /// - Returns: Una instancia de `AsyncStream<AppEvent>`.
    func stream() -> AsyncStream<AppEvent>
}

/// Implementación moderna y ligera de un bus de eventos reactivo basado en `AsyncStream`.
/// Garantiza aislamiento en `@MainActor` y gestión automática del ciclo de vida de continuaciones.
@MainActor
public final class AppEventBus: AppEventStreaming, @unchecked Sendable {
    /// Registro de continuaciones activas identificadas por UUID único.
    private var continuations: [UUID: AsyncStream<AppEvent>.Continuation] = [:]

    /// Inicializador predeterminado del bus de eventos.
    public init() {}

    /// Despacha un evento a todas las continuaciones activas registradas.
    /// - Parameter event: Evento a emitir.
    public func send(_ event: AppEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    /// Crea y registra un nuevo flujo `AsyncStream` con limpieza automática al finalizar la tarea.
    /// - Returns: `AsyncStream<AppEvent>` listo para iterar con `for await`.
    public func stream() -> AsyncStream<AppEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: AppEvent.self)
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.removeContinuation(for: id)
            }
        }
        return stream
    }

    /// Elimina una continuación finalizada del diccionario interno.
    /// - Parameter id: Identificador único de la continuación.
    private func removeContinuation(for id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
