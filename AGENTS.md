# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## What this is

FileBrowser is a Swift Package (`swift-tools-version: 6.0`, iOS 17+) providing a single
SwiftUI library: a document browser modeled on Procreate's, meant as a replacement for
`DocumentGroup` / `UIDocumentBrowserViewController`. It is consumed by host apps that own
their own document format; the package itself is format-agnostic.

## Build & test

```sh
swift build                                    # builds for macOS host by default
swift test                                     # runs FileBrowserTests
swift test --filter FileBrowserTests/example   # run a single test
```

Note: the package targets iOS but most code is gated behind `#if os(iOS)`, so a plain
`swift build` on macOS compiles only the cross-platform pieces. To compile/test the iOS
surface, build through Xcode against an iOS Simulator destination
(`xcodebuild -scheme FileBrowser -destination 'platform=iOS Simulator,name=iPhone 15'`).

Tests are written with Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest.

## Architecture

The library exposes one public view, `FileBrowserView`, plus the public `FileManager`
extension. Host apps embed `FileBrowserView` and pass closures for actions the package
deliberately does not own (opening a document, showing settings/intro, importing).

- **`FileBrowserModel`** (`@Observable`, `@unchecked Sendable`) — the single source of
  truth. Owns the document list, selection state, and the "selecting" mode. It operates
  exclusively on the app's **Documents directory**: `scan()` enumerates it recursively,
  keeping only files whose `pathExtension` matches and skipping any directory named in
  `exclude`. A `DispatchSource` file-system watcher (`startMonitoring`) re-runs `scan()`
  on the main queue whenever the directory changes. The `@unchecked Sendable` and the
  `DispatchQueue.main.async` (rather than `Task`) inside the event handler are deliberate
  workarounds for a Swift 6 `DispatchSource` crash — see the linked forum thread in the
  source before changing them.

- **`FileBrowserView`** — owns layout: a `LazyVGrid` of `BrowserItemView`s plus a blurred
  top toolbar that swaps between normal mode (Select / Import / New) and selecting mode
  (Duplicate / Delete / dismiss). The model is created lazily in `onAppear`, so it is
  optional throughout the view.

- **`model.openURL`** is a cross-component animation channel, not navigation state.
  Setting it makes the matching `BrowserItemView` scale/fade (the "opening" animation);
  the actual open is the host's `documentSelected` closure, fired ~1s later via
  `Task.sleep`. New-document creation chains several timed sleeps: create file → wait for
  the watcher to re-scan → scroll to it → trigger `openURL` → call `documentSelected`.

- **Thumbnails** — `ThumbnailView` + `ThumbnailLoader` load asynchronously. If a host
  passes `thumbnailName`, a PNG of that name is read from *inside* the document
  (documents are treated as package directories); otherwise `QLThumbnailGenerator`
  produces one. Loading happens on a detached task, cancelled on reuse.

## Conventions

- New SwiftUI/UIKit-specific code should be wrapped in `#if os(iOS)`; `ThumbnailLoader`
  and `ThumbnailView` additionally carry `#else` branches for macOS (`NSImage`).
- Bundled assets (colors in `Media.xcassets`) are resolved with `Bundle.module`.
- Filename collisions are resolved by `getFileURL(base:)`, which appends ` 1`, ` 2`, …
  until a free name is found — reuse it for any new file-creating code.
