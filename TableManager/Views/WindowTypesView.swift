//
//  WindowTypesView.swift
//  TableManager
//
//  Created for TableManager macOS app
//

import SwiftUI

/// View for managing window types
struct WindowTypesView: View {
    /// Main view model
    var viewModel: MainViewModel
    
    /// Array of window types from the configuration manager
    @State private var windowTypes: [WindowType] = []
    
    /// Currently selected window type
    @State private var selectedType: WindowType?
    
    /// Whether to show the window picker
    @State private var showingWindowPicker = false
    
    /// Whether to show the add/edit sheet
    @State private var showingEditSheet = false
    
    /// Window type being edited
    @State private var editingType: WindowType?
    
    /// Whether to show delete confirmation
    @State private var showingDeleteConfirmation = false
    
    /// Whether to show success toast
    @State private var showToast = false
    
    /// Toast message
    @State private var toastMessage = ""
    
    /// Filter text for searching window types
    @State private var filterText = ""
    
    /// Whether to show only enabled types
    @State private var showEnabledOnly = false
    
    /// Window selector view model for window selection
    @StateObject private var windowSelectorViewModel: WindowSelectorViewModel
    
    init(viewModel: MainViewModel) {
        self.viewModel = viewModel
        self._windowSelectorViewModel = StateObject(wrappedValue: WindowSelectorViewModel(windowManager: viewModel.windowManager))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Window Types")
                    .font(.headline)
                    .padding(.leading)
                
                Spacer()
                
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search", text: $filterText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)
                        .disableAutocorrection(true)
                    
                    if !filterText.isEmpty {
                        Button(action: {
                            filterText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Toggle("Enabled Only", isOn: $showEnabledOnly)
                    .toggleStyle(.switch)
                    .padding(.horizontal)
                
                Button(action: {
                    editingType = WindowType(
                        id: UUID().uuidString,
                        name: "New Window Type",
                        titlePattern: "*",
                        classPattern: "*",
                        enabled: true
                    )
                    showingEditSheet = true
                }) {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    showingWindowPicker = true
                }) {
                    Label("Select Window", systemImage: "eye")
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                    .frame(width: 10)
            }
            .padding(.vertical, 10)
            .background(Color(.controlBackgroundColor))
            
            // Content
            HSplitView {
                // List of window types
                VStack {
                    List(filteredWindowTypes, selection: $selectedType) { windowType in
                        windowTypeRow(windowType)
                            .contentShape(Rectangle()) // Make the entire row clickable
                            .tag(windowType)
                    }
                    .listStyle(SidebarListStyle())
                }
                .frame(minWidth: 250)
                
                // Details of selected window type
                VStack {
                    if let selectedType = selectedType {
                        windowTypeDetails(selectedType)
                    } else {
                        noSelectionView
                    }
                }
                .frame(minWidth: 400)
            }
        }
        .onAppear {
            // Load window types from view model
            loadWindowTypes()
        }
        .onChange(of: viewModel.configManager.windowTypes) { _ in
            // Reload when window types change
            loadWindowTypes()
        }
        .sheet(isPresented: $showingWindowPicker) {
            WindowPickerView(
                windowSelectorViewModel: windowSelectorViewModel,
                onFinish: { selectedType in
                    if let type = selectedType {
                        viewModel.addWindowType(type)
                        self.selectedType = type
                        
                        showToast = true
                        toastMessage = "Window type '\(type.name)' added successfully"
                    }
                    loadWindowTypes()
                }
            )
        }
        .sheet(isPresented: $showingEditSheet) {
            if let editingType = editingType {
                WindowTypeEditView(
                    windowType: editingType,
                    onSave: saveWindowType,
                    onCancel: {
                        self.editingType = nil
                        showingEditSheet = false
                    }
                )
            }
        }
        .alert("Delete Window Type", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let selectedType = selectedType {
                    viewModel.configManager.removeWindowType(id: selectedType.id)
                    self.selectedType = nil
                    loadWindowTypes()
                    
                    showToast = true
                    toastMessage = "Window type deleted successfully"
                }
            }
        } message: {
            if let selectedType = selectedType {
                Text("Are you sure you want to delete '\(selectedType.name)'? This cannot be undone.")
            } else {
                Text("Are you sure you want to delete this window type? This cannot be undone.")
            }
        }
        .overlay(
            Group {
                if showToast {
                    VStack {
                        Spacer()
                        
                        Text(toastMessage)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.controlBackgroundColor)))
                            .shadow(radius: 2)
                            .padding(.bottom, 20)
                            .transition(.move(edge: .bottom))
                            .onAppear {
                                // Auto-hide after 2 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        showToast = false
                                    }
                                }
                            }
                    }
                }
            }
        )
    }
    
    /// Filtered list of window types based on search and filter settings
    private var filteredWindowTypes: [WindowType] {
        var result = windowTypes
        
        // Apply text filter if any
        if !filterText.isEmpty {
            result = result.filter { windowType in
                windowType.name.lowercased().contains(filterText.lowercased()) ||
                windowType.titlePattern.lowercased().contains(filterText.lowercased()) ||
                windowType.classPattern.lowercased().contains(filterText.lowercased())
            }
        }
        
        // Apply enabled-only filter if selected
        if showEnabledOnly {
            result = result.filter { $0.enabled }
        }
        
        return result
    }
    
    /// View for when no window type is selected
    private var noSelectionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "macwindow")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Window Type Selected")
                .font(.title)
            
            Text("Select a window type from the list or create a new one")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                Button(action: {
                    editingType = WindowType(
                        id: UUID().uuidString,
                        name: "New Window Type",
                        titlePattern: "*",
                        classPattern: "*",
                        enabled: true
                    )
                    showingEditSheet = true
                }) {
                    Label("Add New", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    showingWindowPicker = true
                }) {
                    Label("Select Window", systemImage: "eye")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
    
    /// Row view for a window type in the list
    private func windowTypeRow(_ windowType: WindowType) -> some View {
        HStack {
            Image(systemName: windowType.enabled ? "macwindow" : "macwindow.badge.minus")
                .foregroundColor(windowType.enabled ? .accentColor : .secondary)
            
            VStack(alignment: .leading) {
                Text(windowType.name)
                    .foregroundColor(windowType.enabled ? .primary : .secondary)
                
                Text(windowType.titlePattern)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !windowType.enabled {
                Text("Disabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.2)))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            // Add context menu actions
            Button(action: {
                editingType = windowType
                showingEditSheet = true
            }) {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(action: {
                toggleWindowTypeEnabled(windowType)
            }) {
                Label(windowType.enabled ? "Disable" : "Enable", 
                      systemImage: windowType.enabled ? "slash.circle" : "checkmark.circle")
            }
            
            Button(action: {
                // Create a copy
                let copy = windowType.copy()
                viewModel.configManager.addWindowType(copy)
                loadWindowTypes()
                selectedType = copy
                
                showToast = true
                toastMessage = "Created copy of '\(windowType.name)'"
            }) {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                selectedType = windowType
                showingDeleteConfirmation = true
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    /// Details view for a selected window type
    private func windowTypeDetails(_ windowType: WindowType) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(windowType.name)
                .font(.title)
                .fontWeight(.semibold)
            
            Divider()
            
            // Details grid
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 15) {
                GridRow {
                    Text("Name:")
                        .foregroundColor(.secondary)
                    Text(windowType.name)
                        .fontWeight(.medium)
                }
                
                GridRow {
                    Text("Title Pattern:")
                        .foregroundColor(.secondary)
                    Text(windowType.titlePattern)
                }
                
                GridRow {
                    Text("Class Pattern:")
                        .foregroundColor(.secondary)
                    Text(windowType.classPattern)
                }
                
                GridRow {
                    Text("Status:")
                        .foregroundColor(.secondary)
                    HStack {
                        Circle()
                            .fill(windowType.enabled ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        Text(windowType.enabled ? "Enabled" : "Disabled")
                    }
                }
            }
            
            Divider()
            
            // Pattern explanation section
            patternExplanationView(windowType)
            
            Spacer()
            
            // Action buttons
            HStack {
                Button(action: {
                    toggleWindowTypeEnabled(windowType)
                }) {
                    Label(windowType.enabled ? "Disable" : "Enable", 
                          systemImage: windowType.enabled ? "slash.circle" : "checkmark.circle")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: {
                    editingType = windowType
                    showingEditSheet = true
                }) {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    // Create a copy
                    let copy = windowType.copy()
                    viewModel.configManager.addWindowType(copy)
                    loadWindowTypes()
                    selectedType = copy
                    
                    showToast = true
                    toastMessage = "Created copy of '\(windowType.name)'"
                }) {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }
    
    /// Pattern explanation view
    private func patternExplanationView(_ windowType: WindowType) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pattern Explanation")
                .font(.headline)
            
            Text("Title Pattern: \(windowType.titlePattern)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("This pattern will match windows with titles like:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView {
                Text(generateExampleMatches(pattern: windowType.titlePattern))
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(.textBackgroundColor)))
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 100)
            
            Divider()
            
            Text("Class Pattern: \(windowType.classPattern)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("This pattern will match applications with identifiers like:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView {
                Text(generateExampleClassMatches(pattern: windowType.classPattern))
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(.textBackgroundColor)))
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 80)
        }
    }
    
    /// Toggles the enabled state of a window type
    private func toggleWindowTypeEnabled(_ windowType: WindowType) {
        var updatedType = windowType
        updatedType.enabled.toggle()
        viewModel.configManager.updateWindowType(updatedType)
        loadWindowTypes()
        
        // If we're toggling the currently selected type, update the selection
        if selectedType?.id == windowType.id {
            selectedType = updatedType
        }
        
        showToast = true
        toastMessage = "\(updatedType.name) \(updatedType.enabled ? "enabled" : "disabled")"
    }
    
    /// Loads window types from the configuration manager
    private func loadWindowTypes() {
        windowTypes = viewModel.configManager.windowTypes
    }
    
    /// Generates example matches for a pattern
    private func generateExampleMatches(pattern: String) -> String {
        // Handle special cases for common patterns
        if pattern == "*" {
            return "- Any window title"
        }
        
        var examples = ""
        
        let patternWithoutWildcards = pattern.replacingOccurrences(of: "*", with: "")
        
        if pattern.hasPrefix("*") && pattern.hasSuffix("*") {
            examples += "- Window with '\(patternWithoutWildcards)' anywhere in the title\n"
            examples += "- Example: 'My \(patternWithoutWildcards) Window'\n"
            examples += "- Example: 'About \(patternWithoutWildcards)'"
        } else if pattern.hasPrefix("*") {
            examples += "- Window title ending with '\(patternWithoutWildcards)'\n"
            examples += "- Example: 'My \(patternWithoutWildcards)'\n"
            examples += "- Example: 'About \(patternWithoutWildcards)'"
        } else if pattern.hasSuffix("*") {
            examples += "- Window title starting with '\(patternWithoutWildcards)'\n"
            examples += "- Example: '\(patternWithoutWildcards) Window'\n"
            examples += "- Example: '\(patternWithoutWildcards) App'"
        } else {
            examples += "- Exact match: '\(patternWithoutWildcards)'"
        }
        
        // Special handling for poker-related patterns
        if pattern.contains("Hold'em") || pattern.contains("hold'em") {
            examples += "\n\n- Specifically targets poker windows with Hold'em games\n"
            examples += "- Example: 'Texas Hold'em - Table 12345'\n"
            examples += "- Example: 'No Limit Hold'em Tournament'"
        } else if pattern.contains("Table") || pattern.contains("table") {
            examples += "\n\n- Specifically targets windows with table references\n"
            examples += "- Example: 'Table 12345'\n"
            examples += "- Example: 'Poker Table - Tournament'"
        }
        
        return examples
    }
    
    /// Generates example matches for a class pattern
    private func generateExampleClassMatches(pattern: String) -> String {
        if pattern == "*" {
            return "- Any application"
        }
        
        var examples = ""
        
        // Handle bundle ID patterns
        if pattern.contains(".") {
            if pattern.hasSuffix("*") {
                // Prefix match
                let prefix = pattern.replacingOccurrences(of: "*", with: "")
                examples += "- Applications with bundle IDs starting with '\(prefix)'\n"
                
                // Add specific examples for known poker clients
                if prefix.contains("pokerstars") || prefix.contains("PokerStars") {
                    examples += "- Example: 'com.pokerstars.client'\n"
                    examples += "- Example: 'com.pokerstars.tournament'"
                } else if prefix.contains("partypoker") || prefix.contains("PartyPoker") {
                    examples += "- Example: 'com.partypoker.client'\n"
                    examples += "- Example: 'com.partypoker.app'"
                } else {
                    examples += "- Example: '\(prefix)client'\n"
                    examples += "- Example: '\(prefix)app'"
                }
            } else {
                // Exact match
                examples += "- Exact bundle ID: '\(pattern)'"
            }
        } else {
            // General pattern
            let patternWithoutWildcards = pattern.replacingOccurrences(of: "*", with: "")
            
            if pattern.hasPrefix("*") && pattern.hasSuffix("*") {
                examples += "- Applications with '\(patternWithoutWildcards)' in their identifier\n"
                examples += "- Example: 'com.\(patternWithoutWildcards).app'\n"
                examples += "- Example: 'app.\(patternWithoutWildcards).client'"
            } else if pattern.hasPrefix("*") {
                examples += "- Applications with identifiers ending with '\(patternWithoutWildcards)'\n"
                examples += "- Example: 'com.example.\(patternWithoutWildcards)'"
            } else if pattern.hasSuffix("*") {
                examples += "- Applications with identifiers starting with '\(patternWithoutWildcards)'\n"
                examples += "- Example: '\(patternWithoutWildcards).example.app'"
            }
        }
        
        return examples
    }
    
    /// Saves a window type
    private func saveWindowType(_ windowType: WindowType) {
        if viewModel.configManager.windowTypes.contains(where: { $0.id == windowType.id }) {
            // Update existing
            viewModel.configManager.updateWindowType(windowType)
            showToast = true
            toastMessage = "Window type '\(windowType.name)' updated"
        } else {
            // Add new
            viewModel.configManager.addWindowType(windowType)
            showToast = true
            toastMessage = "Window type '\(windowType.name)' added"
        }
        
        // Refresh window types
        loadWindowTypes()
        selectedType = windowType
        editingType = nil
        showingEditSheet = false
    }
}

/// View for editing window type properties
struct WindowTypeEditView: View {
    /// Window type being edited
    @State var windowType: WindowType
    
    /// Callback when the window type is saved
    var onSave: (WindowType) -> Void
    
    /// Callback when editing is canceled
    var onCancel: () -> Void
    
    /// Whether to show the pattern helper
    @State private var showPatternHelper = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text(windowType.id.isEmpty ? "Add Window Type" : "Edit Window Type")
                .font(.title)
                .padding(.bottom, 10)
            
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Name", text: $windowType.name)
                        .textFieldStyle(.roundedBorder)
                        .padding(.vertical, 5)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Title Pattern:")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("Pattern Helper") {
                                showPatternHelper.toggle()
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.accentColor)
                        }
                        
                        TextField("Title Pattern", text: $windowType.titlePattern)
                            .textFieldStyle(.roundedBorder)
                            .help("Use * as wildcard. Example: *Poker* matches any window with 'Poker' in title")
                    }
                    .padding(.vertical, 5)
                    
                    TextField("Window Class", text: $windowType.classPattern)
                        .textFieldStyle(.roundedBorder)
                        .help("Use * as wildcard. Often this is the app's bundle identifier")
                        .padding(.vertical, 5)
                    
                    Toggle("Enabled", isOn: $windowType.enabled)
                        .padding(.vertical, 5)
                }
                
                if showPatternHelper {
                    Section(header: Text("Pattern Helper")) {
                        patternHelperView
                    }
                }
                
                Section(header: Text("Pattern Examples")) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Title patterns:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("*Poker* - Matches any window with 'Poker' in the title\n" +
                                 "Texas* - Matches window titles starting with 'Texas'\n" +
                                 "*Table - Matches window titles ending with 'Table'\n" +
                                 "Table 1 - Matches only the exact title 'Table 1'")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color(.textBackgroundColor)))
                            
                            Text("Window class patterns:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 5)
                            
                            Text("com.pokerstars.* - Matches any PokerStars window\n" +
                                 "com.partypoker.client - Matches exactly this class\n" +
                                 "*poker* - Matches any class containing 'poker'")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color(.textBackgroundColor)))
                        }
                    }
                    .frame(height: 200)
                }
            }
            
            Divider()
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save") {
                    onSave(windowType)
                }
                .buttonStyle(.borderedProminent)
                .disabled(windowType.name.isEmpty || windowType.titlePattern.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 600, height: 650)
    }
    
    /// Helper view for creating patterns
    private var patternHelperView: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Common patterns for poker windows:")
                .font(.subheadline)
            
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Button("*Hold'em*") {
                        windowType.titlePattern = "*Hold'em*"
                    }
                    .buttonStyle(.bordered)
                    
                    Button("*Omaha*") {
                        windowType.titlePattern = "*Omaha*"
                    }
                    .buttonStyle(.bordered)
                    
                    Button("*Table*") {
                        windowType.titlePattern = "*Table*"
                    }
                    .buttonStyle(.bordered)
                }
                
                GridRow {
                    Button("*Tournament*") {
                        windowType.titlePattern = "*Tournament*"
                    }
                    .buttonStyle(.bordered)
                    
                    Button("*Cash*") {
                        windowType.titlePattern = "*Cash*"
                    }
                    .buttonStyle(.bordered)
                    
                    Button("*Sit & Go*") {
                        windowType.titlePattern = "*Sit & Go*"
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Text("Common patterns for poker clients:")
                .font(.subheadline)
                .padding(.top, 5)
            
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Button("com.pokerstars.*") {
                        windowType.classPattern = "com.pokerstars.*"
                    }
                    .buttonStyle(.bordered)
                    
                    Button("com.partypoker.*") {
                        windowType.classPattern = "com.partypoker.*"
                    }
                    .buttonStyle(.bordered)
                }
                
                GridRow {
                    Button("com.888poker.*") {
                        windowType.classPattern = "com.888poker.*"
                    }
                    .buttonStyle(.bordered)
                    
                    Button("com.ggpoker.*") {
                        windowType.classPattern = "com.ggpoker.*"
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Text("Click on the buttons above to insert common patterns")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 5)
        }
        .padding(10)
        .background(Color(.textBackgroundColor).opacity(0.3))
        .cornerRadius(8)
    }
}
