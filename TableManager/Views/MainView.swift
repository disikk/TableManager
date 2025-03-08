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
    
    /// Whether settings sheet is presented
    @State private var showingSettings = false
    
    /// Whether new configuration sheet is presented
    @State private var showingNewConfigSheet = false
    
    /// Whether window picker is presented
    @State private var showingWindowPicker = false
    
    /// Name for new configuration
    @State private var newConfigName = ""
    
    /// Current view selection in sidebar
    @State private var selectedSidebarItem: MainView.SidebarItem = .configurations
    
    var body: some View {
        NavigationView {
            // Sidebar
            sidebar
            
            // Content
            ZStack {
                switch selectedSidebarItem {
                case .configurations:
                    if let configID = viewModel.activeConfigurationID,
                       let config = viewModel.configurations.first(where: { $0.id == configID }) {
                        ConfigurationView(configuration: config, viewModel: viewModel)
                    } else {
                        noConfigurationView
                    }
                case .windowTypes:
                    WindowTypesView(viewModel: viewModel)
                case .settings:
                    SettingsView()
                }
            }
        }
        .navigationTitle("Table Manager")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showingSettings.toggle()
                }) {
                    Image(systemName: "gear")
                }
            }
        }
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
            TextField("Configuration Name", text: $newConfigName)
            Button("Capture", action: {
                viewModel.captureCurrentLayout(name: newConfigName)
                newConfigName = ""
            })
            Button("Cancel", role: .cancel) {
                viewModel.cancelCaptureMode()
                newConfigName = ""
            }
        } message: {
            Text("Enter a name for the captured layout")
        }
    }
    
    /// Sidebar view
    private var sidebar: some View {
        List {
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
            
            Divider()
            
            Section("Tools") {
                NavigationLink(destination: WindowTypesView(viewModel: viewModel), 
                               tag: MainView.SidebarItem.windowTypes,
                               selection: $selectedSidebarItem) {
                    Label("Window Types", systemImage: "macwindow")
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
            
            Divider()
            
            NavigationLink(destination: SettingsView(), 
                           tag: MainView.SidebarItem.settings,
                           selection: $selectedSidebarItem) {
                Label("Settings", systemImage: "gear")
            }
            
            Spacer()
            
            // Status bar
            statusBar
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
    }
    
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
