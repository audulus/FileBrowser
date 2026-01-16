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
    let closingURL: URL?

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
                showIntro: @escaping () -> Void,
                closingURL: URL?) {
        self.utType = utType
        self.pathExtension = pathExtension
        self.newDocumentURL = newDocumentURL
        self.documentSelected = documentSelected
        self.thumbnailName = thumbnailName
        self.exclude = exclude
        self.showSettings = showSettings
        self.doImport = doImport
        self.showIntro = showIntro
        self.closingURL = closingURL
    }

    let columns = [
        GridItem(.adaptive(minimum: 250))
    ]

    func newDocument(proxy: ScrollViewProxy) {
        
        guard let model else { return }
        
        do {
            let url = try model.newDocument()
            let filename = url.lastPathComponent
            
            Task {
                
                // Wait for reload of documents.
                try await Task.sleep(for: .milliseconds(50))
                
                // Look up URL with the same filename (URLs are a different format
                // than what is returned by newDocument.
                if let matchingURL = model.urls.first(where: { $0.lastPathComponent == filename }) {
                    withAnimation {
                        proxy.scrollTo(matchingURL)
                    }
                    
                    try await Task.sleep(for: .seconds(1))
                    
                    // Trigger the opening animation by setting urlToOpen
                    model.urlToOpen = matchingURL
                }
            }
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
    
    public var documentsScrollView: some View {
        ScrollView {
            
            if let model {
                
                LazyVGrid(columns: columns) {
                    ForEach(model.urls, id: \.self) { url in
                        BrowserItemView(model: model,
                                        item: url,
                                        itemSelected: documentSelected,
                                        thumbnailName: thumbnailName)
                        .padding(40)
                        .id(url)
                    }
                }
                .safeAreaPadding(EdgeInsets(top: 80, leading: 0, bottom: 0, trailing: 0))
                
            }

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
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .top) {
                
                documentsScrollView
                
                if let model {
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
                            CustomToolbarButton(image: Image(systemName: "plus"), action: { newDocument(proxy: proxy)})
                        }
                    }
                    .padding()
                    .background(BlurView(style: .dark))
                }
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
            model?.urlToClose = closingURL
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
                    showIntro: {},
                    closingURL: nil)
}

#endif
