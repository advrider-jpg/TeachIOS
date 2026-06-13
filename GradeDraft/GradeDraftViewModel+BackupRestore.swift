import Foundation
import PDFKit
import UIKit
import ZIPFoundation

@MainActor
extension GradeDraftViewModel {
    func mergeRestoredAssignments(_ restored: [AssignmentRecord], resolution: BackupConflictResolution) -> (assignments: [AssignmentRecord], idMap: [UUID: UUID]) {
        var byID = Dictionary(uniqueKeysWithValues: assignments.map { ($0.id, $0) })
        var idMap: [UUID: UUID] = [:]
        for record in restored {
            if let existing = byID[record.id] {
                switch resolution {
                case .keepLocal:
                    var local = existing
                    local.appendAuditEvent(.inputChanged, detail: "Backup restore detected a conflict and kept the local assignment.")
                    byID[local.id] = local
                case .replaceLocal:
                    var replacement = record
                    replacement.appendAuditEvent(.inputChanged, detail: "Backup restore replaced the local assignment after conflict resolution.")
                    byID[record.id] = replacement
                case .restoreAsCopy:
                    var copy = record
                    let originalID = copy.id
                    copy.id = UUID()
                    idMap[originalID] = copy.id
                    copy.sourceInputs = copy.sourceInputs.map { source in
                        var sourceCopy = source
                        if let localRelativePath = source.localRelativePath {
                            sourceCopy.localRelativePath = localRelativePath.replacingOccurrences(
                                of: "Sources/\(originalID.uuidString)/",
                                with: "Sources/\(copy.id.uuidString)/"
                            )
                        }
                        return sourceCopy
                    }
                    copy.title = "Restored copy of \(record.title)"
                    copy.appendAuditEvent(.inputChanged, detail: "Restored as copy because a local record existed with the same ID.")
                    byID[copy.id] = copy
                }
            } else {
                var restoredRecord = record
                restoredRecord.appendAuditEvent(.inputChanged, detail: "Restored from local backup archive.")
                byID[restoredRecord.id] = restoredRecord
            }
        }
        return (Array(byID.values), idMap)
    }

    func previewBackupRestore(from url: URL) {
        do {
            let stagedURL = try stageBackupForRestorePreview(from: url)
            let preview: BackupRestorePreview
            if stagedURL.pathExtension.lowercased() == "zip" {
                preview = try BundleExportService.previewRestore(from: stagedURL, existingAssignments: assignments)
            } else {
                preview = try previewLegacyJSONRestore(from: stagedURL)
            }
            pendingRestoreFileURL = stagedURL
            pendingRestoreFingerprint = try fileFingerprint(stagedURL)
            pendingRestorePreview = preview
            latestRestorePreview = preview
            statusMessage = "Backup preview is ready. Confirm the import option before restoring records."
        } catch {
            pendingRestoreFileURL = nil
            pendingRestoreFingerprint = nil
            pendingRestorePreview = nil
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func confirmPendingRestore() {
        guard let pendingRestoreFileURL else {
            errorMessage = "Choose and preview a backup before importing."
            return
        }
        do {
            let currentFingerprint = try fileFingerprint(pendingRestoreFileURL)
            guard pendingRestoreFingerprint == currentFingerprint else {
                errorMessage = "The staged backup changed after preview. Review the backup again before importing."
                return
            }
        } catch {
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
            return
        }
        errorMessage = nil
        restoreBackup(from: pendingRestoreFileURL)
        guard errorMessage == nil else { return }
        try? fileManager.removeItem(at: pendingRestoreFileURL)
        self.pendingRestoreFileURL = nil
        self.pendingRestoreFingerprint = nil
        self.pendingRestorePreview = nil
    }

    func cancelPendingRestore() {
        if let pendingRestoreFileURL { try? fileManager.removeItem(at: pendingRestoreFileURL) }
        self.pendingRestoreFileURL = nil
        self.pendingRestoreFingerprint = nil
        self.pendingRestorePreview = nil
        statusMessage = "Backup import canceled before records were changed."
    }

    func stageBackupForRestorePreview(from url: URL) throws -> URL {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.isEmpty ? "backup" : url.pathExtension.lowercased()
        let destination = fileManager.temporaryDirectory
            .appendingPathComponent("MarkForMe-PendingRestore-\(UUID().uuidString)")
            .appendingPathExtension(ext)
        if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
        try fileManager.copyItem(at: url, to: destination)
        LocalDataProtection.protectSensitiveFile(destination, fileManager: fileManager)
        return destination
    }

    func previewLegacyJSONRestore(from url: URL) throws -> BackupRestorePreview {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode([AssignmentRecord].self, from: data)
        return BackupRestorePreview(
            archiveKind: "legacy-json",
            schemaVersion: "legacy-json",
            assignmentCount: restored.count,
            classCount: 0,
            studentCount: 0,
            sourceFileCount: 0,
            conflictAssignmentIDs: restored.compactMap { record in assignments.contains(where: { $0.id == record.id }) ? record.id : nil },
            warnings: ["Legacy JSON backup does not contain original files, classes, students, or backup details."]
        )
    }

    func restoreBackup(from url: URL) {
        var restoredSourceRelativePaths: [String] = []
        do {
            let restored: [AssignmentRecord]
            let restoredDatabaseExport: BackupDatabaseExport?
            if url.pathExtension.lowercased() == "zip" {
                latestRestorePreview = try BundleExportService.previewRestore(from: url, existingAssignments: assignments)
                let restoreResult = try BundleExportService.prepareBackupRestore(
                    from: url,
                    existingAssignments: assignments,
                    applicationSupportDirectory: try store.applicationSupportDirectory(),
                    conflictResolution: backupConflictResolution
                )
                restored = restoreResult.assignments
                restoredDatabaseExport = restoreResult.databaseExport
                restoredSourceRelativePaths = restoreResult.restoredSourceRelativePaths
            } else {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let rawRestored = try decoder.decode([AssignmentRecord].self, from: data)
                restored = sanitizedLegacyRestoredAssignments(rawRestored)
                restoredDatabaseExport = nil
                latestRestorePreview = BackupRestorePreview(
                    archiveKind: "legacy-json",
                    schemaVersion: "legacy-json",
                    assignmentCount: restored.count,
                    classCount: 0,
                    studentCount: 0,
                    sourceFileCount: 0,
                    conflictAssignmentIDs: restored.compactMap { record in assignments.contains(where: { $0.id == record.id }) ? record.id : nil },
                    warnings: ["Legacy JSON backup does not contain original files, classes, students, or backup details."]
                )
            }
            guard !restored.isEmpty else {
                errorMessage = "Backup contained no assignments."
                return
            }

            let localAssignments = assignments
            let localClassGroups = classGroups
            let localStudents = students
            let localRosterEntries = assignmentRosterEntries
            let mergeResult = mergeRestoredAssignments(restored, resolution: backupConflictResolution)
            let nextAssignments = mergeResult.assignments.sorted { $0.updatedAt > $1.updatedAt }

            let nextClassGroups: [ClassGroupRecord]
            let nextStudents: [StudentRecord]
            if backupConflictResolution == .replaceLocal {
                nextClassGroups = restoredDatabaseExport?.classGroups.sorted { $0.name < $1.name } ?? Self.classGroupsFromAssignments(nextAssignments)
                nextStudents = restoredDatabaseExport?.students.sorted { $0.displayName < $1.displayName } ?? Self.studentsFromAssignments(nextAssignments)
            } else {
                nextClassGroups = mergedClassGroups(local: localClassGroups, restored: restoredDatabaseExport?.classGroups ?? [])
                nextStudents = mergedStudents(local: localStudents, restored: restoredDatabaseExport?.students ?? [])
            }

            let archiveAssignmentIDMap: [UUID: UUID] = restoredDatabaseExport.map { databaseExport in
                Dictionary(uniqueKeysWithValues: zip(databaseExport.assignments, restored).compactMap { original, restoredRecord in
                    original.id == restoredRecord.id ? nil : (original.id, restoredRecord.id)
                })
            } ?? [:]
            let rosterAssignmentIDMap = archiveAssignmentIDMap.merging(mergeResult.idMap) { _, viewModelRemappedID in viewModelRemappedID }
            let localConflictIDs = Set(localAssignments.map(\.id)).intersection(Set((restoredDatabaseExport?.assignments ?? restored).map(\.id)))
            let restoredRosterCandidates = remappedRestoredRosterEntries(
                restoredDatabaseExport?.rosterEntries ?? [],
                assignmentIDMap: rosterAssignmentIDMap,
                conflictResolution: backupConflictResolution,
                localConflictAssignmentIDs: localConflictIDs,
                assignmentsForStatus: nextAssignments
            )
            let rosterCandidates = backupConflictResolution == .replaceLocal ? restoredRosterCandidates : localRosterEntries + restoredRosterCandidates
            let nextRosterEntries = reconciledRosterEntries(rosterCandidates, assignments: nextAssignments, students: nextStudents)
            let snapshot = AssignmentStoreSnapshot(
                assignments: nextAssignments,
                classGroups: nextClassGroups,
                students: nextStudents,
                rosterEntries: nextRosterEntries
            )

            try store.replaceLocalDataSnapshot(snapshot)
            assignments = snapshot.assignments
            classGroups = snapshot.classGroups
            students = snapshot.students
            assignmentRosterEntries = snapshot.rosterEntries
            selectedAssignmentID = assignments.first?.id
            statusMessage = "Restored \(restored.count) assignment(s) plus related class, student, roster, and original-file records from local backup with \(backupConflictResolution.displayName.lowercased()) handling."
        } catch {
            cleanupRestoredSourceFiles(restoredSourceRelativePaths)
            reloadFromStoreAfterPersistenceFailure()
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
            statusMessage = "Restore failed. Local data and original files were rolled back to their previous state."
        }
    }

    func fileFingerprint(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return StableFingerprint.fingerprint(data)
    }
}
