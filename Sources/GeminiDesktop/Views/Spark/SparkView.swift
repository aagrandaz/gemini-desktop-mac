//
//  SparkView.swift
//  GeminiDesktop
//
//  Created on 2026-08-25.
//

import SwiftUI
import AppKit

public struct SparkView: View {
    @ObservedObject var folderManager = LocalFolderManager.shared
    @State private var taskPrompt: String = ""
    @State private var attachedFolder: ConnectedFolder?
    @State private var isExecutingTask: Bool = false
    @State private var executionResult: String? = nil
    var onSendToChat: ((String) -> Void)?

    public init(onSendToChat: ((String) -> Void)? = nil) {
        self.onSendToChat = onSendToChat
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Spacer().frame(height: 20)
                heroSection
                taskInputBox
                feedbackSection
                recientesSection
                tendenciasSection
                Spacer().frame(height: 40)
            }
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
    }

    // MARK: - Subviews

    @ViewBuilder
    private var heroSection: some View {
        VStack(alignment: .center, spacing: 8) {
            HStack {
                Spacer()
                Text("Haz que Gemini Spark trabaje por ti")
                    .font(.system(size: 28, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
        }
        .padding(.top, 40)
    }

    @ViewBuilder
    private var taskInputBox: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                attachFolderMenu

                if let folder = attachedFolder {
                    attachedFolderChip(folder: folder)
                }

                TextField("Describe tu tarea", text: $taskPrompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .onSubmit { executeTask() }

                Button(action: {}) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                if !taskPrompt.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button(action: { executeTask() }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.85))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
        }
        .padding(.horizontal, 60)
    }

    @ViewBuilder
    private var attachFolderMenu: some View {
        Menu {
            Button(action: {
                folderManager.addFolderFromPicker()
            }) {
                Label("Conectar nueva carpeta de Mac...", systemImage: "folder.badge.plus")
            }

            if !folderManager.folders.isEmpty {
                Divider()
                Text("Carpetas conectadas:")
                ForEach(folderManager.folders) { folder in
                    Button(action: {
                        attachedFolder = folder
                    }) {
                        Label(folder.name, systemImage: "folder.fill")
                    }
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func attachedFolderChip(folder: ConnectedFolder) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: 11))
                .foregroundColor(.blue)
            Text(folder.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
            Button(action: { attachedFolder = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.blue.opacity(0.18))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.blue.opacity(0.4), lineWidth: 1)
        )
        .cornerRadius(14)
    }

    @ViewBuilder
    private var feedbackSection: some View {
        if let result = executionResult {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                    Text("Resultado de Gemini Spark:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Cerrar") { executionResult = nil }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                Text(result)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
                    .textSelection(.enabled)
            }
            .padding(16)
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            .padding(.horizontal, 60)
        }
    }

    @ViewBuilder
    private var recientesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recientes")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))

            VStack(spacing: 12) {
                RecentTaskRow(
                    title: "Desarrollo de Anteproyecto Académico",
                    subtitle: "Redactó guion técnico conciso para el anteproyecto.",
                    action: {
                        onSendToChat?("Desarrollo de Anteproyecto Académico")
                    }
                )

                RecentTaskRow(
                    title: "Diseño de Mueble para Televisión",
                    subtitle: "Adapté el diseño del mueble a las dimensiones exactas.",
                    action: {
                        onSendToChat?("Diseño de Mueble para Televisión")
                    }
                )
            }

            Button(action: {}) {
                HStack(spacing: 4) {
                    Text("Todas las tareas")
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.horizontal, 60)
    }

    @ViewBuilder
    private var tendenciasSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tendencias")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))

            VStack(spacing: 12) {
                TrendCard(
                    title: "Organiza mis carpetas conectadas",
                    description: "Encuentra archivos desorganizados en mis carpetas conectadas, agrúpalos por tipo o contexto, y archiva el desorden.",
                    action: {
                        runTrendTask("Por favor analiza y organiza los archivos de mis carpetas conectadas.")
                    }
                )

                TrendCard(
                    title: "Dar un cierre a mi última reunión",
                    description: "Obtén la transcripción o el documento más reciente de Meet, y redacta un correo electrónico de seguimiento.",
                    action: {
                        runTrendTask("Redacta un correo de seguimiento y cierre para mi última reunión.")
                    }
                )

                TrendCard(
                    title: "Convertir mis archivos en hojas de cálculo",
                    description: "Analiza los elementos de mi carpeta conectada (como facturas o informes), extráelos y estructúralos en una tabla CSV/Excel.",
                    action: {
                        runTrendTask("Analiza los documentos de mi carpeta conectada y extrae los datos clave estructurados en una tabla.")
                    }
                )
            }
        }
        .padding(.horizontal, 60)
    }

    private func executeTask() {
        let trimmed = taskPrompt.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        var finalPrompt = trimmed
        if let folder = attachedFolder {
            let summary = folderManager.generateContextSummary(for: folder)
            finalPrompt = "Contexto Local:\n\(summary)\n\nTarea a realizar:\n\(trimmed)"
        }

        if let send = onSendToChat {
            send(finalPrompt)
            taskPrompt = ""
            attachedFolder = nil
        } else {
            executionResult = "Tarea enviada a Gemini Spark con \(attachedFolder?.name ?? "contexto general")."
        }
    }

    private func runTrendTask(_ prompt: String) {
        taskPrompt = prompt
        if let firstFolder = folderManager.folders.first {
            attachedFolder = firstFolder
        }
        executeTask()
    }
}

struct RecentTaskRow: View {
    let title: String
    let subtitle: String
    var action: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isHovered ? Color.white.opacity(0.06) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct TrendCard: View {
    let title: String
    let description: String
    var action: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 3)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isHovered ? Color.white.opacity(0.06) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
