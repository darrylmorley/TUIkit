//  🖥️ TUIKit — Terminal UI Kit for Swift
//  String+TerminalWidth.swift
//
//  Created by LAYERED.work
//  License: MIT

// MARK: - Terminal Character Width

extension Character {
    /// The display width of this character in a terminal (number of cells).
    ///
    /// The rule follows Markus Kuhn's `wcwidth` (the one glibc uses), applied
    /// to each code point of the grapheme cluster and summed:
    ///
    /// - East Asian Wide and Fullwidth code points (CJK, kana, hangul
    ///   syllables, fullwidth forms, most emoji): 2 cells.
    /// - Nonspacing and enclosing marks (Mn, Me), format characters (Cf:
    ///   ZWJ, ZWNJ, bidi marks such as U+061C, soft hyphen, prepended
    ///   concatenation marks such as U+0600), variation selectors, and
    ///   Hangul medial vowel and final consonant jamo: 0 cells.
    /// - Everything else, including spacing combining marks (Mc, such as
    ///   the Devanagari vowel sign U+093F): 1 cell.
    ///
    /// So a Devanagari conjunct such as क्ष is 2 cells (क 1, virama 0, ष 1),
    /// Thai กำ is 2, halfwidth ｶﾞ is 2, and e + U+0301 is 1.
    ///
    /// Emoji sequences are drawn as one glyph and count as 2: ZWJ sequences
    /// built on an emoji, skin-tone modifiers, flags (regional-indicator
    /// pairs), keycaps and tag sequences.
    ///
    /// Terminals do not all agree. macOS's own `wcwidth` returns 0 for some
    /// spacing marks (U+093F, U+0940), and terminals differ on Indic
    /// rendering generally, so this is one consistent rule, not a guarantee
    /// of what every terminal draws.
    public var terminalWidth: Int {
        let scalars = unicodeScalars
        guard let first = scalars.first else { return 0 }

        // Fast path: a lone printable ASCII character.
        if scalars.count == 1 {
            let value = first.value
            if value >= 0x20 && value < 0x7F { return 1 }
            return Self.codePointWidth(first)
        }

        if Self.isEmojiSequence(scalars) { return 2 }

        return scalars.reduce(0) { $0 + Self.codePointWidth($1) }
    }

    /// True for a multi-code-point cluster that terminals draw as one emoji.
    private static func isEmojiSequence(_ scalars: String.UnicodeScalarView) -> Bool {
        guard let first = scalars.first else { return false }
        if (0x1F1E6...0x1F1FF).contains(first.value) { return true }  // flag
        var hasJoiner = false
        for scalar in scalars.dropFirst() {
            let value = scalar.value
            if value == 0x20E3 { return true }                       // keycap
            if (0x1F3FB...0x1F3FF).contains(value) { return true }   // skin tone
            if (0xE0020...0xE007F).contains(value) { return true }   // tag sequence
            if value == 0x200D { hasJoiner = true }
        }
        // ZWJ also appears inside Indic conjuncts, so it only makes an emoji
        // sequence when the base is an emoji (🏳 in 🏳️‍🌈 is text-default, so
        // `isEmojiPresentation` would miss it).
        return hasJoiner && first.properties.isEmoji
    }

    /// The cell width of one code point. See ``terminalWidth``.
    private static func codePointWidth(_ scalar: Unicode.Scalar) -> Int {
        let value = scalar.value

        // Zero width.
        if (0xFE00...0xFE0F).contains(value) || (0xE0100...0xE01EF).contains(value) { return 0 }  // variation selectors
        if (0x1160...0x11FF).contains(value) || (0xD7B0...0xD7FF).contains(value) { return 0 }   // Hangul V/T jamo
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .enclosingMark, .format:
            return 0
        case .control:
            return value == 0 ? 0 : 1
        default:
            break
        }

        // East Asian Wide and Fullwidth (2 cells).
        if (0x1100...0x115F).contains(value) { return 2 } // Hangul Jamo initial consonants
        if (0x2329...0x232A).contains(value) { return 2 } // angle brackets
        if (0x2E80...0x303E).contains(value) { return 2 } // CJK radicals, Kangxi, ideographic
        if (0x3041...0x33BF).contains(value) { return 2 } // Hiragana, Katakana, Bopomofo, Hangul compat, Kanbun, CJK
        if (0x33D0...0x33FF).contains(value) { return 2 } // CJK compatibility
        if (0x3400...0x4DBF).contains(value) { return 2 } // CJK unified ext A
        if (0x4E00...0x9FFF).contains(value) { return 2 } // CJK unified
        if (0xA000...0xA4CF).contains(value) { return 2 } // Yi
        if (0xA960...0xA97F).contains(value) { return 2 } // Hangul Jamo extended A
        if (0xAC00...0xD7AF).contains(value) { return 2 } // Hangul syllables
        if (0xF900...0xFAFF).contains(value) { return 2 } // CJK compatibility ideographs
        if (0xFE10...0xFE19).contains(value) { return 2 } // vertical forms
        if (0xFE30...0xFE6F).contains(value) { return 2 } // CJK compatibility forms, small forms
        if (0xFF01...0xFF60).contains(value) { return 2 } // fullwidth forms
        if (0xFFE0...0xFFE6).contains(value) { return 2 } // fullwidth signs
        if (0x1F000...0x1FBFF).contains(value) { return 2 } // emoji and symbols
        if (0x20000...0x2FA1F).contains(value) { return 2 } // CJK unified extensions B-F, compatibility supplement
        if (0x30000...0x3134F).contains(value) { return 2 } // CJK unified extension G

        return 1
    }
}

// MARK: - ANSI String Helpers

extension String {
    /// The visible width of the string in terminal cells, excluding ANSI escape codes.
    ///
    /// Accounts for wide characters (emoji, CJK) that occupy 2 terminal cells
    /// and zero-width characters (combining marks, variation selectors).
    public var strippedLength: Int {
        var count = 0
        var index = startIndex

        while index < endIndex {
            if self[index] == "\u{1B}" {
                // Skip ANSI sequence: ESC [ params letter
                index = self.index(after: index)
                if index < endIndex && self[index] == "[" {
                    index = self.index(after: index)
                    // Skip parameter bytes (digits, semicolons)
                    while index < endIndex && (self[index].isNumber || self[index] == ";") {
                        index = self.index(after: index)
                    }
                    // Skip the final byte (letter)
                    if index < endIndex && self[index].isLetter {
                        index = self.index(after: index)
                    }
                }
            } else {
                count += self[index].terminalWidth
                index = self.index(after: index)
            }
        }

        return count
    }

    /// The string with all ANSI escape codes removed.
    public var stripped: String {
        var result = ""
        result.reserveCapacity(count)
        var index = startIndex

        while index < endIndex {
            if self[index] == "\u{1B}" {
                // Skip ANSI sequence: ESC [ params letter
                index = self.index(after: index)
                if index < endIndex && self[index] == "[" {
                    index = self.index(after: index)
                    while index < endIndex && (self[index].isNumber || self[index] == ";") {
                        index = self.index(after: index)
                    }
                    if index < endIndex && self[index].isLetter {
                        index = self.index(after: index)
                    }
                }
            } else {
                result.append(self[index])
                index = self.index(after: index)
            }
        }

        return result
    }

    /// Returns a copy with ANSI escape sequences removed, suitable for rendering user-provided content.
    ///
    /// Use this to sanitize user input before passing it to ``Text`` or other views
    /// to prevent terminal escape sequence injection (cursor manipulation, color changes, etc.).
    ///
    /// ```swift
    /// Text(userInput.sanitizedForTerminal)
    /// ```
    public var sanitizedForTerminal: String {
        stripped
    }

    /// Pads the string to the specified visible width using spaces.
    ///
    /// ANSI codes and wide characters are handled correctly.
    ///
    /// - Parameter targetWidth: The desired visible width in terminal cells.
    /// - Returns: The padded string.
    public func padToVisibleWidth(_ targetWidth: Int) -> String {
        let currentWidth = strippedLength
        if currentWidth >= targetWidth {
            return self
        }
        return self + String(repeating: " ", count: targetWidth - currentWidth)
    }

    // MARK: - ANSI-Aware Splitting

    /// Returns the first `visibleCount` terminal cells worth of visible characters,
    /// preserving all ANSI codes that appear before or within that range.
    ///
    /// Wide characters (emoji, CJK) count as 2 cells. If a wide character would
    /// exceed the limit, it is excluded.
    ///
    /// - Parameter visibleCount: The number of terminal cells to include.
    /// - Returns: A substring with ANSI codes intact up to the visible boundary.
    public func ansiAwarePrefix(visibleCount: Int) -> String {
        guard visibleCount > 0 else { return "" }

        var result = ""
        var visible = 0
        var index = startIndex

        while index < endIndex && visible < visibleCount {
            // Check if we're at the start of an ANSI escape sequence
            if self[index] == "\u{1B}" {
                // Consume the entire ANSI sequence (ESC [ ... letter)
                let seqStart = index
                index = self.index(after: index)
                if index < endIndex && self[index] == "[" {
                    index = self.index(after: index)
                    // Skip parameter bytes (digits, semicolons)
                    while index < endIndex && (self[index].isNumber || self[index] == ";") {
                        index = self.index(after: index)
                    }
                    // Skip the final byte (letter)
                    if index < endIndex && self[index].isLetter {
                        index = self.index(after: index)
                    }
                }
                result += String(self[seqStart..<index])
            } else {
                let charWidth = self[index].terminalWidth
                if visible + charWidth > visibleCount { break }
                result.append(self[index])
                visible += charWidth
                index = self.index(after: index)
            }
        }

        return result
    }

    /// Returns everything after the first `dropCount` terminal cells of visible characters,
    /// preserving ANSI codes that appear at or after that boundary.
    ///
    /// Wide characters count as 2 cells.
    ///
    /// - Parameter dropCount: The number of terminal cells to skip.
    /// - Returns: The remainder of the string with ANSI codes intact.
    public func ansiAwareSuffix(droppingVisible dropCount: Int) -> String {
        var visible = 0
        var index = startIndex

        while index < endIndex && visible < dropCount {
            if self[index] == "\u{1B}" {
                // Skip the entire ANSI sequence
                index = self.index(after: index)
                if index < endIndex && self[index] == "[" {
                    index = self.index(after: index)
                    while index < endIndex && (self[index].isNumber || self[index] == ";") {
                        index = self.index(after: index)
                    }
                    if index < endIndex && self[index].isLetter {
                        index = self.index(after: index)
                    }
                }
            } else {
                visible += self[index].terminalWidth
                index = self.index(after: index)
            }
        }

        guard index < endIndex else { return "" }
        return String(self[index...])
    }

    // MARK: - ANSI State Extraction

    /// Extracts all leading ANSI SGR sequences that appear before the first
    /// visible character and returns them concatenated.
    ///
    /// This captures the full styling state set up at the beginning of a line
    /// (e.g. background, foreground, dim) so it can be replayed to restore
    /// that state after an interruption (like an overlay insertion).
    ///
    /// Unlike scanning the entire string, this avoids picking up trailing
    /// codes that follow a reset (e.g. the lone background code appended by
    /// `applyPersistentBackground`).
    ///
    /// - Returns: The concatenated leading ANSI sequences, or an empty string
    ///   if the line starts with a visible character.
    public func leadingANSISequences() -> String {
        var result = ""
        var index = startIndex

        while index < endIndex {
            guard self[index] == "\u{1B}" else { break }

            // Consume the ANSI sequence (ESC [ params letter)
            let seqStart = index
            index = self.index(after: index)
            if index < endIndex && self[index] == "[" {
                index = self.index(after: index)
                while index < endIndex && (self[index].isNumber || self[index] == ";") {
                    index = self.index(after: index)
                }
                if index < endIndex && self[index].isLetter {
                    index = self.index(after: index)
                }
            }
            result += String(self[seqStart..<index])
        }

        return result
    }
}
