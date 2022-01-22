// syntax.zig

pub const SyntaxFlags = enum(u16) {
    HighlightNumbers = 1 << 0,
    HighlightStrings = 1 << 1,
};

pub const EditorSyntax = struct {
    fileType: []const u8,
    fileMatch: [][]const u8,
    keywords: [][]const u8,
    singlelineCommentStart: []const u8,
    multilineCommentStart: []const u8,
    multilineCommentEnd: []const u8,
    flags: usize,
};

// HLDB (highlight database)
pub const HLDB = [_]EditorSyntax{
    EditorSyntax{
        .fileType = "c",
        .fileMatch = [_][]u8{
            ".c",
            ".h",
            ".cpp",
        },
        .keywords = [_][]u8{
            "switch",  "if",     "while", "for",     "break",  "continue", "return",
            "else",    "struct", "union", "typedef", "static", "enum",     "class",
            "case",    "int|",   "long|", "double|", "float|", "char|",    "unsigned|",
            "signed|", "void|",
        },
        .singlelineCommentStart = "//",
        .multilineCommentStart = "/*",
        .multilineCommentEnd = "*/",
        .flags = @enumToInt(SyntaxFlags.HighlightNumbers) |
            @enumToInt(SyntaxFlags.HighlightStrings),
    },
};

// eof
