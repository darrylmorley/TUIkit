//  🖥️ TUIKit — Terminal UI Kit for Swift
//  WideCharacterLayoutTests.swift
//
//  Created by LAYERED.work
//  License: MIT

import Testing

@testable import TUIkit

/// Layout must be measured in terminal columns, not `String.count`. A CJK
/// character (zh, ja, ko) takes two columns; a combining mark takes none.
@MainActor
@Suite("Wide character layout")
struct WideCharacterLayoutTests {

    private func context(width: Int) -> RenderContext {
        RenderContext(availableWidth: width, availableHeight: 24, tuiContext: TUIContext())
    }

    private func render<V: View>(_ view: V, width: Int) -> [String] {
        renderToBuffer(view, context: context(width: width)).lines
    }

    // MARK: - Display width helper

    @Test("Character width: CJK is 2, combining clusters take the base width")
    func characterWidths() {
        #expect(Character("端").terminalWidth == 2)
        #expect(Character("가").terminalWidth == 2)
        #expect(Character("A").terminalWidth == 1)
        // e + combining acute accent (one grapheme, two scalars): one column.
        #expect(Character("e\u{0301}").terminalWidth == 1)
        // Devanagari ka + anusvara (a nonspacing mark): one column.
        #expect(Character("\u{0915}\u{0902}").terminalWidth == 1)
        // Arabic letter mark (format character, used in Persian text): none.
        #expect(Character("\u{061C}").terminalWidth == 0)
        // Emoji sequences stay two columns.
        #expect(Character("👍🏽").terminalWidth == 2)
        #expect(Character("🇬🇧").terminalWidth == 2)
        #expect(Character("1\u{FE0F}\u{20E3}").terminalWidth == 2)
        #expect(Character("👨‍👩‍👧").terminalWidth == 2)
        // c a f é (one column with its accent), a space, two wide characters.
        #expect("cafe\u{0301} 端口".strippedLength == 9)
    }

    // MARK: - Text

    @Test("Text measures CJK by display width")
    func textMeasuresDisplayWidth() {
        let size = Text("端口 ports").sizeThatFits(proposal: .unspecified, context: context(width: 80))
        #expect(size.width == 10)
    }

    @Test("Text wraps CJK words by display width and never past the edge")
    func textWrapsCJKWithSpaces() {
        let lines = render(Text("电源 适配器 带有 一个 很长 的 名称"), width: 10).map(\.stripped)
        #expect(lines.count > 1)
        for line in lines {
            #expect(line.strippedLength <= 10, "line \"\(line)\" is \(line.strippedLength) columns, limit 10")
        }
        // CJK may break between characters as well as at spaces, so compare
        // the characters, not the spacing.
        #expect(lines.joined().filter { $0 != " " } == "电源适配器带有一个很长的名称")
    }

    @Test("Text breaks a run of CJK with no spaces between characters")
    func textBreaksCJKRun() {
        let sentence = "每个端口的实时功率系统总计显示在顶部"
        let lines = render(Text(sentence), width: 9).map(\.stripped)
        #expect(lines.count > 1)
        for line in lines {
            // Width 9 holds four wide characters; a fifth would straddle the edge.
            #expect(line.strippedLength <= 9, "line \"\(line)\" is \(line.strippedLength) columns, limit 9")
        }
        #expect(lines.joined() == sentence)
    }

    @Test("Text wrapping of plain ASCII is unchanged")
    func textASCIIWrapUnchanged() {
        let lines = render(Text("the quick brown fox jumps"), width: 10).map(\.stripped)
        #expect(lines == ["the quick", "brown fox", "jumps"])
    }

    // MARK: - Panel

    @Test("Panel title border matches the body with a CJK title")
    func panelCJKTitle() {
        let lines = render(Panel("电源监视器") { Text("x") }, width: 40)
        let widths = Set(lines.map(\.strippedLength))
        #expect(widths.count == 1, "rows have widths \(widths.sorted()): \(lines.map(\.stripped))")
    }

    @Test("Panel sizes itself to a CJK title wider than its body")
    func panelCJKTitleSizesPanel() {
        let lines = render(Panel("端口端口端口端口") { Text("x") }, width: 60)
        let widths = Set(lines.map(\.strippedLength))
        #expect(widths.count == 1, "rows have widths \(widths.sorted()): \(lines.map(\.stripped))")
        // " 端口端口端口端口 " (18 columns) plus the corner and dash on the left
        // and the corner on the right needs at least 21 columns.
        #expect((widths.first ?? 0) >= 21)
    }

    // MARK: - Padded column

    @Test("Menu pads CJK items to one column width")
    func menuCJKItems() {
        // "协商诊断" is four characters but eight columns, the same width as
        // "abcdefgh", so both menus must come out the same size.
        let cjk = render(Menu(items: [MenuItem(label: "Power"), MenuItem(label: "协商诊断")]), width: 40)
        let ascii = render(Menu(items: [MenuItem(label: "Power"), MenuItem(label: "abcdefgh")]), width: 40)
        let widths = Set(cjk.map(\.strippedLength))
        #expect(widths.count == 1, "rows have widths \(widths.sorted()): \(cjk.map(\.stripped))")
        #expect(cjk.map(\.strippedLength) == ascii.map(\.strippedLength),
                "CJK menu \(cjk.map(\.stripped)) vs ASCII menu \(ascii.map(\.stripped))")
    }

    @Test("Dimmed CJK text keeps its width")
    func dimmedCJK() {
        let plain = render(Text("端口端口"), width: 20)
        let dimmed = render(Text("端口端口").dimmed(), width: 20)
        #expect(dimmed.map(\.strippedLength) == plain.map(\.strippedLength))
    }

    // MARK: - Notification wrap

    @Test("Notification text wraps CJK by display width")
    func notificationWrapCJK() {
        let lines = NotificationTiming.wordWrap("电源 适配器 带有 一个 很长 的 名称", maxWidth: 10)
        for line in lines {
            #expect(line.strippedLength <= 10, "line \"\(line)\" is \(line.strippedLength) columns, limit 10")
        }
    }
}
