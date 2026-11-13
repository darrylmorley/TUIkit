//  🖥️ TUIKit — Terminal UI Kit for Swift
//  WordWrap.swift
//
//  Created by LAYERED.work
//  License: MIT

// MARK: - Word Wrapping

/// Word wrapping measured in terminal cells, shared by ``Text`` and
/// notifications.
///
/// Widths are display widths (`strippedLength`), so a two-cell character is
/// never placed across the right edge: it moves to the next line.
///
/// Break opportunities:
/// - at spaces, as before;
/// - before and after each CJK character (ideographs, kana, hangul,
///   fullwidth forms), because CJK text has no spaces between words;
/// - before and after an emoji, but only inside a space-free run that is
///   wider than the line on its own (`hello👋` stays together when it fits).
///
/// Closing punctuation (、。，．！？」』） and their relatives) is kept with
/// the character before it, so a line never starts with it; the pair moves
/// to the next line together. Other line-breaking rules (kinsoku for opening
/// brackets, small kana, prolonged sound marks) are not handled.
///
/// ANSI escape sequences inside a word travel with the text that follows
/// them, so a colour code never dangles at the end of a line.
///
/// Limits:
/// - A run of narrow characters longer than `maxWidth` (a long word or URL)
///   still goes on its own line without being split, as before.
/// - At `maxWidth` 1 a two-cell character still goes on a line of its own,
///   one cell wider than asked; there is nowhere narrower to put it.
enum WordWrap {
    /// Wraps `text` into lines no wider than `maxWidth` terminal cells
    /// (see the limits above).
    ///
    /// - Parameters:
    ///   - text: The text to wrap.
    ///   - maxWidth: Maximum terminal cells per line.
    /// - Returns: An array of wrapped lines (never empty).
    static func wrap(_ text: String, maxWidth: Int) -> [String] {
        guard maxWidth > 0 else { return [text] }

        let words = text.split(separator: " ", omittingEmptySubsequences: false)
        var lines: [String] = []
        var currentLine = ""
        var currentWidth = 0

        for word in words {
            for (index, piece) in pieces(of: word, maxWidth: maxWidth).enumerated() {
                // The first piece of a word follows a space; later pieces of
                // the same word (split at CJK or emoji boundaries) join directly.
                let joinerWidth = index == 0 ? 1 : 0
                let pieceWidth = piece.strippedLength
                if currentLine.isEmpty {
                    currentLine = piece
                    currentWidth = pieceWidth
                } else if currentWidth + joinerWidth + pieceWidth <= maxWidth {
                    currentLine += (index == 0 ? " " : "") + piece
                    currentWidth += joinerWidth + pieceWidth
                } else {
                    lines.append(currentLine)
                    currentLine = piece
                    currentWidth = pieceWidth
                }
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines.isEmpty ? [""] : lines
    }

    // MARK: - Pieces

    /// One visible character with any escape sequences that precede it.
    private struct Unit {
        var text: String
        let character: Character
    }

    /// Splits one space-free word at its break opportunities. A word with no
    /// break opportunity (or an empty word) comes back whole.
    private static func pieces(of word: Substring, maxWidth: Int) -> [String] {
        let wordString = String(word)
        // Every break opportunity inside a word is at a wide character, so a
        // word of narrow characters comes back whole (the common, fast case).
        guard word.contains(where: { $0.terminalWidth > 1 }) else { return [wordString] }
        let units = self.units(of: wordString)
        let hasCJK = units.contains { isCJK($0.character) }
        let breakAtEmoji = wordString.strippedLength > maxWidth
        guard hasCJK || breakAtEmoji else { return [wordString] }

        var result: [String] = []
        var run = ""
        for unit in units {
            let character = unit.character
            let isBreakable = isCJK(character) || (breakAtEmoji && character.terminalWidth > 1)
            if isClosingPunctuation(character) {
                // Keep with whatever came before, so no line starts with it.
                if !run.isEmpty {
                    run += unit.text
                } else if !result.isEmpty {
                    result[result.count - 1] += unit.text
                } else {
                    run = unit.text
                }
            } else if isBreakable {
                if !run.isEmpty {
                    result.append(run)
                    run = ""
                }
                // Start a new run so closing punctuation can still attach.
                run = unit.text
                result.append(run)
                run = ""
            } else {
                run += unit.text
            }
        }
        if !run.isEmpty { result.append(run) }
        return result
    }

    /// Breaks a word into visible characters, attaching each ANSI escape
    /// sequence to the character after it (or, at the end, to the last one).
    private static func units(of word: String) -> [Unit] {
        var units: [Unit] = []
        var pendingEscape = ""
        var index = word.startIndex
        while index < word.endIndex {
            let character = word[index]
            if character == "\u{1B}" {
                // ESC [ parameters final-letter
                var end = word.index(after: index)
                if end < word.endIndex && word[end] == "[" {
                    end = word.index(after: end)
                    while end < word.endIndex && (word[end].isNumber || word[end] == ";") {
                        end = word.index(after: end)
                    }
                    if end < word.endIndex && word[end].isLetter {
                        end = word.index(after: end)
                    }
                }
                pendingEscape += word[index..<end]
                index = end
                continue
            }
            units.append(Unit(text: pendingEscape + String(character), character: character))
            pendingEscape = ""
            index = word.index(after: index)
        }
        if !pendingEscape.isEmpty {
            if units.isEmpty {
                return [Unit(text: pendingEscape, character: " ")]
            }
            units[units.count - 1].text += pendingEscape
        }
        return units
    }

    /// CJK characters, between which a line may break.
    private static func isCJK(_ character: Character) -> Bool {
        guard character.terminalWidth > 1, let value = character.unicodeScalars.first?.value else { return false }
        // Wide, and not in the emoji and symbols planes.
        return !(0x1F000...0x1FBFF).contains(value)
    }

    /// Punctuation a line must not start with.
    private static func isClosingPunctuation(_ character: Character) -> Bool {
        "、。，．！？：；」』）】〉》〕〗〙〛｝］,.!?:;)]}".contains(character)
    }
}
