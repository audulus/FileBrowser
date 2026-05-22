import Foundation
import Testing
import UniformTypeIdentifiers
@testable import FileBrowser

@Test func groupingSelectedDocumentsCreatesANavigableGroup() throws {
    let fixture = try FileBrowserFixture()
    defer { fixture.remove() }

    let alpha = try fixture.writeDocument(named: "Alpha")
    let beta = try fixture.writeDocument(named: "Beta")
    let gamma = try fixture.writeDocument(named: "Gamma")
    let model = fixture.makeModel()

    model.selecting = true
    model.selected = [alpha.standardizedFileURL, beta.standardizedFileURL]

    let group = try model.groupSelected()

    #expect(group.kind == .group)
    #expect(group.url.lastPathComponent == "Group")
    #expect(FileManager.default.fileExists(atURL: group.url.appendingPathComponent(FileBrowserModel.groupMarkerFilename)))
    #expect(!FileManager.default.fileExists(atURL: alpha))
    #expect(!FileManager.default.fileExists(atURL: beta))
    #expect(FileManager.default.fileExists(atURL: group.url.appendingPathComponent("Alpha.fbdoc")))
    #expect(FileManager.default.fileExists(atURL: group.url.appendingPathComponent("Beta.fbdoc")))
    #expect(model.selected.isEmpty)
    #expect(!model.selecting)
    #expect(model.items.map(\.url.lastPathComponent) == ["Gamma.fbdoc", "Group"])
    #expect(model.items.first(where: { $0.url == group.url })?.thumbnailURLs.count == 2)

    model.enterGroup(group.url)

    #expect(model.isInGroup)
    #expect(model.urls.map(\.lastPathComponent) == ["Alpha.fbdoc", "Beta.fbdoc"])

    model.leaveGroup()

    #expect(!model.isInGroup)
    #expect(model.urls == [gamma.standardizedFileURL])
}

@Test func draggingOneDocumentOntoAnotherCreatesAGroup() throws {
    let fixture = try FileBrowserFixture()
    defer { fixture.remove() }

    let alpha = try fixture.writeDocument(named: "Alpha")
    let beta = try fixture.writeDocument(named: "Beta")
    let model = fixture.makeModel()

    let group = try model.group(document: alpha, with: beta)

    #expect(group.kind == .group)
    #expect(model.items.count == 1)
    #expect(model.items.first?.isGroup == true)
    #expect(FileManager.default.fileExists(atURL: group.url.appendingPathComponent("Alpha.fbdoc")))
    #expect(FileManager.default.fileExists(atURL: group.url.appendingPathComponent("Beta.fbdoc")))
}

@Test func draggingDocumentOntoGroupAddsItToThatGroup() throws {
    let fixture = try FileBrowserFixture()
    defer { fixture.remove() }

    let alpha = try fixture.writeDocument(named: "Alpha")
    let beta = try fixture.writeDocument(named: "Beta")
    let gamma = try fixture.writeDocument(named: "Gamma")
    let model = fixture.makeModel()

    let group = try model.group(document: alpha, with: beta)
    try model.move(document: gamma, intoGroup: group.url)

    #expect(!FileManager.default.fileExists(atURL: gamma))
    #expect(FileManager.default.fileExists(atURL: group.url.appendingPathComponent("Gamma.fbdoc")))
    #expect(model.items.count == 1)
    #expect(model.items.first?.isGroup == true)
    #expect(model.items.first?.thumbnailURLs.map(\.lastPathComponent) == ["Alpha.fbdoc", "Beta.fbdoc", "Gamma.fbdoc"])

    model.enterGroup(group.url)

    #expect(model.urls.map(\.lastPathComponent) == ["Alpha.fbdoc", "Beta.fbdoc", "Gamma.fbdoc"])
}

@Test func selectedGroupCanBeUngrouped() throws {
    let fixture = try FileBrowserFixture()
    defer { fixture.remove() }

    let alpha = try fixture.writeDocument(named: "Alpha")
    let beta = try fixture.writeDocument(named: "Beta")
    let gamma = try fixture.writeDocument(named: "Gamma")
    let model = fixture.makeModel()
    let group = try model.group(document: alpha, with: beta)

    model.selecting = true
    model.selected = [group.url]

    #expect(model.canUngroupSelected)

    try model.ungroupSelected()

    #expect(!FileManager.default.fileExists(atURL: group.url))
    #expect(FileManager.default.fileExists(atURL: fixture.documentsURL.appendingPathComponent("Alpha.fbdoc")))
    #expect(FileManager.default.fileExists(atURL: fixture.documentsURL.appendingPathComponent("Beta.fbdoc")))
    #expect(model.items.map(\.url.lastPathComponent) == ["Alpha.fbdoc", "Beta.fbdoc", "Gamma.fbdoc"])
    #expect(model.urls == [
        fixture.documentsURL.appendingPathComponent("Alpha.fbdoc").standardizedFileURL,
        fixture.documentsURL.appendingPathComponent("Beta.fbdoc").standardizedFileURL,
        gamma.standardizedFileURL
    ])
    #expect(model.selected.isEmpty)
    #expect(!model.selecting)
}

@Test func scanHidesGroupContentsFromParentButKeepsRecursiveDocumentsElsewhere() throws {
    let fixture = try FileBrowserFixture()
    defer { fixture.remove() }

    let looseFolder = fixture.documentsURL.appendingPathComponent("Loose", isDirectory: true)
    try FileManager.default.createDirectory(at: looseFolder, withIntermediateDirectories: true)
    let nested = looseFolder.appendingPathComponent("Nested.fbdoc")
    try Data("nested".utf8).write(to: nested)

    let groupURL = fixture.documentsURL.appendingPathComponent("Existing Group", isDirectory: true)
    try FileManager.default.createDirectory(at: groupURL, withIntermediateDirectories: true)
    try Data().write(to: groupURL.appendingPathComponent(FileBrowserModel.groupMarkerFilename))
    try Data("hidden".utf8).write(to: groupURL.appendingPathComponent("Hidden.fbdoc"))

    let model = fixture.makeModel()

    #expect(model.items.map(\.url.lastPathComponent) == ["Existing Group", "Nested.fbdoc"])
    #expect(model.urls == [nested.standardizedFileURL])

    model.enterGroup(groupURL)

    #expect(model.urls.map(\.lastPathComponent) == ["Hidden.fbdoc"])
}

private struct FileBrowserFixture {
    let rootURL: URL
    let documentsURL: URL
    let templateURL: URL

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        documentsURL = rootURL.appendingPathComponent("Documents", isDirectory: true)
        templateURL = rootURL.appendingPathComponent("Template.fbdoc")

        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        try Data("template".utf8).write(to: templateURL)
    }

    func makeModel() -> FileBrowserModel {
        FileBrowserModel(utType: UTType.data,
                         pathExtension: "fbdoc",
                         newDocumentURL: templateURL,
                         exclude: [],
                         documentsURL: documentsURL,
                         shouldStartMonitoring: false)
    }

    func writeDocument(named name: String) throws -> URL {
        let url = documentsURL.appendingPathComponent("\(name).fbdoc")
        try Data(name.utf8).write(to: url)
        return url
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
