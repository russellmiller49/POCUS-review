import Foundation
import SwiftUI

// Critical Care Ultrasound Module Categories
enum UltrasoundModule: String, CaseIterable, Identifiable {
    case cardiac = "Cardiac"
    case ivc = "IVC"
    case lung = "Lung Ultrasound"
    case pleural = "Pleural Ultrasound"
    case renal = "Renal"
    case bladder = "Bladder"
    case aorta = "Abdominal Aorta"
    case vascularAccess = "Vascular Access"
    case dvt = "DVT Ultrasound"

    var id: String { rawValue }

    var requiredImages: Int {
        switch self {
        case .cardiac: return 50
        case .ivc: return 10
        case .lung: return 20
        case .pleural: return 20
        case .renal: return 10
        case .bladder: return 10
        case .aorta: return 10
        case .vascularAccess: return 10
        case .dvt: return 10
        }
    }

    var description: String {
        switch self {
        case .cardiac: return "PLAX, PSAX, Apical 4C, Subcostal"
        case .ivc: return "Longitudinal, inspiratory variation"
        case .lung: return "A-lines, B-lines, consolidation"
        case .pleural: return "Simple effusion, complex effusion, pneumothorax/lung point"
        case .renal: return "Longitudinal, Transverse"
        case .bladder: return "Longitudinal, Transverse"
        case .aorta: return "Ascending/Descending/Abdominal"
        case .vascularAccess: return "IJ, subclavian, femoral"
        case .dvt: return "Compression, femoral/popliteal"
        }
    }

    var requiredViews: [String] {
        switch self {
        case .cardiac:
            return ["PLAX - Standard", "PSAX - Aortic Valve Level", "PSAX - Mitral Valve Level",
                    "Apical 4-Chamber", "Subcostal 4-Chamber"]
        case .ivc:
            return ["IVC Longitudinal", "IVC with Respiratory Variation"]
        case .lung:
            return ["A-lines", "B-lines", "Consolidation", "Lung Sliding"]
        case .pleural:
            return ["Simple Effusion", "Complex Effusion", "Pneumothorax/Lung Point"]
        case .renal:
            return ["Renal Longitudinal", "Renal Transverse"]
        case .bladder:
            return ["Bladder Longitudinal", "Bladder Transverse"]
        case .aorta:
            return ["Ascending Aorta", "Descending Aorta", "Abdominal Aorta"]
        case .vascularAccess:
            return ["Internal Jugular", "Subclavian", "Femoral"]
        case .dvt:
            return ["Femoral Compression", "Popliteal Compression"]
        }
    }

    var color: Color {
        switch self {
        case .cardiac: return .red
        case .ivc: return .blue
        case .lung: return .cyan
        case .pleural: return .teal
        case .renal: return .orange
        case .bladder: return .yellow
        case .aorta: return .pink
        case .vascularAccess: return .green
        case .dvt: return .purple
        }
    }
}

// Standard Transthoracic Echocardiographic Views (ASE Guidelines 2019)
enum EchoView: String, CaseIterable, Identifiable {
    // Parasternal Long Axis Views
    case plaxStandard = "PLAX - Standard"
    case plaxIncreasedDepth = "PLAX - Increased Depth"
    case plaxZoomedAorticValve = "PLAX - Zoomed Aortic Valve"
    case plaxZoomedMitralValve = "PLAX - Zoomed Mitral Valve"
    case plaxRVOutflow = "PLAX - RV Outflow"
    case plaxRVInflow = "PLAX - RV Inflow"

    // Parasternal Short Axis Views
    case psaxGreatVessels = "PSAX - Great Vessels"
    case psaxAorticValve = "PSAX - Aortic Valve Level"
    case psaxMitralValve = "PSAX - Mitral Valve Level"
    case psaxPapillaryMuscle = "PSAX - Papillary Muscle Level"
    case psaxApex = "PSAX - Apex Level"

    // Apical Views
    case apical4Chamber = "Apical 4-Chamber"
    case apical5Chamber = "Apical 5-Chamber"
    case apical2Chamber = "Apical 2-Chamber"
    case apicalLongAxis = "Apical Long Axis"
    case apicalRVFocused = "Apical RV-Focused 4-Chamber"
    case apicalCoronarySinus = "Apical Coronary Sinus"

    // Subcostal Views
    case subcostal4Chamber = "Subcostal 4-Chamber"
    case subcostalIVC = "Subcostal IVC"
    case subcostalHepaticVeins = "Subcostal Hepatic Veins"
    case subcostalAbdominalAorta = "Subcostal Abdominal Aorta"

    // Suprasternal Views
    case suprasternalAorticArch = "Suprasternal Aortic Arch"
    case suprasternalAorticArchLongAxis = "Suprasternal Aortic Arch - Long Axis"

    var id: String { rawValue }

    var category: String {
        switch self {
        case .plaxStandard, .plaxIncreasedDepth, .plaxZoomedAorticValve, .plaxZoomedMitralValve, .plaxRVOutflow, .plaxRVInflow:
            return "Parasternal Long Axis"
        case .psaxGreatVessels, .psaxAorticValve, .psaxMitralValve, .psaxPapillaryMuscle, .psaxApex:
            return "Parasternal Short Axis"
        case .apical4Chamber, .apical5Chamber, .apical2Chamber, .apicalLongAxis, .apicalRVFocused, .apicalCoronarySinus:
            return "Apical"
        case .subcostal4Chamber, .subcostalIVC, .subcostalHepaticVeins, .subcostalAbdominalAorta:
            return "Subcostal"
        case .suprasternalAorticArch, .suprasternalAorticArchLongAxis:
            return "Suprasternal"
        }
    }

    var shortName: String {
        switch self {
        case .plaxStandard: return "PLAX"
        case .plaxIncreasedDepth: return "PLAX Deep"
        case .plaxZoomedAorticValve: return "PLAX AV"
        case .plaxZoomedMitralValve: return "PLAX MV"
        case .plaxRVOutflow: return "PLAX RVOT"
        case .plaxRVInflow: return "PLAX RVIT"
        case .psaxGreatVessels: return "PSAX GV"
        case .psaxAorticValve: return "PSAX AV"
        case .psaxMitralValve: return "PSAX MV"
        case .psaxPapillaryMuscle: return "PSAX PM"
        case .psaxApex: return "PSAX Apex"
        case .apical4Chamber: return "A4C"
        case .apical5Chamber: return "A5C"
        case .apical2Chamber: return "A2C"
        case .apicalLongAxis: return "A3C/LAX"
        case .apicalRVFocused: return "RV A4C"
        case .apicalCoronarySinus: return "CS"
        case .subcostal4Chamber: return "SC 4C"
        case .subcostalIVC: return "SC IVC"
        case .subcostalHepaticVeins: return "SC HV"
        case .subcostalAbdominalAorta: return "SC Aorta"
        case .suprasternalAorticArch: return "SSN Arch"
        case .suprasternalAorticArchLongAxis: return "SSN LAX"
        }
    }

    static var groupedByCategory: [(category: String, views: [EchoView])] {
        let categories = ["Parasternal Long Axis", "Parasternal Short Axis", "Apical", "Subcostal", "Suprasternal"]
        return categories.map { category in
            (category: category, views: EchoView.allCases.filter { $0.category == category })
        }
    }
}

enum UserRole: String, CaseIterable, Identifiable {
    case fellow
    case attending
    case administrator
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .fellow: return "Fellow"
        case .attending: return "Attending"
        case .administrator: return "Administrator"
        }
    }
    
    var systemImage: String {
        switch self {
        case .fellow: return "stethoscope"
        case .attending: return "person.crop.rectangle"
        case .administrator: return "chart.bar.xaxis"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .fellow: return .blue
        case .attending: return .green
        case .administrator: return .purple
        }
    }
}

struct PortfolioProgress: Hashable {
    var module: UltrasoundModule
    var acceptedCount: Int
    var requiredCount: Int

    var progress: Double {
        guard requiredCount > 0 else { return 0 }
        return min(Double(acceptedCount) / Double(requiredCount), 1.0)
    }

    var isComplete: Bool {
        acceptedCount >= requiredCount
    }
}

struct Fellow: Identifiable, Hashable {
    let id: UUID
    var name: String
    var specialty: String
    var year: String
    var institution: String
    var statistics: FellowStatistics
    var portfolioProgress: [PortfolioProgress] = UltrasoundModule.allCases.map {
        PortfolioProgress(module: $0, acceptedCount: 0, requiredCount: $0.requiredImages)
    }

    var totalPortfolioProgress: Double {
        let totalAccepted = portfolioProgress.reduce(0) { $0 + $1.acceptedCount }
        let totalRequired = portfolioProgress.reduce(0) { $0 + $1.requiredCount }
        guard totalRequired > 0 else { return 0 }
        return Double(totalAccepted) / Double(totalRequired)
    }
}

struct FellowStatistics: Hashable {
    var totalCases: Int
    var acceptedCases: Int
    var pendingCases: Int
    var averageQualityScore: Double
    var commonThemes: [String]
}

struct Attending: Identifiable, Hashable {
    let id: UUID
    var name: String
    var specialty: String
    var institution: String
    var averageTurnaroundHours: Double
    var bio: String
}

enum CaseUrgency: String, CaseIterable, Identifiable {
    case routine
    case priority
    case urgent
    case stat
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue.uppercased()
    }
    
    var color: Color {
        switch self {
        case .routine: return .blue
        case .priority: return .orange
        case .urgent: return .pink
        case .stat: return .red
        }
    }
}

enum CaseStatus: String, CaseIterable, Identifiable {
    case draft
    case submitted
    case reviewed
    case accepted
    case needsRevision
    case archived
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .submitted: return "Pending Review"
        case .reviewed: return "Reviewed"
        case .accepted: return "Accepted"
        case .needsRevision: return "Needs Revision"
        case .archived: return "Archived"
        }
    }
    
    var badgeColor: Color {
        switch self {
        case .draft: return .gray
        case .submitted: return .blue
        case .reviewed: return .teal
        case .accepted: return .green
        case .needsRevision: return .orange
        case .archived: return .secondary
        }
    }
}

struct CaseMedia: Identifiable, Hashable {
    enum MediaType: Hashable {
        case image
        case video
    }

    let id: UUID
    var title: String
    var type: MediaType
    var thumbnailName: String
    var description: String
    var echoView: EchoView?
    var fileURL: URL?
    var isRequired: Bool = true  // Primary required view for portfolio
    var isAdditional: Bool = false  // Additional/submodule view
}

struct ClinicalDetail: Identifiable, Hashable {
    let id: UUID = UUID()
    var label: String
    var value: String
}

enum FeedbackStatus: String, CaseIterable {
    case accepted
    case revisionsRequested
    case rejected
}

struct AnnotationPoint: Hashable {
    var x: CGFloat
    var y: CGFloat
}

struct FeedbackAnnotation: Identifiable, Hashable {
    let id: UUID
    var title: String
    var description: String
    var color: Color
    var mediaID: UUID?
    var timestamp: TimeInterval?
    var points: [AnnotationPoint]
    var annotatedImage: Data?
}

struct CaseFeedback: Identifiable, Hashable {
    let id: UUID
    var attending: Attending
    var status: FeedbackStatus
    var qualityRating: Int
    var summary: String
    var detailedComments: [String]
    var annotations: [FeedbackAnnotation]
    var teachingPoints: [String]
    var recommendedResources: [URL]
    var createdAt: Date
}

struct CaseTimelineEntry: Identifiable, Hashable {
    let id: UUID = UUID()
    var date: Date
    var actorName: String
    var action: String
    var icon: String
}

struct QualityChecklistItem: Identifiable, Hashable {
    let id: UUID = UUID()
    var title: String
    var isMet: Bool
}

struct POCUSCase: Identifiable, Hashable {
    let id: UUID
    var title: String
    var studyType: String
    var ultrasoundModule: UltrasoundModule
    var patientAge: Int
    var patientGender: String
    var clinicalIndication: String
    var urgency: CaseUrgency
    var submittedAt: Date
    var status: CaseStatus
    var fellow: Fellow
    var assignedAttending: Attending
    var preliminaryFindings: String
    var measurements: [ClinicalDetail]
    var media: [CaseMedia]
    var feedback: CaseFeedback?
    var timeline: [CaseTimelineEntry]
    var qualityChecklist: [QualityChecklistItem]
    var tags: [String]

    var requiredMedia: [CaseMedia] {
        media.filter { $0.isRequired }
    }

    var additionalMedia: [CaseMedia] {
        media.filter { $0.isAdditional }
    }
}

struct AnalyticsSnapshot: Hashable {
    var periodLabel: String
    var totalCases: Int
    var acceptanceRate: Double
    var averageReviewTimeHours: Double
    var topFeedbackThemes: [String]
    var skillTrends: [SkillTrend]
}

struct SkillTrend: Identifiable, Hashable {
    let id: UUID = UUID()
    var skillName: String
    var progressValues: [Double]
}

struct NotificationItem: Identifiable {
    let id: UUID = UUID()
    var title: String
    var message: String
    var date: Date
    var role: UserRole
    var isRead: Bool
    var actionLabel: String?
}

struct ProgramMetric: Identifiable {
    let id: UUID = UUID()
    var title: String
    var value: String
    var changeDescription: String
    var iconName: String
    var accentColor: Color
}

struct AdministratorReportSection: Identifiable {
    let id: UUID = UUID()
    var title: String
    var description: String
    var chartType: ChartType
    var highlights: [String]
    
    enum ChartType {
        case bar
        case line
        case pie
        case grid
    }
}

struct ResourceLink: Identifiable {
    let id: UUID = UUID()
    var title: String
    var description: String
    var url: URL
}

struct MessageThread: Identifiable {
    let id: UUID
    var participants: [String]
    var lastMessage: String
    var updatedAt: Date
}

struct SampleData {
    static let fellows: [Fellow] = {
        let emma = Fellow(
            id: UUID(),
            name: "Dr. Emma Chen",
            specialty: "Cardiology Fellow",
            year: "Year 2",
            institution: "Mercy Medical Center",
            statistics: .init(
                totalCases: 48,
                acceptedCases: 32,
                pendingCases: 5,
                averageQualityScore: 4.2,
                commonThemes: ["Optimize apical views", "Label valve planes", "Include Doppler traces"]
            )
        )
        let oliver = Fellow(
            id: UUID(),
            name: "Dr. Oliver Grant",
            specialty: "Critical Care Fellow",
            year: "Year 1",
            institution: "Mercy Medical Center",
            statistics: .init(
                totalCases: 26,
                acceptedCases: 14,
                pendingCases: 7,
                averageQualityScore: 3.8,
                commonThemes: ["Image depth", "Focus adjustments", "Measure LVOT"]
            )
        )
        return [emma, oliver]
    }()
    
    static let attendings: [Attending] = {
        let sanders = Attending(
            id: UUID(),
            name: "Dr. Alicia Sanders",
            specialty: "Advanced Echocardiography",
            institution: "Mercy Medical Center",
            averageTurnaroundHours: 8.4,
            bio: "Director of Echocardiography Education with 14 years of experience mentoring fellows."
        )
        let patel = Attending(
            id: UUID(),
            name: "Dr. Raj Patel",
            specialty: "Point-of-Care Ultrasound",
            institution: "Mercy Medical Center",
            averageTurnaroundHours: 6.1,
            bio: "Critical care attending focusing on rapid ultrasound assessment and feedback."
        )
        return [sanders, patel]
    }()
    
    static let resourceLinks: [ResourceLink] = [
        ResourceLink(title: "ASE Echocardiography Guide", description: "Comprehensive reference for echo acquisition standards.", url: URL(string: "https://www.asecho.org")!),
        ResourceLink(title: "POCUS Teaching Pearls", description: "Quick tips for common bedside ultrasound pitfalls.", url: URL(string: "https://www.pocus.org")!),
        ResourceLink(title: "Quality Checklist Template", description: "Downloadable checklist for fellows to self-evaluate scans.", url: URL(string: "https://example.com/checklist")!)
    ]
    
    static func cases(for fellow: Fellow? = nil) -> [POCUSCase] {
        let fellows = SampleData.fellows
        let attendings = SampleData.attendings
        let checklist: [QualityChecklistItem] = [
            .init(title: "Includes parasternal long axis", isMet: true),
            .init(title: "Clear view of LVOT", isMet: false),
            .init(title: "Doppler trace captured", isMet: true)
        ]
        let timeline: [CaseTimelineEntry] = [
            .init(date: Date().addingTimeInterval(-86400 * 3), actorName: "Dr. Emma Chen", action: "Submitted case", icon: "square.and.arrow.up"),
            .init(date: Date().addingTimeInterval(-86400 * 2), actorName: "Dr. Alicia Sanders", action: "Started review", icon: "eye"),
            .init(date: Date().addingTimeInterval(-86400), actorName: "Dr. Alicia Sanders", action: "Returned feedback", icon: "bubble.left")
        ]
        let measurements: [ClinicalDetail] = [
            .init(label: "EF (Simpson)", value: "52%"),
            .init(label: "LVIDd", value: "4.6 cm"),
            .init(label: "TR Vmax", value: "2.9 m/s")
        ]
        let caseFeedback = CaseFeedback(
            id: UUID(),
            attending: attendings[0],
            status: .accepted,
            qualityRating: 4,
            summary: "Strong acquisition with minor optimization needed for apical four chamber.",
            detailedComments: [
                "Great capture of parasternal views with good Doppler angles.",
                "Optimize color gain in apical four to reduce noise.",
                "Add one more sweep to confirm pericardial effusion absence."
            ],
            annotations: [
                .init(id: UUID(), title: "Check valve alignment", description: "Annotate the anterior mitral leaflet to emphasize calcification.", color: .orange, mediaID: nil, timestamp: nil, points: [], annotatedImage: nil),
                .init(id: UUID(), title: "Focus depth", description: "Reduce depth to bring LV apex into focus.", color: .blue, mediaID: nil, timestamp: nil, points: [], annotatedImage: nil)
            ],
            teachingPoints: [
                "Remember to capture at least two cycles for Doppler measurements.",
                "Review ASE guidelines for labeling valve planes."
            ],
            recommendedResources: [
                URL(string: "https://www.asecho.org/guidelines")!
            ],
            createdAt: Date().addingTimeInterval(-86400)
        )
        let media: [CaseMedia] = [
            .init(id: UUID(), title: "Parasternal Long Axis", type: .image, thumbnailName: "heart1", description: "Demonstrates LV function and aortic valve."),
            .init(id: UUID(), title: "Apical Four Chamber", type: .video, thumbnailName: "heart_video", description: "Clip highlighting mitral inflow."),
            .init(id: UUID(), title: "Subcostal IVC", type: .image, thumbnailName: "ivc", description: "Respiratory variation visible.")
        ]
        let case1 = POCUSCase(
            id: UUID(),
            title: "Point-of-care echo - cardiogenic shock",
            studyType: "Focused Cardiac Ultrasound",
            ultrasoundModule: .cardiac,
            patientAge: 64,
            patientGender: "Male",
            clinicalIndication: "Evaluate LV function and volume status in hypotensive ICU patient.",
            urgency: .urgent,
            submittedAt: Date().addingTimeInterval(-86400 * 3.5),
            status: .reviewed,
            fellow: fellows[0],
            assignedAttending: attendings[0],
            preliminaryFindings: "Global hypokinesis with reduced EF, dilated IVC with <50% collapse.",
            measurements: measurements,
            media: media,
            feedback: caseFeedback,
            timeline: timeline,
            qualityChecklist: checklist,
            tags: ["Cardiology", "Shock", "ICU"]
        )
        let case2 = POCUSCase(
            id: UUID(),
            title: "Dyspnea evaluation",
            studyType: "Lung Ultrasound",
            ultrasoundModule: .lung,
            patientAge: 44,
            patientGender: "Female",
            clinicalIndication: "Assess for pulmonary edema versus pneumonia.",
            urgency: .priority,
            submittedAt: Date().addingTimeInterval(-86400 * 1.5),
            status: .submitted,
            fellow: fellows[1],
            assignedAttending: attendings[1],
            preliminaryFindings: "B-lines in bilateral lung fields, small pleural effusion on the right.",
            measurements: [
                .init(label: "Respiratory Rate", value: "24/min"),
                .init(label: "Inferior Vena Cava", value: "2.1 cm")
            ],
            media: [
                .init(id: UUID(), title: "Right Anterior Lung", type: .video, thumbnailName: "lung_video", description: "Multiple B-lines visible."),
                .init(id: UUID(), title: "Pleural Effusion", type: .image, thumbnailName: "pleural", description: "Small effusion with lung sliding."),
            ],
            feedback: nil,
            timeline: [
                .init(date: Date().addingTimeInterval(-86400), actorName: "Dr. Raj Patel", action: "Assigned for review", icon: "person.badge.clock"),
            ],
            qualityChecklist: [
                .init(title: "Anterior, lateral, and posterior lung views", isMet: true),
                .init(title: "Document pleural sliding", isMet: true),
                .init(title: "Measure effusion depth", isMet: false)
            ],
            tags: ["Pulmonary", "Dyspnea"]
        )
        let filtered = [case1, case2].filter { caseData in
            guard let fellow = fellow else { return true }
            return caseData.fellow.id == fellow.id
        }
        return filtered
    }
    
    static let analyticsSnapshots: [AnalyticsSnapshot] = [
        AnalyticsSnapshot(
            periodLabel: "Last 30 Days",
            totalCases: 62,
            acceptanceRate: 0.68,
            averageReviewTimeHours: 10.4,
            topFeedbackThemes: ["Apical view optimization", "Labeling valve planes", "Color Doppler gain"],
            skillTrends: [
                SkillTrend(skillName: "Image Acquisition", progressValues: [0.42, 0.48, 0.55, 0.61]),
                SkillTrend(skillName: "Interpretation", progressValues: [0.33, 0.38, 0.46, 0.52]),
                SkillTrend(skillName: "Documentation", progressValues: [0.58, 0.62, 0.66, 0.71])
            ]
        ),
        AnalyticsSnapshot(
            periodLabel: "Quarter to Date",
            totalCases: 140,
            acceptanceRate: 0.72,
            averageReviewTimeHours: 8.9,
            topFeedbackThemes: ["Pericardial effusion assessment", "VTI tracing", "Right heart evaluation"],
            skillTrends: [
                SkillTrend(skillName: "Image Acquisition", progressValues: [0.31, 0.38, 0.46, 0.54]),
                SkillTrend(skillName: "Interpretation", progressValues: [0.29, 0.34, 0.41, 0.5]),
                SkillTrend(skillName: "Documentation", progressValues: [0.47, 0.58, 0.63, 0.69])
            ]
        )
    ]
    
    static let notifications: [NotificationItem] = [
        NotificationItem(title: "Feedback posted", message: "Dr. Sanders left annotated feedback on cardiogenic shock case.", date: Date().addingTimeInterval(-7200), role: .fellow, isRead: false, actionLabel: "View Feedback"),
        NotificationItem(title: "New case assigned", message: "Oliver Grant submitted a priority lung ultrasound.", date: Date().addingTimeInterval(-10800), role: .attending, isRead: false, actionLabel: "Open Queue"),
        NotificationItem(title: "Monthly report ready", message: "Download the May performance summary.", date: Date().addingTimeInterval(-86400 * 2), role: .administrator, isRead: true, actionLabel: "View Report")
    ]
    
    static let programMetrics: [ProgramMetric] = [
        ProgramMetric(title: "Active Fellows", value: "12", changeDescription: "+2 vs last year", iconName: "person.3.fill", accentColor: .blue),
        ProgramMetric(title: "Avg Review Time", value: "9.3h", changeDescription: "-1.1h MoM", iconName: "clock.fill", accentColor: .green),
        ProgramMetric(title: "Acceptance Rate", value: "74%", changeDescription: "+6 pts", iconName: "checkmark.seal.fill", accentColor: .teal),
        ProgramMetric(title: "Cases Reviewed", value: "320", changeDescription: "+18% QoQ", iconName: "doc.text.fill", accentColor: .orange)
    ]
    
    static let administratorReports: [AdministratorReportSection] = [
        AdministratorReportSection(title: "Fellow Performance", description: "Comparison of case acceptance and volume by fellow.", chartType: .bar, highlights: ["Emma Chen leads in case volume", "Improved acceptance rates across cohort"]),
        AdministratorReportSection(title: "Turnaround Times", description: "Average time from submission to feedback by attending.", chartType: .line, highlights: ["Goal of <12h met for 85% of cases"]),
        AdministratorReportSection(title: "Feedback Themes", description: "Most frequent educational focus areas.", chartType: .pie, highlights: ["Image acquisition remains top priority"])
    ]
    
    static let messageThreads: [MessageThread] = [
        MessageThread(id: UUID(), participants: ["Dr. Sanders", "Dr. Chen"], lastMessage: "Thanks for clarifying the Doppler angle!", updatedAt: Date().addingTimeInterval(-5400)),
        MessageThread(id: UUID(), participants: ["Admin Team"], lastMessage: "July compliance report is available.", updatedAt: Date().addingTimeInterval(-86400 * 4))
    ]
}
