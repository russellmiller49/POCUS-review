import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var activeSheet: ActiveSheet?

    private enum ActiveSheet: Identifiable {
        case studyDetail(AppViewModel.StudyDetailState)

        var id: UUID {
            switch self {
            case .studyDetail(let detail):
                return detail.id
            }
        }
    }

    var body: some View {
        Group {
            switch viewModel.currentSession?.role.userRole {
            case .some(.fellow):
                FellowDashboardTabView()
            case .some(.attending):
                AttendingExperienceView()
            case .some(.administrator):
                AdministratorExperienceView()
            case .none:
                ProgressView("Loading role…")
            }
        }
        .onAppear {
            updateActiveSheet(with: viewModel.studyDetail)
        }
        .onChange(of: viewModel.studyDetail?.id) { _ in
            updateActiveSheet(with: viewModel.studyDetail)
        }
        .sheet(item: $activeSheet, onDismiss: {
            viewModel.dismissStudyDetail()
        }) { sheet in
            switch sheet {
            case .studyDetail(let detail):
                StudyDetailView(detail: detail)
            }
        }
    }

    private func updateActiveSheet(with detail: AppViewModel.StudyDetailState?) {
        if let detail {
            activeSheet = .studyDetail(detail)
        } else {
            activeSheet = nil
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppViewModel())
}

private extension MembershipRole {
    var userRole: UserRole {
        switch self {
        case .fellow:
            return .fellow
        case .attending:
            return .attending
        case .administrator, .admin:
            return .administrator
        }
    }
}
