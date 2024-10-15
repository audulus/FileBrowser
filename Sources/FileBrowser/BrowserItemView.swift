//  Copyright © Audulus LLC. All rights reserved.

import SwiftUI

struct BrowserItemView: View {

    var model: FileBrowserModel
    let item: URL
    var itemSelected: (URL) -> Void
    var thumbnailName: String?
    @State var renaming = false
    @State var newName = ""

    func tap() {
        if model.selecting {
            if selected {
                model.selected.remove(item)
            } else {
                model.selected.insert(item)
            }
        } else {
            itemSelected(item)
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
        .onAppear {
            newName = name
        }
    }

}

