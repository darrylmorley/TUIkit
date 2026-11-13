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

    @Test("Character width: CJK is 2, combining marks add nothing")
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

// MARK: - Exact columns

/// Columns of plain text, counted independently of `terminalWidth`: every
/// character is one column, plus one more for each CJK character. Only used
/// on strings made of ASCII, box drawing and CJK.
private func referenceColumns(_ line: String) -> Int {
    let plain = line.replacingOccurrences(of: "\u{1B}\\[[0-9;]*[A-Za-z]", with: "", options: .regularExpression)
    let wide = plain.unicodeScalars.filter { scalar in
        let value = scalar.value
        return (0x3040...0x30FF).contains(value) || (0x4E00...0x9FFF).contains(value)
            || (0xAC00...0xD7A3).contains(value) || (0xFF01...0xFF60).contains(value)
    }.count
    return plain.count + wide
}

/// Each test renders a CJK view and an ASCII twin whose text has the same
/// display width, then checks that every CJK row takes exactly as many
/// columns as the twin's rows. The twin's columns are its character count
/// (all narrow), so nothing here leans on the width helper under test.
@MainActor
@Suite("Wide character layout, exact columns")
struct WideCharacterExactColumnTests {

    private func context(width: Int) -> RenderContext {
        RenderContext(availableWidth: width, availableHeight: 24, tuiContext: TUIContext())
    }

    private func render<V: View>(_ view: V, width: Int = 40) -> [String] {
        renderToBuffer(view, context: context(width: width)).lines
    }

    /// The twin's rows, all one width; returns that width.
    private func twinWidth(_ lines: [String]) -> Int {
        let widths = Set(lines.map { referenceColumns($0) })
        #expect(widths.count == 1, "ASCII twin is ragged: \(lines.map(\.stripped))")
        return widths.first ?? -1
    }

    private func expectColumns(_ lines: [String], equal width: Int, _ what: String) {
        #expect(!lines.isEmpty)
        for line in lines {
            #expect(referenceColumns(line) == width,
                    "\(what): \"\(line.stripped)\" is \(referenceColumns(line)) columns, expected \(width)")
        }
    }

    @Test("Panel with a CJK title")
    func panel() {
        let width = twinWidth(render(Panel("abcdefghij") { Text("x") }))
        expectColumns(render(Panel("电源监视器") { Text("x") }), equal: width, "Panel")
    }

    @Test("Menu with a CJK item")
    func menu() {
        let width = twinWidth(render(Menu(items: [MenuItem(label: "Power"), MenuItem(label: "abcdefgh")])))
        expectColumns(render(Menu(items: [MenuItem(label: "Power"), MenuItem(label: "协商诊断")])), equal: width, "Menu")
    }

    @Test("Dimmed CJK text")
    func dimmed() {
        let width = twinWidth(render(Text("abcd").dimmed(), width: 20))
        expectColumns(render(Text("端口").dimmed(), width: 20), equal: width, "Dimmed")
    }

    @Test("List row with a CJK badge")
    func listBadge() {
        struct Item: Identifiable { let id: String }
        func list(_ badge: String) -> some View {
            List(selection: Binding<String?>(get: { nil }, set: { _ in })) {
                ForEach([Item(id: "a")]) { _ in Text("row").badge(badge) }
            }
        }
        let twin = render(list("abcd"), width: 30)
        let cjk = render(list("端口"), width: 30)
        #expect(cjk.contains { $0.stripped.contains("端口") }, "badge not rendered: \(cjk.map(\.stripped))")
        #expect(twin.count == cjk.count)
        for (a, b) in zip(twin, cjk) {
            #expect(referenceColumns(b) == referenceColumns(a),
                    "badge row \"\(b.stripped)\" is \(referenceColumns(b)) columns, twin \"\(a.stripped)\" is \(referenceColumns(a))")
        }
    }

    @Test("Scroll indicator is centred in its width")
    func scrollIndicator() {
        let line = renderScrollIndicator(direction: .up, width: 30, palette: EnvironmentValues().palette).stripped
        // "▲ more above " is 13 columns; (30 - 13) / 2 = 8 spaces before it.
        #expect(line == String(repeating: " ", count: 8) + "▲ more above ")
    }

    @Test("Unfocused TextField with a CJK prompt")
    func textFieldPrompt() {
        // The first field takes focus, so the second one is unfocused and
        // shows its prompt.
        func fields(_ prompt: String) -> some View {
            VStack {
                TextField("First", text: Binding(get: { "" }, set: { _ in }))
                TextField("Name", text: Binding(get: { "" }, set: { _ in }), prompt: Text(prompt))
            }
        }
        let twin = render(fields("abcdefghij"), width: 30)
        let cjk = render(fields("请输入名称"), width: 30)
        let promptRow = cjk.firstIndex { $0.stripped.contains("请输入名称") }
        #expect(promptRow != nil, "prompt not rendered: \(cjk.map(\.stripped))")
        if let row = promptRow, row < twin.count {
            #expect(referenceColumns(cjk[row]) == referenceColumns(twin[row]),
                    "prompt row \"\(cjk[row].stripped)\" is \(referenceColumns(cjk[row])) columns, twin \(referenceColumns(twin[row]))")
        }
    }

    // MARK: Character widths (Kuhn/glibc wcwidth rule)

    @Test("Cluster widths: sums of code points, emoji sequences 2")
    func clusterWidths() {
        #expect(Character("\u{0915}\u{094D}\u{0937}").terminalWidth == 2)   // क्ष: ka, virama, ssa
        #expect(Character("\u{0E01}\u{0E33}").terminalWidth == 2)           // Thai กำ (SARA AM)
        #expect(Character("\u{FF76}\u{FF9E}").terminalWidth == 2)           // halfwidth ｶﾞ
        #expect(Character("e\u{0301}").terminalWidth == 1)                  // é, decomposed
        #expect(Character("\u{0915}\u{093F}").terminalWidth == 2)           // कि: vowel sign is Mc = 1
        #expect(Character("👨‍👩‍👧").terminalWidth == 2)                         // ZWJ family
        #expect(Character("🏳️‍🌈").terminalWidth == 2)                          // text-default base + ZWJ
        #expect(Character("\u{1100}\u{1161}\u{11A8}").terminalWidth == 2)   // hangul L+V+T jamo
        #expect(Character("\u{0600}1").terminalWidth == 1)                  // prepended mark + digit
    }

    // MARK: Wrapping edge cases (through notifications' wrapper)

    @Test("A wide character at width 1 goes on its own line")
    func wideAtWidthOne() {
        #expect(NotificationTiming.wordWrap("端口", maxWidth: 1) == ["端", "口"])
    }

    @Test("A colour code travels with the text after a wrap")
    func escapeTravels() {
        let lines = NotificationTiming.wordWrap("端\u{1B}[31m口", maxWidth: 2)
        #expect(lines == ["端", "\u{1B}[31m口"])
    }

    @Test("An emoji stuck to a word does not split it when it fits")
    func emojiStaysWithWord() {
        #expect(NotificationTiming.wordWrap("hello👋 there", maxWidth: 7) == ["hello👋", "there"])
    }

    /// A Devanagari conjunct cluster can measure more than one cell (ट्रो is
    /// 3), but it is narrow letters inside a word, not a break point.
    @Test("A Hindi word with conjuncts is not split")
    func hindiWordNotSplit() {
        #expect(NotificationTiming.wordWrap("कोई Thunderbolt कंट्रोलर नहीं", maxWidth: 20)
                == ["कोई Thunderbolt", "कंट्रोलर नहीं"])
    }

    @Test("A line never starts with closing CJK punctuation")
    func closingPunctuation() {
        #expect(NotificationTiming.wordWrap("你好。", maxWidth: 4) == ["你", "好。"])
    }
}
