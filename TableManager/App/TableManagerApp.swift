//
//  TableManagerApp.swift
//  TableManager
//
//  Created for TableManager macOS app
//

import SwiftUI

@main
struct TableManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appDelegate.mainViewModel)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            // Standard commands
            CommandGroup(replacing: .newItem) {
                Button("New Configuration") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowNewConfigSheet"), object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            // App-specific commands
            CommandMenu("Window") {
                Button("Capture Layout") {
                    NotificationCenter.default.post(name: NSNotification.Name("CaptureLayout"), object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
                
                Button("Select Window") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowWindowPicker"), object: nil)
                }
                .keyboardShortcut("w", modifiers: [.command, .option])
            }
        }
    }
}
