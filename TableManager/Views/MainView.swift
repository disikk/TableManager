//
//  MainView.swift
//  TableManager
//
//  Created for TableManager macOS app
//

import SwiftUI

/// Main view for the application
struct MainView: View {
    /// View model
    @StateObject private var viewModel = MainViewModel()
    
    /// Selected view in sidebar
    @State private var selectedSidebarItem: MainView.SidebarItem? = .configurations
    
    /// Whether settings sheet is presented
    @State private var showingSettings = false
    
    /// Whether new configuration sheet is presented
    @State private var showingNewConfigSheet = false
    
    /// Whether window picker is presented
    @State private var showingWindowPicker = false
    
    /// Name for new configuration
    @State private var newConfigName = ""
    
    var body: some View {
        mainContent
            .sheet(isPresented: $showingNewConfigSheet) {
                newConfigurationSheet
            }
            .sheet(isPresented: $showingWindowPicker) {
                WindowPickerView(windowManager: viewModel.windowManager,
                                 onWindowSelected: { windowType in
                    viewModel.addWindowType(windowType)
                })
            }
            .alert("Capture Layout", isPresented: $viewModel.isCaptureModeActive) {
                captureLayoutAlertContent
            } message: {
                Text("Enter a name for the captured layout")
            }
    }
    
    // MARK: - Main Content Components
    
    /// Main container for the app UI
    private var mainContent: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebarContent
            
            // Content area
            contentArea
        }
        .overlay(
            Group {
                if let notification = NotificationManager.shared.currentNotification {
                    NotificationView(data: notification)
                        .transition(.move(edge: .top))
                        .animation(.easeInOut, value: notification.id)
                }
            }
        )
    }
    
    /// Left sidebar content
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Header
            sidebarHeader
            
            // List content
            sidebarList
        }
        .frame(minWidth: 200)
    }
    
    /// Sidebar header
    private var sidebarHeader: some View {
        HStack {
            Text("Table Manager")
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    /// Sidebar list with sections
    private var sidebarList: some View {
        List {
            configurationSection
            
            Divider()
            
            toolsSection
            
            Divider()
            
            settingsButton
            
            Spacer()
            
            // Status bar
            statusBar
        }
        .listStyle(SidebarListStyle())
    }
    
    /// Configurations section in sidebar
    private var configurationSection: some View {
        Section("Configurations") {
            ForEach(viewModel.configurations) { config in
                ConfigurationRow(config: config, isActive: viewModel.activeConfigurationID == config.id)
                    .onTapGesture {
                        viewModel.activateConfiguration(config.id)
                        selectedSidebarItem = .configurations
                    }
            }
            
            Button(action: {
                newConfigName = "New Configuration"
                showingNewConfigSheet = true
            }) {
                Label("Add Configuration", systemImage: "plus")
            }
        }
    }
    
    /// Tools section in sidebar
    private var toolsSection: some View {
        Section("Tools") {
            Button(action: {
                selectedSidebarItem = .windowTypes
            }) {
                Label("Window Types", systemImage: "macwindow")
                    .foregroundColor(selectedSidebarItem == .windowTypes ? .accentColor : .primary)
            }
            
            Button(action: {
                showingWindowPicker = true
            }) {
                Label("Select Window", systemImage: "eye.circle")
            }
            
            Button(action: {
                newConfigName = "Captured Layout"
                viewModel.startCaptureMode()
            }) {
                Label("Capture Layout", systemImage: "camera")
            }
        }
    }
    
    /// Settings button in sidebar
    private var settingsButton: some View {
        Button(action: {
            selectedSidebarItem = .settings
        }) {
            Label("Settings", systemImage: "gear")
                .foregroundColor(selectedSidebarItem == .settings ? .accentColor : .primary)
        }
    }
    
    /// Main content area
    private var contentArea: some View {
        ZStack {
            // Main content based on selection
            contentForSelectedItem
            
            // Settings button overlay
            settingsButtonOverlay
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Content based on sidebar selection
    private var contentForSelectedItem: some View {
        Group {
            switch selectedSidebarItem {
            case .configurations:
                configurationContent
            case .windowTypes:
                WindowTypesView(viewModel: viewModel)
            case .settings:
                SettingsView()
            case .none:
                noConfigurationView
            }
        }
    }
    
    /// Content for configuration tab
    private var configurationContent: some View {
        Group {
            if let configID = viewModel.activeConfigurationID,
               let config = viewModel.configurations.first(where: { $0.id == configID }) {
                ConfigurationView(configuration: config, viewModel: viewModel)
            } else {
                noConfigurationView
            }
        }
    }
    
    /// Settings button overlay
    private var settingsButtonOverlay: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    showingSettings.toggle()
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 18))
                        .padding(10)
                        .background(Circle().fill(Color(.controlBackgroundColor)))
                }
                .padding()
            }
            Spacer()
        }
    }
    
    // MARK: - Alert and Sheet Components
    
    /// Alert content for layout capture
    private var captureLayoutAlertContent: some View {
        Group {
            TextField("Configuration Name", text: $newConfigName)
            Button("Capture", action: {
                viewModel.captureCurrentLayout(name: newConfigName)
                newConfigName = ""
            })
            Button("Cancel", role: .cancel) {
                viewModel.cancelCaptureMode()
                newConfigName = ""
            }
        }
    }
    
    /// Sheet for creating a new configuration
    private var newConfigurationSheet: some View {
        VStack(spacing: 20) {
            Text("Create New Configuration")
                .font(.headline)
            
            TextField("Configuration Name", text: $newConfigName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300)
            
            HStack {
                Button("Cancel") {
                    showingNewConfigSheet = false
                }
                
                Button("Create") {
                    viewModel.createConfiguration(name: newConfigName)
                    showingNewConfigSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .padding()
        .frame(width: 400, height: 200)
    }
    
    // MARK: - Helper Views
    
    /// View shown when no configuration is selected
    private var noConfigurationView: some View {
        VStack(spacing: 20) {
            Image(systemName: "macwindow")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Configuration Selected")
                .font(.title)
            
            Text("Select a configuration from the sidebar or create a new one")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Create New Configuration") {
                newConfigName = "New Configuration"
                showingNewConfigSheet = true
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
    
    /// Status bar at the bottom of the sidebar
    private var statusBar: some View {
        VStack(alignment: .leading) {
            Divider()
            
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.vertical, 5)
        }
    }
    
    /// Color for the status indicator
    private var statusColor: Color {
        switch viewModel.appState {
        case .idle:
            return .gray
        case .detecting, .capturing:
            return .orange
        case .monitoring:
            return .green
        case .arranging:
            return .blue
        case .error:
            return .red
        }
    }
    
    // MARK: - Supporting Types
    
    /// Items that can be selected in the sidebar
    enum SidebarItem {
        case configurations
        case windowTypes
        case settings
    }
}

/// Row view for a configuration in the sidebar
struct ConfigurationRow: View {
    let config: Configuration
    let isActive: Bool
    
    var body: some View {
        HStack {
            Label(config.name, systemImage: "square.grid.2x2")
                .foregroundColor(isActive ? .accentColor : .primary)
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}

/// View for displaying notifications
struct NotificationView: View {
    let data: NotificationData
    
    var body: some View {
        VStack {
            HStack(spacing: 15) {
                Image(systemName: data.type.icon)
                    .foregroundColor(data.type.color)
                    .font(.system(size: 20))
                
                Text(data.message)
                    .font(.body)
                
                Spacer()
                
                Button(action: {
                    NotificationManager.shared.hide()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.controlBackgroundColor))
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .padding()
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
