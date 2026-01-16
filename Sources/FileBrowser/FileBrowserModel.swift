//  Copyright © 2024 Audulus LLC. All rights reserved.

import Foundation
import Observation
import UniformTypeIdentifiers

@Observable
class FileBrowserModel: @unchecked Sendable {

    // See https://forums.swift.org/t/dispatchsource-crash-under-swift-6/75951

    var urls: [URL] = []
    var selected = Set<URL>()
    var selecting = false
    var urlToOpen: URL? = nil  // Used to trigger programmatic opening animation
    var urlToClose: URL? = nil  // Used to trigger programmatic closing animation
    let pathExtension: String
    let utType: UTType
    let newDocumentURL: URL
    let exclude: [String]

    enum Error: Swift.Error {
        case noDocumentsDirectory
    }

    init(utType: UTType, pathExtension: String, newDocumentURL: URL, exclude: [String]) {
        self.utType = utType
        self.pathExtension = pathExtension
        self.newDocumentURL = newDocumentURL
        self.exclude = exclude

        scan()
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private var directoryFileDescriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?

    func startMonitoring() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

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

        guard let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.standardizedFileURL else {
            print("⚠️ couldn't get documents directory")
            return
        }

        urls = []

        let mgr = FileManager.default
        guard let enumerator = mgr.enumerator(at: docsDir, includingPropertiesForKeys: nil) else {
            print("⚠️ couldn't get directory enumerator")
            return
        }

        let excludeURLs = exclude.map { docsDir.appendingPathComponent($0, isDirectory: true) }

        while let url = enumerator.nextObject() as? URL {

            if excludeURLs.contains(url.standardizedFileURL) {
                enumerator.skipDescendants()
                continue
            }

            if url.pathExtension == pathExtension {
                urls.append(url)
            }
        }

        urls.sort(by: { $0.lastPathComponent < $1.lastPathComponent} )
    }

    func rename(url: URL, to: String) throws {
        let mgr = FileManager.default
        try mgr.moveItem(at: url, to: url.deletingLastPathComponent().appendingPathComponent(to, conformingTo: utType))
    }

    func delete(url: URL) throws {
        let mgr = FileManager.default
        try mgr.removeItem(at: url)
    }

    func deleteSelected() throws {
        let mgr = FileManager.default
        for url in selected {
            try mgr.removeItem(at: url)
        }
        selected = []
    }

    func duplicateSelected() throws {
        let mgr = FileManager.default

        for url in selected {
            let destUrl = try getFileURL(base: url.deletingPathExtension().lastPathComponent)
            try mgr.copyItem(at: url, to: destUrl)
        }
    }

    func getFileURL(base: String) throws -> URL  {

        let mgr = FileManager.default

        guard let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw Error.noDocumentsDirectory
        }

        var comp = "\(base).\(pathExtension)"

        var counter = 1
        while mgr.fileExists(atURL: docsDir.appending(component: comp)) {
            comp = "\(base) \(counter).\(pathExtension)"
            counter += 1
        }

        return docsDir.appending(component: comp)
    }

    func newDocument() throws -> URL {
        let mgr = FileManager.default
        let destUrl = try getFileURL(base: "Untitled")
        try mgr.copyItem(at: newDocumentURL, to: destUrl)
        return destUrl
    }

    func importFile(at url: URL) {

        guard let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("⚠️ couldn't get documents directory")
            return
        }

        // gain access to the directory
        let gotAccess = url.startAccessingSecurityScopedResource()
        if !gotAccess { return }

        let mgr = FileManager.default

        do {
            try mgr.copyItem(at: url, to: docsDir.appending(component: url.lastPathComponent))
        } catch {
            print("⚠️ error importing")
        }

        // release access
        url.stopAccessingSecurityScopedResource()
    }
}
