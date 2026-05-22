//  Copyright © Audulus LLC. All rights reserved.

import SwiftUI
#if os(iOS)
import UniformTypeIdentifiers
#endif

struct BrowserItemView: View {

    var model: FileBrowserModel
    let item: FileBrowserItem
    var itemSelected: (URL) -> Void
    var thumbnailName: String?
    @State var renaming = false
    @State var newName = ""

    func openItem() {
        guard item.isDocument else {
            model.enterGroup(item.url)
            return
        }

        // Call itemSelected after a brief delay to let the animation play
        model.openURL = item.url
        Task {
            try? await Task.sleep(for: .seconds(1))
            itemSelected(item.url)
        }
    }

    func tap() {
        if model.selecting {
            if selected {
                model.selected.remove(item.url)
            } else {
                model.selected.insert(item.url)
            }
        } else {
            openItem()
        }
    }

    var selected: Bool {
        model.selected.contains(item.url)
    }

    func submit() {
        do {
            try model.rename(item: item, to: newName)
        } catch {
            print("error renaming: \(error)")
        }
    }

    var name: String {
        switch item.kind {
        case .document:
            item.url.deletingPathExtension().lastPathComponent
        case .group:
            item.url.lastPathComponent
        }
    }
    
    var enlarge: Bool {
        model.openURL == item.url
    }

    #if os(iOS)
    func dropDocument(with providers: [NSItemProvider]) -> Bool {
        for provider in providers where provider.canLoadObject(ofClass: NSString.self) {
            provider.loadObject(ofClass: NSString.self) { value, _ in
                guard let string = value as? String, let url = URL(string: string) else {
                    return
                }

                DispatchQueue.main.async {
                    do {
                        switch item.kind {
                        case .document:
                            try model.group(document: url, with: item.url)
                        case .group:
                            try model.move(document: url, intoGroup: item.url)
                        }
                    } catch {
                        print("error handling dropped document: \(error)")
                    }
                }
            }

            return true
        }

        return false
    }
    #endif

    var body: some View {
        @Bindable var model = model
        VStack {
            ZStack(alignment: .bottomLeading) {
                thumbnail
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 0)
                    .onTapGesture {
                        tap()
                    }
                if model.selecting {
                    Image(systemName: selected ? "checkmark.circle.fill" : "checkmark.circle")
                        .padding()
                }
            }

            HStack {
                Button(action: { renaming = true }) {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .alert("Rename", isPresented: $renaming) {
                    TextField("New name", text: $newName)
                    Button("OK", action: submit)
                    Button("Cancel", action: { renaming = false})
                }
                Spacer()
            }.padding(.top)
        }
        .scaleEffect(enlarge ? 1.2 : 1.0)
        .opacity(enlarge ? 0.8 : 1.0)
        .animation(.easeOut, value: enlarge)
        .onAppear {
            newName = name
        }
        #if os(iOS)
        .documentGroupingDragDrop(item: item, isEnabled: !model.selecting, dropDocument: dropDocument(with:))
        #endif
    }

    @ViewBuilder
    var thumbnail: some View {
        switch item.kind {
        case .document:
            ThumbnailView(url: item.url, thumbnailName: thumbnailName)
        case .group:
            GroupThumbnailView(urls: item.thumbnailURLs, thumbnailName: thumbnailName)
        }
    }

}

#if os(iOS)
private extension View {
    @ViewBuilder
    func documentGroupingDragDrop(item: FileBrowserItem,
                                  isEnabled: Bool,
                                  dropDocument: @escaping ([NSItemProvider]) -> Bool) -> some View {
        if isEnabled {
            switch item.kind {
            case .document:
                self
                    .onDrag {
                        NSItemProvider(object: item.url.absoluteString as NSString)
                    }
                    .onDrop(of: [UTType.plainText], isTargeted: nil, perform: dropDocument)
            case .group:
                self
                    .onDrop(of: [UTType.plainText], isTargeted: nil, perform: dropDocument)
            }
        } else {
            self
        }
    }
}
#endif
