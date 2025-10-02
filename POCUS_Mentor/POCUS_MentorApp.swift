//
//  POCUS_MentorApp.swift
//  POCUS_Mentor
//
//  Updated to showcase full app experience based on requirements in POCUS_App_Features_Plain_English.md
//

import SwiftUI

@main
struct POCUS_MentorApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
