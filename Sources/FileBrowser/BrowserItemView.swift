//  Copyright © Audulus LLC. All rights reserved.

import SwiftUI

struct BrowserItemView: View {

    var model: FileBrowserModel
    let item: URL
    var itemSelected: (URL) -> Void
    var thumbnailName: String?
    @State var renaming = false
    @State var newName = ""

    func openItem() {
        // Call itemSelected after a brief delay to let the animation play
        model.openURL = item
        Task {
            try? await Task.sleep(for: .seconds(1))
            itemSelected(item)
        }
    }

    func tap() {
        if model.selecting {
            if selected {
                model.selected.remove(item)
            } else {
                model.selected.insert(item)
            }
        } else {
            openItem()
        }
    }

    var selected: Bool {
        model.selected.contains(item)
    }

    func submit() {
        do {
            try model.rename(url: item, to: newName)
        } catch {
            print("error renaming: \(error)")
        }
    }

    var name: String {
        item.deletingPathExtension().lastPathComponent
    }
    
    var enlarge: Bool {
        model.openURL == item
    }

    var body: some View {
        @Bindable var model = model
        VStack {
            ZStack(alignment: .bottomLeading) {
                ThumbnailView(url: item, thumbnailName: thumbnailName)
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
    }

}

