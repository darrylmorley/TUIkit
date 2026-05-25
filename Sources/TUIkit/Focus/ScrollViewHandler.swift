//  🖥️ TUIKit — Terminal UI Kit for Swift
//  ScrollViewHandler.swift
//
//  License: MIT

import TUIkitCore

@MainActor
final class ScrollViewHandler: @preconcurrency Focusable {
    let focusID: String
    var scrollOffset: Int = 0
    var viewportHeight: Int
    var contentHeight: Int = 0

    init(focusID: String, viewportHeight: Int) {
        self.focusID = focusID
        self.viewportHeight = viewportHeight
    }

    var hasContentAbove: Bool { scrollOffset > 0 }
    var hasContentBelow: Bool { scrollOffset + viewportHeight < contentHeight }

    func clampOffset() {
        let maxOffset = max(0, contentHeight - viewportHeight)
        scrollOffset = max(0, min(scrollOffset, maxOffset))
    }

    func handleKeyEvent(_ event: KeyEvent) -> Bool {
        switch event.key {
        case .up:
            scrollOffset -= 1
            clampOffset()
            AppState.shared.setNeedsRender()
            return true
        case .down:
            scrollOffset += 1
            clampOffset()
            AppState.shared.setNeedsRender()
            return true
        case .pageUp:
            scrollOffset -= max(1, viewportHeight - 1)
            clampOffset()
            AppState.shared.setNeedsRender()
            return true
        case .pageDown:
            scrollOffset += max(1, viewportHeight - 1)
            clampOffset()
            AppState.shared.setNeedsRender()
            return true
        case .home:
            scrollOffset = 0
            AppState.shared.setNeedsRender()
            return true
        case .end:
            scrollOffset = max(0, contentHeight - viewportHeight)
            AppState.shared.setNeedsRender()
            return true
        default:
            return false
        }
    }
}
