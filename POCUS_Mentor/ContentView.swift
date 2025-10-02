//
//  ContentView.swift
//  POCUS_Mentor
//
//  Root container for the POCUS Mentor experience.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        NavigationStack {
            Group {
                if let role = appState.selectedRole {
                    RoleExperienceContainer(role: role)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                RoleSwitcherButton(selectedRole: role) {
                                    appState.resetState()
                                }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                NotificationBellView()
                            }
                        }
                } else {
                    RoleSelectionView()
                        .navigationTitle("POCUS Mentor")
                        .toolbarTitleDisplayMode(.inline)
                }
            }
            .animation(.spring(duration: 0.35), value: appState.selectedRole)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
