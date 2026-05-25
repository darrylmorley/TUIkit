//  🖥️ TUIKit — Terminal UI Kit for Swift
//  ScrollView.swift
//
//  License: MIT

import TUIkitCore

/// A scrollable container that clips content to the available height and
/// allows the user to scroll with arrow keys, Page Up/Down, and Home/End.
///
/// When content fits within the available height, `ScrollView` renders
/// identically to its content with no overhead. When content overflows,
/// scroll indicators appear at the top and/or bottom.
///
/// ```swift
/// ScrollView {
///     VStack {
///         for item in items {
///             Text(item.name)
///         }
///     }
/// }
/// ```
public struct ScrollView<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: Never {
        fatalError("ScrollView renders directly via Renderable")
    }
}

extension ScrollView: Renderable {
    public func renderToBuffer(context: RenderContext) -> FrameBuffer {
        let availableHeight = context.availableHeight

        // Render content with enough room to see its natural size.
        // Don't use a huge value (like 10_000) because layout containers
        // may pad to fill available height, inflating the buffer.
        var contentContext = context
        contentContext.availableHeight = max(availableHeight, availableHeight * 4)
        let fullBuffer = TUIkitView.renderToBuffer(content, context: contentContext)

        // Trim trailing empty lines that layout padding may have added.
        let trimmedHeight = Self.trimmedHeight(of: fullBuffer)

        // If content fits, return it directly.
        if trimmedHeight <= availableHeight {
            return fullBuffer
        }

        // Persist scroll state across render passes.
        let stateStorage = context.environment.stateStorage!
        let focusID = FocusRegistration.persistFocusID(
            context: context,
            explicitFocusID: nil,
            defaultPrefix: "scrollview",
            propertyIndex: 1
        )

        let handlerKey = StateStorage.StateKey(identity: context.identity, propertyIndex: 0)
        let handlerBox: StateBox<ScrollViewHandler> = stateStorage.storage(
            for: handlerKey,
            default: ScrollViewHandler(focusID: focusID, viewportHeight: availableHeight)
        )
        let handler = handlerBox.value

        // Reserve 1 line each for scroll indicators (shown conditionally).
        let indicatorLines = 2
        let viewport = max(1, availableHeight - indicatorLines)

        handler.contentHeight = trimmedHeight
        handler.viewportHeight = viewport
        handler.clampOffset()

        // Register for keyboard focus.
        FocusRegistration.register(context: context, handler: handler)

        let palette = context.environment.palette
        var outputLines: [String] = []

        if handler.hasContentAbove {
            outputLines.append(renderScrollIndicator(
                direction: .up, width: fullBuffer.width, palette: palette
            ))
        }

        let start = handler.scrollOffset
        let end = min(start + viewport, trimmedHeight)
        outputLines.append(contentsOf: fullBuffer.lines[start..<end])

        if handler.hasContentBelow {
            outputLines.append(renderScrollIndicator(
                direction: .down, width: fullBuffer.width, palette: palette
            ))
        }

        return FrameBuffer(lines: outputLines)
    }

    private static func trimmedHeight(of buffer: FrameBuffer) -> Int {
        var height = buffer.height
        while height > 0 {
            let line = buffer.lines[height - 1]
            if line.strippedLength > 0 { break }
            height -= 1
        }
        return height
    }
}
