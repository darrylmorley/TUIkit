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

        // Render content at unlimited height to measure natural size.
        var contentContext = context
        contentContext.availableHeight = max(availableHeight, 10_000)
        let fullBuffer = TUIkitView.renderToBuffer(content, context: contentContext)

        // If content fits, return it directly.
        if fullBuffer.height <= availableHeight {
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

        // Update handler with current dimensions.
        handler.contentHeight = fullBuffer.height
        handler.viewportHeight = max(1, availableHeight - 2)
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
        let end = min(start + handler.viewportHeight, fullBuffer.height)
        outputLines.append(contentsOf: fullBuffer.lines[start..<end])

        if handler.hasContentBelow {
            outputLines.append(renderScrollIndicator(
                direction: .down, width: fullBuffer.width, palette: palette
            ))
        }

        return FrameBuffer(lines: outputLines)
    }
}
