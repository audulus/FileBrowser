//  Copyright © 2024 Audulus LLC. All rights reserved.

import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)

public struct FileBrowserView: View {

    let utType: UTType
    let pathExtension: String
    let newDocumentURL: URL
    let documentSelected: (URL) -> Void
    let thumbnailName: String?
    let exclude: [String]
    let showSettings: () -> Void
    let doImport: () -> Void
    let showIntro: () -> Void

    @State private var model: FileBrowserModel?
    @State private var showDeleteAlert = false

    public init(utType: UTType,
                pathExtension: String,
                newDocumentURL: URL,
                documentSelected: @escaping (URL) -> Void,
                thumbnailName: String? = nil,
                exclude: [String] = [],
                showSettings: @escaping () -> Void,
                doImport: @escaping () -> Void,
                showIntro: @escaping () -> Void) {
        self.utType = utType
        self.pathExtension = pathExtension
        self.newDocumentURL = newDocumentURL
        self.documentSelected = documentSelected
        self.thumbnailName = thumbnailName
        self.exclude = exclude
        self.showSettings = showSettings
        self.doImport = doImport
        self.showIntro = showIntro
    }

    let columns = [
        GridItem(.adaptive(minimum: 250))
    ]

    func newDocument() {
        do {
            try model?.newDocument()
        } catch {
            print("⚠️ error creating new document: \(error)")
        }
    }

    func deleteSelected() {
        do {
            try model?.deleteSelected()
        } catch {
            print("⚠️ error deleting selected items: \(error)")
        }
    }

    func duplicateSelected() {
        do {
            try model?.duplicateSelected()
        } catch {
            print("⚠️ error duplicating selected items: \(error)")
        }
    }

    func deactivateSelection() {
        model?.selecting = false
        model?.selected = .init()
    }

    func openDocuments() {
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {

            let path = documentsDirectory.absoluteString.replacingOccurrences(of: "file://", with: "shareddocuments://")
            let url = URL(string: path)!

            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    public var body: some View {
        ZStack(alignment: .top) {

            if let model {
                ScrollView {
                    LazyVGrid(columns: columns) {
                        ForEach(model.urls, id: \.self) { url in
                            BrowserItemView(model: model,
                                            item: url,
                                            itemSelected: documentSelected,
                                            thumbnailName: thumbnailName)
                            .padding(40)
                        }
                    }
                    .safeAreaPadding(EdgeInsets(top: 80, leading: 0, bottom: 0, trailing: 0))

                    HStack {
                        Button(action: showIntro) {
                            Text("Show Intro")
                                .font(.caption)
                                .padding()
                                .background(
                                    .thinMaterial,
                                    in: RoundedRectangle(cornerRadius: 10))
                        }

                        Button(action: openDocuments) {
                            Text("Open Documents Folder")
                                .font(.caption)
                                .padding()
                                .background(
                                    .thinMaterial,
                                    in: RoundedRectangle(cornerRadius: 10))
                        }

                        Button(action: showSettings) {
                            Text("Settings")
                                .font(.caption)
                                .padding()
                                .background(
                                    .thinMaterial,
                                    in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                HStack(spacing: 20) {
                    if let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String {
                        Text(appName)
                            .font(.title)
                    }
                    Spacer()
                    if model.selecting {
                        Button(action: duplicateSelected) {
                            Text("Duplicate")
                        }
                        Button(action: { showDeleteAlert = true }) {
                            Text("Delete")
                        }
                        CustomToolbarButton(image: Image(systemName: "multiply"), action: deactivateSelection)
                    } else {
                        Button(action: { model.selecting = true }) {
                            Text("Select")
                        }
                        Button(action: doImport) {
                            Text("Import")
                        }
                        CustomToolbarButton(image: Image(systemName: "plus"), action: newDocument)
                    }
                }
                .padding()
                .background(BlurView(style: .dark))

            }
        }
        .background(Color("BrowserBackground", bundle: Bundle.module))
        .foregroundStyle(.white)
        .alert("Are you sure?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { deleteSelected() }
            Button("Cancel", role: .cancel) { }
        }
        .onAppear {
            model = FileBrowserModel(utType: utType,
                                     pathExtension: pathExtension,
                                     newDocumentURL: newDocumentURL,
                                     exclude: exclude)
        }
    }
}

struct BlurView: UIViewRepresentable {

    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        let blurEffect = UIBlurEffect(style: style)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(blurView, at: 0)
        NSLayoutConstraint.activate([
            blurView.heightAnchor.constraint(equalTo: view.heightAnchor),
            blurView.widthAnchor.constraint(equalTo: view.widthAnchor),
        ])
        return view
    }

    func updateUIView(_ uiView: UIView,
                      context: Context) {

    }

}

#Preview {
    FileBrowserView(utType: UTType.png,
                    pathExtension: "png",
                    newDocumentURL: URL(fileURLWithPath: "/tmp/test.png"),
                    documentSelected: { _ in},
                    showSettings: {},
                    doImport: {},
                    showIntro: {})
}

#endif
