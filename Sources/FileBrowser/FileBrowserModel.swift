//  Copyright © 2024 Audulus LLC. All rights reserved.

import Foundation
import Observation
import UniformTypeIdentifiers

struct FileBrowserItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case document
        case group
    }

    let kind: Kind
    let url: URL
    let thumbnailURLs: [URL]

    var id: URL { url }

    var isDocument: Bool {
        kind == .document
    }

    var isGroup: Bool {
        kind == .group
    }
}

@Observable
class FileBrowserModel: @unchecked Sendable {

    // See https://forums.swift.org/t/dispatchsource-crash-under-swift-6/75951

    static let groupMarkerFilename = ".filebrowser-group"

    var items: [FileBrowserItem] = []
    var urls: [URL] = []
    var selected = Set<URL>()
    var selecting = false
    var openURL: URL? = nil  // Used to trigger programmatic opening animation
    var currentDirectoryURL: URL
    let documentsURL: URL
    let pathExtension: String
    let utType: UTType
    let newDocumentURL: URL
    let exclude: [String]

    enum Error: Swift.Error {
        case groupNeedsMultipleDocuments
        case invalidGroupDocument
        case invalidGroup
    }

    init(utType: UTType,
         pathExtension: String,
         newDocumentURL: URL,
         exclude: [String],
         documentsURL: URL? = nil,
         shouldStartMonitoring: Bool = true) {
        self.utType = utType
        self.pathExtension = pathExtension
        self.newDocumentURL = newDocumentURL
        self.exclude = exclude
        self.documentsURL = documentsURL?.standardizedFileURL
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.standardizedFileURL
        self.currentDirectoryURL = self.documentsURL

        scan()
        if shouldStartMonitoring {
            startMonitoring()
        }
    }

    deinit {
        stopMonitoring()
    }

    private var directoryFileDescriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?

    func startMonitoring() {
        // Open the directory to get a file descriptor.
        directoryFileDescriptor = open(documentsURL.path, O_EVTONLY)
        guard directoryFileDescriptor >= 0 else {
            print("Failed to open directory.")
            return
        }

        // Create the dispatch source.
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryFileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global()
        )

        // Set the event handler.
        source?.setEventHandler { [weak self] in
            guard let self = self else { return }
            // Trouble making this work using Task:
            // https://forums.swift.org/t/dispatchsource-crash-under-swift-6/75951
            DispatchQueue.main.async {
                self.scan()
            }
        }

        let fd = directoryFileDescriptor

        // Set the cancel handler to close the file descriptor.
        source?.setCancelHandler {
            close(fd)
        }

        // Start monitoring.
        source?.resume()
    }

    func stopMonitoring() {
        source?.cancel()
        source = nil
    }

    func scan() {

        let docsDir = documentsURL.standardizedFileURL
        let mgr = FileManager.default

        if !isDirectory(currentDirectoryURL) || !currentDirectoryURL.isEqualOrDescendant(of: docsDir) {
            currentDirectoryURL = docsDir
        }

        items = []
        urls = []

        guard let enumerator = mgr.enumerator(at: currentDirectoryURL, includingPropertiesForKeys: [.isDirectoryKey]) else {
            print("⚠️ couldn't get directory enumerator")
            return
        }

        let excludeURLs = exclude.map { docsDir.appendingPathComponent($0, isDirectory: true) }

        while let url = enumerator.nextObject() as? URL {
            let standardizedURL = url.standardizedFileURL

            if excludeURLs.contains(standardizedURL) {
                enumerator.skipDescendants()
                continue
            }

            if isGroupDirectory(standardizedURL) {
                if standardizedURL.deletingLastPathComponent().standardizedFileURL == currentDirectoryURL.standardizedFileURL {
                    items.append(
                        FileBrowserItem(kind: .group,
                                        url: standardizedURL,
                                        thumbnailURLs: thumbnailURLs(in: standardizedURL))
                    )
                }
                enumerator.skipDescendants()
                continue
            }

            if standardizedURL.pathExtension == pathExtension {
                items.append(FileBrowserItem(kind: .document, url: standardizedURL, thumbnailURLs: []))

                if isDirectory(standardizedURL) {
                    enumerator.skipDescendants()
                }
            }
        }

        items.sort(by: { $0.url.lastPathComponent < $1.url.lastPathComponent })
        urls = items.filter(\.isDocument).map(\.url)
        selected.formIntersection(Set(items.map(\.url)))
    }

    func rename(url: URL, to: String) throws {
        let mgr = FileManager.default
        try mgr.moveItem(at: url, to: url.deletingLastPathComponent().appendingPathComponent(to, conformingTo: utType))
        scan()
    }

    func rename(item: FileBrowserItem, to: String) throws {
        let destinationURL: URL

        switch item.kind {
        case .document:
            destinationURL = item.url.deletingLastPathComponent().appendingPathComponent(to, conformingTo: utType)
        case .group:
            destinationURL = item.url.deletingLastPathComponent().appendingPathComponent(to, isDirectory: true)
        }

        try FileManager.default.moveItem(at: item.url, to: destinationURL)
        scan()
    }

    func delete(url: URL) throws {
        let mgr = FileManager.default
        try mgr.removeItem(at: url)
        scan()
    }

    func deleteSelected() throws {
        let mgr = FileManager.default
        for url in selected {
            try mgr.removeItem(at: url)
        }
        selected = []
        scan()
    }

    func duplicateSelected() throws {
        let mgr = FileManager.default

        for item in selectedItems {
            let destURL: URL
            switch item.kind {
            case .document:
                destURL = try getFileURL(base: item.url.deletingPathExtension().lastPathComponent,
                                         in: item.url.deletingLastPathComponent())
            case .group:
                destURL = try getGroupURL(base: item.url.lastPathComponent,
                                          in: item.url.deletingLastPathComponent())
            }

            try mgr.copyItem(at: item.url, to: destURL)
        }

        scan()
    }

    func getFileURL(base: String) throws -> URL  {
        try getFileURL(base: base, in: documentsURL)
    }

    func getFileURL(base: String, in directoryURL: URL) throws -> URL  {
        let mgr = FileManager.default

        var comp = "\(base).\(pathExtension)"

        var counter = 1
        while mgr.fileExists(atURL: directoryURL.appending(component: comp)) {
            comp = "\(base) \(counter).\(pathExtension)"
            counter += 1
        }

        return directoryURL.appending(component: comp)
    }

    func getGroupURL(base: String, in directoryURL: URL) throws -> URL {
        let mgr = FileManager.default
        var comp = base

        var counter = 1
        while mgr.fileExists(atURL: directoryURL.appending(component: comp, directoryHint: .isDirectory)) {
            comp = "\(base) \(counter)"
            counter += 1
        }

        return directoryURL.appending(component: comp, directoryHint: .isDirectory)
    }

    func newDocument() throws -> URL {
        let mgr = FileManager.default
        let destUrl = try getFileURL(base: "Untitled", in: currentDirectoryURL)
        try mgr.copyItem(at: newDocumentURL, to: destUrl)
        return destUrl
    }

    func importFile(at url: URL) {

        // gain access to the directory
        let gotAccess = url.startAccessingSecurityScopedResource()
        if !gotAccess { return }

        let mgr = FileManager.default

        do {
            try mgr.copyItem(at: url, to: currentDirectoryURL.appending(component: url.lastPathComponent))
        } catch {
            print("⚠️ error importing")
        }

        // release access
        url.stopAccessingSecurityScopedResource()
    }

    var isInGroup: Bool {
        currentDirectoryURL.standardizedFileURL != documentsURL.standardizedFileURL
    }

    var currentGroupName: String? {
        isInGroup ? currentDirectoryURL.lastPathComponent : nil
    }

    var selectedItems: [FileBrowserItem] {
        items.filter { selected.contains($0.url) }
    }

    var canGroupSelected: Bool {
        selectedItems.filter(\.isDocument).count >= 2
    }

    var canUngroupSelected: Bool {
        selectedItems.contains(where: \.isGroup)
    }

    func enterGroup(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        guard isGroupDirectory(standardizedURL) else { return }

        currentDirectoryURL = standardizedURL
        selected = []
        selecting = false
        scan()
    }

    func leaveGroup() {
        guard isInGroup else { return }

        currentDirectoryURL = currentDirectoryURL.deletingLastPathComponent().standardizedFileURL
        selected = []
        selecting = false
        scan()
    }

    @discardableResult
    func groupSelected() throws -> FileBrowserItem {
        let documents = selectedItems.filter(\.isDocument).map(\.url)
        return try createGroup(containing: documents)
    }

    @discardableResult
    func group(document sourceURL: URL, with destinationURL: URL) throws -> FileBrowserItem {
        try createGroup(containing: [sourceURL.standardizedFileURL, destinationURL.standardizedFileURL])
    }

    func move(document sourceURL: URL, intoGroup groupURL: URL) throws {
        let documentURL = sourceURL.standardizedFileURL
        let targetGroupURL = groupURL.standardizedFileURL

        guard isDocumentURL(documentURL), itemExists(at: documentURL, kind: .document) else {
            throw Error.invalidGroupDocument
        }

        guard itemExists(at: targetGroupURL, kind: .group), isGroupDirectory(targetGroupURL) else {
            throw Error.invalidGroup
        }

        let destinationURL = try getFileURL(base: documentURL.deletingPathExtension().lastPathComponent,
                                            in: targetGroupURL)
        try FileManager.default.moveItem(at: documentURL, to: destinationURL)
        selected.remove(documentURL)
        scan()
    }

    func ungroupSelected() throws {
        let groupURLs = selectedItems.filter(\.isGroup).map(\.url)

        for groupURL in groupURLs {
            try ungroup(groupURL)
        }

        selected = []
        selecting = false
        scan()
    }

    private func createGroup(containing documentURLs: [URL]) throws -> FileBrowserItem {
        let documents = Array(Set(documentURLs.map(\.standardizedFileURL)))
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })

        guard documents.count >= 2 else {
            throw Error.groupNeedsMultipleDocuments
        }

        guard documents.allSatisfy({ isDocumentURL($0) && itemExists(at: $0, kind: .document) }) else {
            throw Error.invalidGroupDocument
        }

        let groupURL = try getGroupURL(base: "Group", in: currentDirectoryURL)
        let mgr = FileManager.default
        try mgr.createDirectory(at: groupURL, withIntermediateDirectories: false)
        try Data().write(to: groupURL.appendingPathComponent(Self.groupMarkerFilename))

        for documentURL in documents {
            let destinationURL = try getFileURL(base: documentURL.deletingPathExtension().lastPathComponent,
                                                in: groupURL)
            try mgr.moveItem(at: documentURL, to: destinationURL)
        }

        selected = []
        selecting = false
        scan()

        return items.first(where: { $0.url == groupURL }) ?? FileBrowserItem(
            kind: .group,
            url: groupURL,
            thumbnailURLs: thumbnailURLs(in: groupURL)
        )
    }

    private func ungroup(_ groupURL: URL) throws {
        let standardizedGroupURL = groupURL.standardizedFileURL
        guard itemExists(at: standardizedGroupURL, kind: .group), isGroupDirectory(standardizedGroupURL) else {
            throw Error.invalidGroup
        }

        let mgr = FileManager.default
        let parentURL = standardizedGroupURL.deletingLastPathComponent()
        let documentURLs = try mgr.contentsOfDirectory(at: standardizedGroupURL, includingPropertiesForKeys: [.isDirectoryKey])
            .map(\.standardizedFileURL)
            .filter { $0.pathExtension == pathExtension }
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })

        for documentURL in documentURLs {
            let destinationURL = try getFileURL(base: documentURL.deletingPathExtension().lastPathComponent,
                                                in: parentURL)
            try mgr.moveItem(at: documentURL, to: destinationURL)
        }

        try mgr.removeItem(at: standardizedGroupURL)
    }

    private func itemExists(at url: URL, kind: FileBrowserItem.Kind) -> Bool {
        items.contains { $0.kind == kind && $0.url.standardizedFileURL == url.standardizedFileURL }
    }

    private func isDocumentURL(_ url: URL) -> Bool {
        url.pathExtension == pathExtension
    }

    private func isGroupDirectory(_ url: URL) -> Bool {
        let markerURL = url.appendingPathComponent(Self.groupMarkerFilename)
        return isDirectory(url) && FileManager.default.fileExists(atURL: markerURL)
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    private func thumbnailURLs(in groupURL: URL) -> [URL] {
        let mgr = FileManager.default

        guard let urls = try? mgr.contentsOfDirectory(at: groupURL, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return []
        }

        return urls
            .map(\.standardizedFileURL)
            .filter { $0.pathExtension == pathExtension }
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            .prefix(4)
            .map { $0 }
    }
}

private extension URL {
    func isEqualOrDescendant(of ancestor: URL) -> Bool {
        let path = resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false).trimmingTrailingSlash()
        let ancestorPath = ancestor.resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false).trimmingTrailingSlash()

        return path == ancestorPath || path.hasPrefix("\(ancestorPath)/")
    }
}

private extension String {
    func trimmingTrailingSlash() -> String {
        hasSuffix("/") ? String(dropLast()) : self
    }
}
