import Foundation
import Combine
import TUSKit

@MainActor
final class TUSUploadService: NSObject, ObservableObject {
    enum UploadStatus: Equatable {
        case queued
        case uploading(progress: Double)
        case completed(location: URL)
        case failed(message: String)
    }

    struct UploadContext: Identifiable, Equatable {
        let id: UUID
        let studyId: UUID
        let institutionId: UUID
        let objectName: String
        let contentType: String
        let fileURL: URL
    }

    struct UploadHandle {
        let id: UUID
        let context: UploadContext
    }

    @Published private(set) var uploads: [UUID: UploadStatus] = [:]
    @Published private(set) var contexts: [UUID: UploadContext] = [:]

    private let client: TUSClient
    private let configuration: AppConfig

    init(
        configuration: AppConfig,
        sessionIdentifier: String = "POCUS-Uploads",
        backgroundIdentifier: String = "mil.nmcsd.pocus.uploads"
    ) {
        self.configuration = configuration

        let sessionConfiguration = URLSessionConfiguration.background(withIdentifier: backgroundIdentifier)
        sessionConfiguration.isDiscretionary = false
        sessionConfiguration.sessionSendsLaunchEvents = true
        sessionConfiguration.allowsCellularAccess = true
        sessionConfiguration.timeoutIntervalForRequest = 60 * 5
        sessionConfiguration.timeoutIntervalForResource = 60 * 10

        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let storageDirectory = documentsDirectory.appendingPathComponent("TUS")

        do {
            self.client = try TUSClient(
                server: configuration.supabase.resumableUploadEndpoint,
                sessionIdentifier: sessionIdentifier,
                sessionConfiguration: sessionConfiguration,
                storageDirectory: storageDirectory,
                chunkSize: configuration.uploadChunkSize
            )
        } catch {
            fatalError("Unable to initialize TUSClient: \(error)")
        }

        super.init()

        client.delegate = self
        _ = client.start()
    }

    convenience override init() {
        self.init(configuration: AppConfig.shared)
    }

    func enqueueUpload(
        fileURL: URL,
        studyId: UUID,
        institutionId: UUID,
        contentType: String,
        accessToken: String,
        cacheControl: String = "3600",
        metadata: [String: Any] = ["source": "ios", "deidentified": true],
        upsert: Bool = true
    ) throws -> UploadHandle {
        let fileUUID = UUID()
        let objectName = makeObjectName(
            institutionId: institutionId,
            studyId: studyId,
            fileId: fileUUID,
            sourceURL: fileURL,
            contentType: contentType
        )

        let metadataJSONData = try JSONSerialization.data(withJSONObject: metadata, options: [])
        let metadataJSONString = String(data: metadataJSONData, encoding: .utf8) ?? "{}"

        var uploadMetadata = [
            "bucketName": configuration.supabase.bucket,
            "objectName": objectName,
            "contentType": contentType,
            "cacheControl": cacheControl,
            "metadata": metadataJSONString
        ]

        // Include a reference so we can decode the context later.
        uploadMetadata["studyId"] = studyId.uuidString
        uploadMetadata["institutionId"] = institutionId.uuidString

        var headers = [
            "Authorization": "Bearer \(accessToken)"
        ]
        if upsert {
            headers["x-upsert"] = "true"
        }

        let uploadId = try client.uploadFileAt(
            filePath: fileURL,
            uploadURL: nil,
            customHeaders: headers,
            context: uploadMetadata
        )

        let context = UploadContext(
            id: uploadId,
            studyId: studyId,
            institutionId: institutionId,
            objectName: objectName,
            contentType: contentType,
            fileURL: fileURL
        )

        contexts[uploadId] = context
        uploads[uploadId] = .queued

        return UploadHandle(id: uploadId, context: context)
    }

    func cancelUpload(id: UUID) {
        do {
            try client.cancel(id: id)
            uploads[id] = .failed(message: "Cancelled")
        } catch {
            uploads[id] = .failed(message: "Cancel failed: \(error.localizedDescription)")
        }
    }

    func resumePersistedUploads() {
        _ = client.start()
    }

    private func makeObjectName(
        institutionId: UUID,
        studyId: UUID,
        fileId: UUID,
        sourceURL: URL,
        contentType: String
    ) -> String {
        let ext = fileExtension(for: sourceURL, contentType: contentType)
        let object = "studies/\(institutionId.uuidString)/\(studyId.uuidString)/\(fileId.uuidString)\(ext)"
        return object.lowercased()
    }

    private func fileExtension(for url: URL, contentType: String) -> String {
        if let ext = url.pathExtension.nonEmpty {
            return ".\(ext.lowercased())"
        }
        switch contentType.lowercased() {
        case "video/quicktime": return ".mov"
        case "video/mp4": return ".mp4"
        case "image/jpeg": return ".jpg"
        case "image/png": return ".png"
        default: return ""
        }
    }
}

extension TUSUploadService: TUSClientDelegate {
    nonisolated func didStartUpload(id: UUID, context: [String: String]?, client: TUSClient) {
        Task { @MainActor in
            self.uploads[id] = .uploading(progress: 0)
        }
    }

    nonisolated func didFinishUpload(id: UUID, url: URL, context: [String: String]?, client: TUSClient) {
        Task { @MainActor in
            self.uploads[id] = .completed(location: url)
        }
    }

    nonisolated func uploadFailed(id: UUID, error: Error, context: [String: String]?, client: TUSClient) {
        Task { @MainActor in
            self.uploads[id] = .failed(message: error.localizedDescription)
        }
    }

    nonisolated func fileError(error: TUSClientError, client: TUSClient) {
        Task { @MainActor in
            print("TUS file error: \(error)")
        }
    }

    @available(iOS 11.0, *)
    nonisolated func totalProgress(bytesUploaded: Int, totalBytes: Int, client: TUSClient) {
        // No-op for now; UI can derive from per-upload progress.
    }

    @available(iOS 11.0, *)
    nonisolated func progressFor(id: UUID, context: [String: String]?, bytesUploaded: Int, totalBytes: Int, client: TUSClient) {
        guard totalBytes > 0 else { return }
        let progress = Double(bytesUploaded) / Double(totalBytes)
        Task { @MainActor in
            self.uploads[id] = .uploading(progress: progress)
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
