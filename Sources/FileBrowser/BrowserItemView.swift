//  Copyright © Audulus LLC. All rights reserved.

import SwiftUI

struct BrowserItemView: View {

    var model: FileBrowserModel
    let item: URL
    var itemSelected: (URL) -> Void
    var thumbnailName: String?
    @State var renaming = false
    @State var newName = ""
    @State var isOpening = false

    func tap() {
        if model.selecting {
            if selected {
                model.selected.remove(item)
            } else {
                model.selected.insert(item)
            }
        } else {
            // Animate an increase in size to show it opening
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isOpening = true
            }
            
            // Call itemSelected after a brief delay to let the animation play
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                itemSelected(item)
            }
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
        .scaleEffect(isOpening ? 1.2 : 1.0)
        .opacity(isOpening ? 0.8 : 1.0)
        .onAppear {
            newName = name
        }
    }

}

