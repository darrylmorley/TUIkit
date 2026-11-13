//  🖥️ TUIKit — Terminal UI Kit for Swift
//  WordWrap.swift
//
//  Created by LAYERED.work
//  License: MIT

// MARK: - Word Wrapping

/// Word wrapping measured in terminal cells, shared by ``Text`` and
/// notifications.
///
/// Lines break at spaces, and also on either side of a wide character
/// (CJK ideographs, kana, hangul, fullwidth forms), because CJK text has no
/// spaces between words and may break between any two characters. Widths
/// are display widths (`strippedLength`), so a two-cell character is never
/// placed across the right edge: it moves to the next line.
///
/// A run of narrow characters longer than `maxWidth` (a long word or URL)
/// still goes on its own line without being split, as before.
enum WordWrap {
    /// Wraps `text` into lines no wider than `maxWidth` terminal cells.
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
            for (index, piece) in pieces(of: word).enumerated() {
                // The first piece of a word follows a space; later pieces of
                // the same word (split around wide characters) join directly.
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

    /// Splits one space-free word at its break opportunities: before and
    /// after every wide character. A word with no wide characters (or an
    /// empty word) comes back whole.
    private static func pieces(of word: Substring) -> [String] {
        guard word.contains(where: { $0.terminalWidth > 1 }) else { return [String(word)] }
        var result: [String] = []
        var run = ""
        for character in word {
            if character.terminalWidth > 1 {
                if !run.isEmpty {
                    result.append(run)
                    run = ""
                }
                result.append(String(character))
            } else {
                run.append(character)
            }
        }
        if !run.isEmpty { result.append(run) }
        return result
    }
}
