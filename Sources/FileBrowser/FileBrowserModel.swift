//  Copyright © 2024 Audulus LLC. All rights reserved.

import Foundation
import Observation
import UniformTypeIdentifiers

@Observable
class FileBrowserModel {

    var urls: [URL] = []
    var selected = Set<URL>()
    var selecting = false
    let pathExtension: String
    let utType: UTType
    let newDocumentURL: URL

    enum Error: Swift.Error {
        case noDocumentsDirectory
    }

    init(utType: UTType, pathExtension: String, newDocumentURL: URL) {
        self.utType = utType
        self.pathExtension = pathExtension
        self.newDocumentURL = newDocumentURL
        scan()
    }

    func scan() {

        guard let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("⚠️ couldn't get documents directory")
            return
        }

        urls = []

        let mgr = FileManager.default
        let enumerator = mgr.enumerator(at: docsDir, includingPropertiesForKeys: nil)

        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == pathExtension {
                urls.append(url)
            }
        }

        urls.sort(by: { $0.lastPathComponent < $1.lastPathComponent} )
    }

    func rename(url: URL, to: String) throws {
        let mgr = FileManager.default
        try mgr.moveItem(at: url, to: url.deletingLastPathComponent().appendingPathComponent(to, conformingTo: utType))
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

        for url in selected {
            let destUrl = try getFileURL(base: url.deletingPathExtension().lastPathComponent)
            try mgr.copyItem(at: url, to: destUrl)
        }

        scan()
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

    func newDocument() throws {
        let mgr = FileManager.default
        let destUrl = try getFileURL(base: "Untitled")
        try mgr.copyItem(at: newDocumentURL, to: destUrl)

        scan()
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

        scan()
    }
}
