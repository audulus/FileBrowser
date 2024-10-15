//  Copyright © 2024 Audulus LLC. All rights reserved.

import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)

public struct FileBrowserView: View {

    @Binding var editing: URL?
    let utType: UTType
    let pathExtension: String
    let newDocumentURL: URL
    let thumbnailName: String?
    let exclude: [String]

    @State private var model: FileBrowserModel?
    @State private var isImporting = false
    @State private var showDeleteAlert = false

    public init(editing: Binding<URL?>, utType: UTType, pathExtension: String, newDocumentURL: URL, thumbnailName: String? = nil, exclude: [String] = []) {
        _editing = editing
        self.utType = utType
        self.pathExtension = pathExtension
        self.newDocumentURL = newDocumentURL
        self.thumbnailName = thumbnailName
        self.exclude = exclude
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

    func select(url: URL) {
        editing = url
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
                                            itemSelected: select,
                                            thumbnailName: thumbnailName)
                            .padding(40)
                        }
                    }
                    .safeAreaPadding(EdgeInsets(top: 80, leading: 0, bottom: 0, trailing: 0))

                    Button("Open Documents Folder", action: { openDocuments() })
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .padding()
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
                        Button(action: { isImporting = true}) {
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
        .fileImporter(isPresented: $isImporting,
                      allowedContentTypes: [utType]) { result in
            switch result {
            case .success(let url):
                model?.importFile(at: url)
            case .failure(let error):
                // handle error
                print(error)
            }
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
    FileBrowserView(editing: .constant(nil),
                    utType: UTType.png,
                    pathExtension: "png",
                    newDocumentURL: URL(fileURLWithPath: "/tmp/test.png"))
}

#endif
