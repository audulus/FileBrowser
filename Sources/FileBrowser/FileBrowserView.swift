//  Copyright © 2024 Audulus LLC. All rights reserved.

import SwiftUI

#if os(iOS)

struct FileBrowserView: View {

    @State var model = FileBrowserModel()
    @State var isImporting = false
    @Binding var editing: URL?
    @State var showDeleteAlert = false

    let columns = [
        GridItem(.adaptive(minimum: 250))
    ]

    func newDocument() {
        do {
            try model.newDocument()
        } catch {
            print("⚠️ error creating new document: \(error)")
        }
    }

    func select(url: URL) {
        editing = url
    }

    func deleteSelected() {
        do {
            try model.deleteSelected()
        } catch {
            print("⚠️ error deleting selected items: \(error)")
        }
    }

    func duplicateSelected() {
        do {
            try model.duplicateSelected()
        } catch {
            print("⚠️ error duplicating selected items: \(error)")
        }
    }

    func deactivateSelection() {
        model.selecting = false
        model.selected = .init()
    }

    var body: some View {
        ZStack(alignment: .top) {

            ScrollView {
                LazyVGrid(columns: columns) {
                    ForEach(model.urls, id: \.self) { url in
                        BrowserItemView(model: model,
                                        item: url,
                                        itemSelected: select)
                            .padding(40)
                    }
                }
                .safeAreaPadding(EdgeInsets(top: 80, leading: 0, bottom: 0, trailing: 0))
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
        .background(Color("BrowserBackground"))
        .foregroundStyle(.white)
        .alert("Are you sure?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { deleteSelected() }
            Button("Cancel", role: .cancel) { }
        }
        .fileImporter(isPresented: $isImporting,
                      allowedContentTypes: [model.utType]) { result in
            switch result {
            case .success(let url):
                model.importFile(at: url)
            case .failure(let error):
                // handle error
                print(error)
            }
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
    FileBrowserView(editing: .constant(nil))
}

#endif