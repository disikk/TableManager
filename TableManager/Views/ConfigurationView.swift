//
//  ConfigurationView.swift
//  TableManager
//
//  Created for TableManager macOS app
//

import SwiftUI

/// View for editing and managing a configuration
struct ConfigurationView: View {
    /// Current configuration
    @State var configuration: Configuration
    
    /// Main view model
    var viewModel: MainViewModel
    
    /// Edit mode for the layout grid
    @State private var isEditingLayout = false
    
    /// Current rows in the grid
    @State private var rows = 2
    
    /// Current columns in the grid
    @State private var columns = 2
    
    /// Whether to create overlapping slots
    @State private var createOverlappingSlots = false
    
    /// Overlap percentage for overlapping slots
    @State private var overlapPercentage: Double = 30.0
    
    /// Show confirmation for deleting
    @State private var showingDeleteConfirmation = false
    
    /// Show preview mode
    @State private var showingPreview = false
    
    /// Show auto-activation settings
    @State private var showingAutoActivation = false
    
    /// Edited configuration name
    @State private var editedName: String
    
    /// Selected slot for editing
    @State private var selectedSlotID: String? = nil
    
    /// Drag offset for slot editing
    @State private var dragOffset: CGSize = .zero
    
    /// Active drag operation
    @State private var activeDragType: DragType? = nil
    
    /// Show slot edit popup
    @State private var showingSlotEditor = false
    
    /// Selected window type for auto-activation rule
    @State private var selectedWindowTypeID: String = ""
    
    /// Selected window count for auto-activation rule
    @State private var selectedWindowCount: Int = 4
    
    /// Auto-activation type selection (0: window count, 1: window type count, 2: manual only)
    @State private var autoActivationType: Int = 0
    
    /// Scale factor for the layout preview
    @State private var previewScale: CGFloat = 1.0
    
    /// Show toast message
    @State private var showToast = false
    
    /// Toast message
    @State private var toastMessage = ""
    
    /// Enum for drag operation types
    enum DragType {
        case position
        case resize
    }
    
    init(configuration: Configuration, viewModel: MainViewModel) {
        self._configuration = State(initialValue: configuration)
        self.viewModel = viewModel
        self._editedName = State(initialValue: configuration.name)
        
        // Calculate rows and columns from layout
        if !configuration.layout.slots.isEmpty {
            // Get unique positions with a tolerance for slight misalignments
            let tolerance: CGFloat = 10.0
            
            let xPositions = configuration.layout.slots.map { $0.frame.minX }
            let yPositions = configuration.layout.slots.map { $0.frame.minY }
            
            // Count unique positions using tolerance
            var uniqueXPositions: [CGFloat] = []
            var uniqueYPositions: [CGFloat] = []
            
            for x in xPositions {
                if !uniqueXPositions.contains(where: { abs($0 - x) <= tolerance }) {
                    uniqueXPositions.append(x)
                }
            }
            
            for y in yPositions {
                if !uniqueYPositions.contains(where: { abs($0 - y) <= tolerance }) {
                    uniqueYPositions.append(y)
                }
            }
            
            self._rows = State(initialValue: uniqueYPositions.count)
            self._columns = State(initialValue: uniqueXPositions.count)
        }
        
        // Initialize auto-activation settings if present
        if let autoActivation = configuration.autoActivation {
            switch autoActivation {
            case .windowCount(let count):
                self._autoActivationType = State(initialValue: 0)
                self._selectedWindowCount = State(initialValue: count)
            case .windowTypeCount(let typeCounts):
                self._autoActivationType = State(initialValue: 1)
                if let firstType = typeCounts.keys.first {
                    self._selectedWindowTypeID = State(initialValue: firstType)
                    if let count = typeCounts[firstType] {
                        self._selectedWindowCount = State(initialValue: count)
                    }
                }
            }
        } else {
            self._autoActivationType = State(initialValue: 2) // Manual only
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Configuration details
                    configurationDetails
                    
                    // Layout preview/editor
                    layoutSection
                }
                .padding()
            }
        }
        .background(Color(.windowBackgroundColor))
        .onChange(of: editedName) { newName in
            var updatedConfig = configuration
            updatedConfig.name = newName
            viewModel.configManager.updateConfiguration(updatedConfig)
        }
        .alert("Delete Configuration", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.configManager.removeConfiguration(id: configuration.id)
            }
        } message: {
            Text("Are you sure you want to delete '\(configuration.name)'? This cannot be undone.")
        }
        .sheet(isPresented: $showingSlotEditor) {
            if let slotID = selectedSlotID, let slotIndex = configuration.layout.slots.firstIndex(where: { $0.id == slotID }) {
                SlotEditorView(
                    slot: $configuration.layout.slots[slotIndex],
                    onSave: { updatedSlot in
                        if let index = configuration.layout.slots.firstIndex(where: { $0.id == updatedSlot.id }) {
                            configuration.layout.slots[index] = updatedSlot
                            saveConfiguration()
                        }
                        showingSlotEditor = false
                    },
                    onCancel: {
                        showingSlotEditor = false
                    }
                )
            }
        }
        .overlay(
            Group {
                if showToast {
                    ToastView(message: toastMessage)
                        .transition(.move(edge: .bottom))
                        .animation(.easeInOut, value: showToast)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                showToast = false
                            }
                        }
                }
            }
        )
    }
    
    /// Toolbar for the configuration view
    private var toolbar: some View {
        HStack {
            Text(configuration.name)
                .font(.headline)
                .padding(.leading)
            
            Spacer()
            
            Button(action: {
                isEditingLayout.toggle()
                if isEditingLayout {
                    showToast = true
                    toastMessage = "Edit mode: Drag slots to reposition or resize"
                } else {
                    saveConfiguration()
                }
            }) {
                Label(isEditingLayout ? "Exit Edit Mode" : "Edit Layout", systemImage: isEditingLayout ? "checkmark.circle" : "pencil")
            }
            .buttonStyle(.bordered)
            
            Button(action: {
                showingPreview.toggle()
            }) {
                Label("Preview", systemImage: "eye")
            }
            .buttonStyle(.bordered)
            
            Button(action: {
                // Apply current layout to windows
                viewModel.configManager.activateConfiguration(id: configuration.id)
                showToast = true
                toastMessage = "Layout applied to windows"
            }) {
                Label("Apply", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
            
            Spacer()
                .frame(width: 10)
        }
        .padding(.vertical, 10)
        .background(Color(.controlBackgroundColor))
    }
    
    /// Configuration details section
    private var configurationDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Configuration Details")
                .font(.title2)
                .fontWeight(.semibold)
            
            Divider()
            
            VStack(alignment: .leading) {
                Text("Name")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Configuration Name", text: $editedName)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.bottom, 5)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Grid Dimensions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Stepper("\(rows) rows", value: $rows, in: 1...10)
                            .frame(width: 200)
                            .onChange(of: rows) { _ in
                                if !isEditingLayout {
                                    isEditingLayout = true
                                    showToast = true
                                    toastMessage = "Edit mode activated. Press 'Regenerate Grid' to apply changes."
                                }
                            }
                        
                        Spacer()
                        
                        Stepper("\(columns) columns", value: $columns, in: 1...10)
                            .frame(width: 200)
                            .onChange(of: columns) { _ in
                                if !isEditingLayout {
                                    isEditingLayout = true
                                    showToast = true
                                    toastMessage = "Edit mode activated. Press 'Regenerate Grid' to apply changes."
                                }
                            }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    regenerateGrid()
                    showToast = true
                    toastMessage = "Grid regenerated with \(rows) rows × \(columns) columns"
                }) {
                    Label("Regenerate Grid", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                .disabled(!isEditingLayout)
            }
            
            VStack(alignment: .leading) {
                Toggle("Create overlapping slots", isOn: $createOverlappingSlots)
                    .help("Create slots that overlap each other, useful for small screens with many tables")
                
                if createOverlappingSlots {
                    HStack {
                        Text("Overlap:")
                            .foregroundColor(.secondary)
                        
                        Slider(value: $overlapPercentage, in: 0...50, step: 5)
                            .frame(width: 200)
                        
                        Text("\(Int(overlapPercentage))%")
                            .frame(width: 40, alignment: .trailing)
                    }
                    .padding(.leading)
                }
            }
            .padding(.vertical, 5)
            
            Toggle("Auto-activation", isOn: $showingAutoActivation)
                .padding(.vertical, 5)
                .onChange(of: showingAutoActivation) { newValue in
                    if newValue && autoActivationType == 2 {
                        // Default to window count if showing auto-activation and currently set to manual
                        autoActivationType = 0
                    }
                }
            
            if showingAutoActivation {
                autoActivationSettings
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.controlBackgroundColor)))
    }
    
    /// Auto-activation settings
    private var autoActivationSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select when this configuration should automatically activate:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("Activation type", selection: $autoActivationType) {
                Text("Window Count").tag(0)
                Text("Window Type Count").tag(1)
                Text("Never (Manual Only)").tag(2)
            }
            .pickerStyle(.segmented)
            .onChange(of: autoActivationType) { newValue in
                updateAutoActivationSettings()
            }
            
            if autoActivationType == 0 {
                // Window count activation
                HStack {
                    Text("Activate when")
                        .foregroundColor(.secondary)
                    
                    Picker("Number of windows", selection: $selectedWindowCount) {
                        ForEach(1..<21) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    .frame(width: 100)
                    .onChange(of: selectedWindowCount) { _ in
                        updateAutoActivationSettings()
                    }
                    
                    Text("windows are detected")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 5)
            } else if autoActivationType == 1 {
                // Window type count activation
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Window Type:")
                            .foregroundColor(.secondary)
                        
                        Picker("Window Type", selection: $selectedWindowTypeID) {
                            ForEach(viewModel.configManager.windowTypes, id: \.id) { windowType in
                                Text(windowType.name).tag(windowType.id)
                            }
                        }
                        .onChange(of: selectedWindowTypeID) { _ in
                            updateAutoActivationSettings()
                        }
                    }
                    
                    HStack {
                        Text("Activate when")
                            .foregroundColor(.secondary)
                        
                        Picker("Number of windows", selection: $selectedWindowCount) {
                            ForEach(1..<21) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .frame(width: 100)
                        .onChange(of: selectedWindowCount) { _ in
                            updateAutoActivationSettings()
                        }
                        
                        Text("windows of this type are detected")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 5)
            } else {
                // Manual only - no auto-activation
                Text("This configuration will only be activated manually")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 5)
            }
            
            Button("Apply Auto-activation Settings") {
                saveAutoActivationSettings()
                showToast = true
                toastMessage = "Auto-activation settings saved"
            }
            .buttonStyle(.bordered)
            .disabled(autoActivationType == 2)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(.textBackgroundColor)))
    }
    
    /// Layout section with grid editor
    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Layout")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack {
                    Text("Scale:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $previewScale, in: 0.5...1.5, step: 0.1)
                        .frame(width: 100)
                    
                    Text("\(Int(previewScale * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                }
            }
            
            Divider()
            
            // Layout grid preview
            ZStack {
                layoutGrid
                
                if showingPreview {
                    previewOverlay
                }
            }
            .frame(height: 500 * previewScale)
            .clipped()
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.1)))
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.controlBackgroundColor)))
    }
    
    /// Layout grid editor
    private var layoutGrid: some View {
        VStack {
            if isEditingLayout {
                Text("Edit Mode: Drag slots to reposition, use corners to resize, or double-click to edit properties")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)
            }
            
            // Layout slots
            ZStack {
                // Background grid
                gridBackground
                
                // Slots
                ForEach(configuration.layout.slots) { slot in
                    SlotView(
                        slot: slot,
                        isSelected: selectedSlotID == slot.id,
                        isEditing: isEditingLayout,
                        onSelect: {
                            selectedSlotID = slot.id
                        },
                        onDoubleClick: {
                            selectedSlotID = slot.id
                            showingSlotEditor = true
                        },
                        onDragChanged: { dragType, value in
                            handleDrag(slot: slot, dragType: dragType, value: value)
                        },
                        onDragEnded: { _ in
                            finishDrag()
                        }
                    )
                }
            }
            .padding()
            .scaleEffect(previewScale)
        }
    }
    
    /// Grid background with lines
    private var gridBackground: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Rectangle()
                    .fill(Color.black.opacity(0.05))
                
                // Vertical grid lines
                ForEach(0..<columns+1, id: \.self) { column in
                    let x = geometry.size.width / CGFloat(columns) * CGFloat(column)
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 1)
                        .offset(x: x - geometry.size.width / 2)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                
                // Horizontal grid lines
                ForEach(0..<rows+1, id: \.self) { row in
                    let y = geometry.size.height / CGFloat(rows) * CGFloat(row)
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 1)
                        .offset(y: y - geometry.size.height / 2)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
    }
    
    /// Preview overlay when showing preview
    private var previewOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
            
            VStack {
                Text("Preview Mode")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                
                Text("This shows how windows will be arranged when this configuration is applied.")
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                
                // Add sample window previews representing different apps
                HStack(spacing: 20) {
                    VStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green.opacity(0.6))
                            .frame(width: 120, height: 90)
                        Text("PokerStars")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                    
                    VStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: 120, height: 90)
                        Text("PartyPoker")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                    
                    VStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red.opacity(0.6))
                            .frame(width: 120, height: 90)
                        Text("888poker")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                }
                .padding()
                
                Button("Exit Preview") {
                    showingPreview = false
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.windowBackgroundColor).opacity(0.8)))
        }
    }
    
    /// Handles drag operations on slots
    private func handleDrag(slot: Slot, dragType: DragType, value: DragGesture.Value) {
        guard isEditingLayout, let slotIndex = configuration.layout.slots.firstIndex(where: { $0.id == slot.id }) else { return }
        
        if activeDragType == nil {
            activeDragType = dragType
        }
        
        guard let dragType = activeDragType else { return }
        
        var updatedSlot = configuration.layout.slots[slotIndex]
        
        switch dragType {
        case .position:
            // Update position
            let newX = updatedSlot.frame.minX + value.translation.width
            let newY = updatedSlot.frame.minY + value.translation.height
            
            updatedSlot.frame.origin = CGPoint(x: newX, y: newY)
            
        case .resize:
            // Update size
            let newWidth = max(100, updatedSlot.frame.width + value.translation.width)
            let newHeight = max(80, updatedSlot.frame.height + value.translation.height)
            
            updatedSlot.frame.size = CGSize(width: newWidth, height: newHeight)
        }
        
        // Update the slot
        configuration.layout.slots[slotIndex] = updatedSlot
    }
    
    /// Finishes a drag operation and saves the configuration
    private func finishDrag() {
        activeDragType = nil
        saveConfiguration()
    }
    
    /// Saves the current configuration
    private func saveConfiguration() {
        viewModel.configManager.updateConfiguration(configuration)
    }
    
    /// Saves auto-activation settings
    private func saveAutoActivationSettings() {
        var updatedConfig = configuration
        
        switch autoActivationType {
        case 0:
            // Window count
            updatedConfig.autoActivation = .windowCount(selectedWindowCount)
        case 1:
            // Window type count
            if !selectedWindowTypeID.isEmpty {
                updatedConfig.autoActivation = .windowTypeCount([selectedWindowTypeID: selectedWindowCount])
            }
        case 2:
            // Manual only
            updatedConfig.autoActivation = nil
        default:
            break
        }
        
        // Save configuration
        configuration = updatedConfig
        viewModel.configManager.updateConfiguration(updatedConfig)
    }
    
    /// Updates auto-activation settings based on UI values
    private func updateAutoActivationSettings() {
        // Only update if activated
        if showingAutoActivation {
            saveAutoActivationSettings()
        }
    }
    
    /// Regenerates the grid based on current rows and columns
    private func regenerateGrid() {
        // Create a new layout with the current dimensions
        let newLayout: Layout
        
        if createOverlappingSlots {
            // Create an overlapping grid layout
            newLayout = viewModel.layoutEngine.createOverlappingGridLayout(
                rows: rows,
                columns: columns,
                overlap: CGFloat(overlapPercentage / 100.0),
                displayID: CGMainDisplayID()
            )
        } else {
            // Create a standard grid layout
            newLayout = viewModel.layoutEngine.createGridLayout(
                rows: rows,
                columns: columns,
                displayID: CGMainDisplayID()
            )
        }
        
        // Update configuration
        var updatedConfig = configuration
        updatedConfig.layout = newLayout
        configuration = updatedConfig
        
        // Save changes
        viewModel.configManager.updateConfiguration(updatedConfig)
        
        // Show toast with appropriate message
        let message = createOverlappingSlots
            ? "Grid regenerated with \(rows) rows × \(columns) columns and \(Int(overlapPercentage))% overlap"
            : "Grid regenerated with \(rows) rows × \(columns) columns"
        
        showToast = true
        toastMessage = message
    }
}

/// View for a single slot in the grid
struct SlotView: View {
    /// The slot
    let slot: Slot
    
    /// Whether the slot is currently selected
    let isSelected: Bool
    
    /// Whether we're in edit mode
    let isEditing: Bool
    
    /// Callback when slot is selected
    let onSelect: () -> Void
    
    /// Callback when slot is double clicked
    let onDoubleClick: () -> Void
    
    /// Callback when drag operation changes
    let onDragChanged: (ConfigurationView.DragType, DragGesture.Value) -> Void
    
    /// Callback when drag operation ends
    let onDragEnded: (DragGesture.Value) -> Void
    
    /// Tap gesture state for double-click detection
    @State private var tapCount = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Slot background
                Rectangle()
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1))
                    .border(isSelected ? Color.blue : Color.blue.opacity(0.5), width: 2)
                
                // Slot content
                VStack {
                    Text("Slot \(slot.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !isEditing {
                        // Show preview content
                        Text("Priority: \(slot.priority)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Resize handle in edit mode
                if isEditing {
                    VStack {
                        HStack {
                            Spacer()
                            
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                                .background(Circle().fill(Color.white).frame(width: 16, height: 16))
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            onDragChanged(.resize, value)
                                        }
                                        .onEnded { value in
                                            onDragEnded(value)
                                        }
                                )
                        }
                        
                        Spacer()
                    }
                    .padding(4)
                }
            }
            .position(
                x: slot.frame.midX,
                y: slot.frame.midY
            )
            .frame(
                width: slot.frame.width,
                height: slot.frame.height
            )
            .gesture(
                TapGesture()
                    .onEnded {
                        tapCount += 1
                        
                        // Schedule reset of tap count
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if tapCount == 1 {
                                onSelect()
                            } else if tapCount > 1 {
                                onDoubleClick()
                            }
                            tapCount = 0
                        }
                    }
            )
            // Position drag only available in edit mode
            .gesture(
                isEditing ? 
                DragGesture()
                    .onChanged { value in
                        onDragChanged(.position, value)
                    }
                    .onEnded { value in
                        onDragEnded(value)
                    } : nil
            )
        }
    }
}

/// View for editing slot properties
struct SlotEditorView: View {
    /// The slot being edited
    @Binding var slot: Slot
    
    /// Callback when saving
    let onSave: (Slot) -> Void
    
    /// Callback when canceling
    let onCancel: () -> Void
    
    /// Temporary slot ID
    @State private var slotID: String
    
    /// Temporary slot priority
    @State private var priority: Int
    
    /// Position X
    @State private var positionX: CGFloat
    
    /// Position Y
    @State private var positionY: CGFloat
    
    /// Width
    @State private var width: CGFloat
    
    /// Height
    @State private var height: CGFloat
    
    init(slot: Binding<Slot>, onSave: @escaping (Slot) -> Void, onCancel: @escaping () -> Void) {
        self._slot = slot
        self.onSave = onSave
        self.onCancel = onCancel
        
        // Initialize state properties
        self._slotID = State(initialValue: slot.wrappedValue.id)
        self._priority = State(initialValue: slot.wrappedValue.priority)
        self._positionX = State(initialValue: slot.wrappedValue.frame.minX)
        self._positionY = State(initialValue: slot.wrappedValue.frame.minY)
        self._width = State(initialValue: slot.wrappedValue.frame.width)
        self._height = State(initialValue: slot.wrappedValue.frame.height)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Slot Properties")
                .font(.headline)
            
            Form {
                Section(header: Text("Slot Information")) {
                    HStack {
                        Text("ID:")
                            .frame(width: 80, alignment: .trailing)
                        TextField("Slot ID", text: $slotID)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Text("Priority:")
                            .frame(width: 80, alignment: .trailing)
                        Picker("Priority", selection: $priority) {
                            ForEach(0..<10) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                
                Section(header: Text("Position and Size")) {
                    HStack {
                        Text("X:")
                            .frame(width: 80, alignment: .trailing)
                        TextField("X", value: $positionX, formatter: NumberFormatter())
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Text("Y:")
                            .frame(width: 80, alignment: .trailing)
                        TextField("Y", value: $positionY, formatter: NumberFormatter())
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Text("Width:")
                            .frame(width: 80, alignment: .trailing)
                        TextField("Width", value: $width, formatter: NumberFormatter())
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Text("Height:")
                            .frame(width: 80, alignment: .trailing)
                        TextField("Height", value: $height, formatter: NumberFormatter())
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
            }
            .padding()
            
            Divider()
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                
                Spacer()
                
                Button("Save") {
                    // Create updated slot
                    let updatedSlot = Slot(
                        id: slotID,
                        frame: CGRect(x: positionX, y: positionY, width: width, height: height),
                        displayID: slot.displayID,
                        priority: priority
                    )
                    
                    onSave(updatedSlot)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 500)
        .padding()
    }
}

/// Toast view for showing temporary messages
struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.controlBackgroundColor)))
            .padding(.bottom, 20)
    }
}
