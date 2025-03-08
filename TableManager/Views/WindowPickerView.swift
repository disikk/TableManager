//
//  WindowPickerView.swift
//  TableManager
//
//  Created for TableManager macOS app
//

import SwiftUI

/// View for selecting windows by clicking
struct WindowPickerView: View {
    /// View model for the window selector
    @ObservedObject private var viewModel: WindowSelectorViewModel
    
    /// Callback when window selection completes, returns selected type or nil if canceled
    var onFinish: (WindowType?) -> Void
    
    /// Selected refinement strategy
    @State private var refinementStrategy = 0 // 0: Simple, 1: Intelligent
    
    /// Whether to show test results
    @State private var showingTestResults = false
    
    /// Whether to show a success message
    @State private var showingSuccess = false
    
    /// Initializer accepting WindowManager (for compatibility with existing code)
    init(windowManager: WindowManager, onWindowSelected: @escaping (WindowType) -> Void) {
        self.viewModel = WindowSelectorViewModel(windowManager: windowManager)
        self.onFinish = { windowType in
            if let windowType = windowType {
                onWindowSelected(windowType)
            }
        }
    }
    
    /// Initializer accepting WindowSelectorViewModel directly
    init(windowSelectorViewModel: WindowSelectorViewModel, onFinish: @escaping (WindowType?) -> Void) {
        self.viewModel = windowSelectorViewModel
        self.onFinish = onFinish
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Window Selector")
                    .font(.headline)
                    .padding(.leading)
                
                Spacer()
                
                Button(action: {
                    onFinish(nil)
                }) {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                    .frame(width: 10)
            }
            .padding(.vertical, 10)
            .background(Color(.controlBackgroundColor))
            
            // Content
            VStack {
                if viewModel.isSelecting {
                    selectingView
                } else if let windowType = viewModel.createdWindowType {
                    windowTypeCreatedView(windowType)
                } else if let window = viewModel.selectedWindow {
                    windowSelectedView(window)
                } else {
                    startView
                }
            }
            .padding()
        }
        .frame(width: 700, height: 600)
        .onAppear {
            if !viewModel.isSelecting {
                viewModel.startSelection()
            }
        }
        .onDisappear {
            viewModel.stopSelection()
        }
    }
    
    // View shown when starting window selection
    private var startView: some View {
        VStack(spacing: 25) {
            Image(systemName: "macwindow.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("Window Selector")
                .font(.title)
            
            Text("This tool helps you create a new window type by selecting an existing window on your screen.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button("Select a Window") {
                viewModel.startSelection()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // View shown during active window selection
    private var selectingView: some View {
        VStack(spacing: 25) {
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .opacity(0.8)
            
            Text("Click on a Window to Select It")
                .font(.title)
            
            Text("Move your mouse over the window you want to use for creating a window type, then click to select it.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            HStack {
                Text("Current position:")
                    .foregroundColor(.secondary)
                Text("(\(Int(viewModel.mousePosition.x)), \(Int(viewModel.mousePosition.y)))")
                    .monospaced()
            }
            .padding(.top, 10)
            
            if let highlightedWindow = viewModel.highlightedWindow {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Highlighted Window:")
                        .font(.headline)
                        .padding(.bottom, 2)
                    
                    Text(highlightedWindow.title)
                        .lineLimit(1)
                        .foregroundColor(.accentColor)
                    
                    Text(highlightedWindow.windowClass)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.controlBackgroundColor)))
            }
            
            Text("Press Escape to cancel selection")
                .font(.caption)
                .padding(.top, 10)
            
            Text(viewModel.statusMessage)
                .padding(.top, 20)
                .foregroundColor(.accentColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // View shown after a window has been selected
    private func windowSelectedView(_ window: WindowInfo) -> some View {
        VStack(spacing: 20) {
            Text("Window Selected")
                .font(.title)
            
            Divider()
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 15) {
                GridRow {
                    Text("Title:")
                        .foregroundColor(.secondary)
                    Text(window.title)
                        .lineLimit(1)
                }
                
                GridRow {
                    Text("Window Class:")
                        .foregroundColor(.secondary)
                    Text(window.windowClass)
                        .lineLimit(1)
                }
                
                GridRow {
                    Text("Process ID:")
                        .foregroundColor(.secondary)
                    Text("\(window.pid)")
                }
                
                GridRow {
                    Text("Window ID:")
                        .foregroundColor(.secondary)
                    Text("\(window.id)")
                }
                
                GridRow {
                    Text("Position:")
                        .foregroundColor(.secondary)
                    Text("(\(Int(window.frame.minX)), \(Int(window.frame.minY)))")
                }
                
                GridRow {
                    Text("Size:")
                        .foregroundColor(.secondary)
                    Text("\(Int(window.frame.width)) × \(Int(window.frame.height))")
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.controlBackgroundColor)))
            
            Divider()
            
            Text("Pattern generation strategy:")
                .font(.headline)
            
            Picker("Strategy", selection: $refinementStrategy) {
                Text("Simple pattern").tag(0)
                Text("Intelligent pattern detection").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            Text(refinementStrategy == 0 ? 
                "Simple pattern will match this specific window type" : 
                "Intelligent pattern will analyze the window to create a pattern that matches similar windows")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            HStack {
                Button("Select Another Window") {
                    viewModel.startSelection()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Create Window Type") {
                    if refinementStrategy == 0 {
                        // Simple pattern
                        if let type = viewModel.createWindowTypeFromSelection() {
                            onFinish(type)
                        }
                    } else {
                        // Intelligent pattern
                        if let type = viewModel.createRefinedWindowType() {
                            onFinish(type)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    // View shown after a window type has been created
    private func windowTypeCreatedView(_ windowType: WindowType) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Window Type Created")
                .font(.title)
            
            Divider()
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 15) {
                GridRow {
                    Text("Name:")
                        .foregroundColor(.secondary)
                    Text(windowType.name)
                }
                
                GridRow {
                    Text("Title Pattern:")
                        .foregroundColor(.secondary)
                    Text(windowType.titlePattern)
                }
                
                GridRow {
                    Text("Window Class:")
                        .foregroundColor(.secondary)
                    Text(windowType.classPattern)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.controlBackgroundColor)))
            
            // Test results
            HStack {
                if viewModel.testWindowTypeMatch() {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                
                Text(viewModel.statusMessage)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.controlBackgroundColor)))
            
            Spacer()
            
            HStack {
                Button("Start Over") {
                    viewModel.startSelection()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Add Window Type") {
                    onFinish(windowType)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

struct WindowPickerView_Previews: PreviewProvider {
    static var previews: some View {
        WindowPickerView(
            windowManager: WindowManager(),
            onWindowSelected: { _ in }
        )
    }
}
