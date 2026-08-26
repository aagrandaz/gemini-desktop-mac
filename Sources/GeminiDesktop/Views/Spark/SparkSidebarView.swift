//
//  SparkSidebarView.swift
//  GeminiDesktop
//
//  Created on 2026-08-25.
//

import SwiftUI
import AppKit

public enum SidebarMode: String, CaseIterable {
    case chat = "Chat"
    case spark = "Spark BETA"
}

public struct SparkSidebarView: View {
    @Binding var selectedMode: SidebarMode
    @ObservedObject var folderManager = LocalFolderManager.shared
    var onNewChat: () -> Void
    var onSelectChat: (String) -> Void
    var onOpenSettingsCategory: ((String) -> Void)?

    @State private var isPersonalizeExpanded: Bool = true
    @State private var isFoldersExpanded: Bool = true
    @State private var isNotebooksExpanded: Bool = true
    @State private var isChatsExpanded: Bool = true
    @State private var hoveredFolderId: UUID? = nil

    public init(
        selectedMode: Binding<SidebarMode>,
        onNewChat: @escaping () -> Void,
        onSelectChat: @escaping (String) -> Void,
        onOpenSettingsCategory: ((String) -> Void)? = nil
    ) {
        self._selectedMode = selectedMode
        self.onNewChat = onNewChat
        self.onSelectChat = onSelectChat
        self.onOpenSettingsCategory = onOpenSettingsCategory
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Mode Switcher (Segmented Control)
            HStack(spacing: 4) {
                ModeSwitchButton(
                    title: "Chat",
                    isSelected: selectedMode == .chat,
                    action: { selectedMode = .chat }
                )
                ModeSwitchButton(
                    title: "Spark",
                    badge: "BETA",
                    isSelected: selectedMode == .spark,
                    action: { selectedMode = .spark }
                )
            }
            .padding(4)
            .background(Color.white.opacity(0.06))
            .cornerRadius(18)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Content List depending on Mode
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if selectedMode == .spark {
                        sparkSidebarContent
                    } else {
                        chatSidebarContent
                    }
                }
                .padding(.horizontal, 12)
            }

            Spacer()

            // User Profile Pill at Bottom
            userProfileBar
        }
        .frame(width: 250)
        .background(Color(red: 0.09, green: 0.09, blue: 0.10))
    }

    // MARK: - Spark Mode Sidebar Content
    private var sparkSidebarContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Tareas
            SidebarRowButton(
                icon: "square.and.pencil",
                title: "Tareas",
                isSelected: true,
                action: {}
            )

            // Section: Personalizar
            VStack(alignment: .leading, spacing: 6) {
                Text("Personalizar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)

                SidebarRowButton(
                    icon: "clock",
                    title: "Actividades programadas",
                    action: { onOpenSettingsCategory?("Spark") }
                )

                SidebarRowButton(
                    icon: "sparkles",
                    title: "Habilidades",
                    action: { onOpenSettingsCategory?("Spark") }
                )

                SidebarRowButton(
                    icon: "square.stack.3d.up",
                    title: "Apps conectadas",
                    action: { onOpenSettingsCategory?("Apps") }
                )
            }

            // Section: Carpetas conectadas
            VStack(alignment: .leading, spacing: 8) {
                Text("Carpetas conectadas")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)

                // Button: + Agregar carpeta de Mac
                Button(action: {
                    folderManager.addFolderFromPicker()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Agregar carpeta de Mac")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // List of Connected Folders
                ForEach(folderManager.folders) { folder in
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(folder.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text("\(folder.fileCount) archivos")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        if hoveredFolderId == folder.id {
                            Button(action: {
                                folderManager.removeFolder(id: folder.id)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(folderManager.selectedFolder?.id == folder.id ? Color.white.opacity(0.08) : Color.clear)
                    .cornerRadius(6)
                    .onHover { isHovered in
                        hoveredFolderId = isHovered ? folder.id : nil
                    }
                    .onTapGesture {
                        folderManager.selectedFolder = folder
                    }
                }
            }
        }
    }

    // MARK: - Chat Mode Sidebar Content
    private var chatSidebarContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Search & New Chat
            SidebarRowButton(icon: "magnifyingglass", title: "Buscar", action: {})
            SidebarRowButton(icon: "plus.bubble", title: "Nuevo chat", isHighlighted: true, action: onNewChat)
            SidebarRowButton(icon: "square.grid.2x2", title: "Biblioteca", action: {})

            // Cuadernos
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Cuadernos")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                    Spacer()
                    Image(systemName: isNotebooksExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
                .onTapGesture { isNotebooksExpanded.toggle() }

                if isNotebooksExpanded {
                    SidebarRowButton(icon: "plus", title: "Nuevo cuaderno", action: {})
                    SidebarRowButton(icon: "flame.fill", title: "Guía de Profiling Continuo", action: { onSelectChat("Guía de Profiling Continuo") })
                    SidebarRowButton(icon: "doc.text", title: "RHEL - Certificación", action: { onSelectChat("RHEL - Certificación") })
                    SidebarRowButton(icon: "ellipsis", title: "Todos los cuadernos", action: {})
                }
            }

            // Chats
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Chats")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                    Spacer()
                    Image(systemName: isChatsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
                .onTapGesture { isChatsExpanded.toggle() }

                if isChatsExpanded {
                    SidebarRowButton(title: "Análisis Sartorial de Traje Gris", action: { onSelectChat("Análisis Sartorial de Traje Gris") })
                    SidebarRowButton(title: "Índice de Estándares y Guías", action: { onSelectChat("Índice de Estándares y Guías") })
                    SidebarRowButton(title: "Anteproyecto Titulación", action: { onSelectChat("Anteproyecto Titulación") })
                    SidebarRowButton(title: "Diseño de Mueble para TV", action: { onSelectChat("Diseño de Mueble para TV") })
                }
            }
        }
    }

    // MARK: - User Profile Bar
    private var userProfileBar: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                Text("AG")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Abel Granda")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text("Pro")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.blue)
            }

            Spacer()

            Button(action: {
                NotificationCenter.default.post(name: .init("OpenSettings"), object: nil)
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.04))
    }
}

// MARK: - Mode Switch Button
struct ModeSwitchButton: View {
    let title: String
    var badge: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .gray)

                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.18))
                        .cornerRadius(4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isSelected ? Color.white.opacity(0.14) : Color.clear)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sidebar Row Button
struct SidebarRowButton: View {
    var icon: String? = nil
    let title: String
    var isSelected: Bool = false
    var isHighlighted: Bool = false
    let action: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundColor(isHighlighted ? .white : (isSelected ? .blue : .gray))
                        .frame(width: 18)
                }

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isHighlighted ? .white : (isSelected ? .white : .white.opacity(0.85)))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isHighlighted ? Color.white.opacity(0.12) : (isSelected ? Color.white.opacity(0.08) : (isHovered ? Color.white.opacity(0.04) : Color.clear)))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
