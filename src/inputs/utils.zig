const std = @import("std");

pub fn sanitizeValue(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const has_escaped_quotes = std.mem.indexOfScalar(u8, input, '\\') != null;
    const is_double_quoted = input.len >= 2 and input[0] == '"' and input[input.len - 1] == '"';
    const is_single_quoted = input.len >= 2 and input[0] == '\'' and input[input.len - 1] == '\'';

    if (!has_escaped_quotes) {
        const to_dupe = if (is_double_quoted or is_single_quoted) input[1 .. input.len - 1] else input;
        return try allocator.dupe(u8, to_dupe);
    }

    const value = if (is_double_quoted or is_single_quoted) input[1 .. input.len - 1] else input;
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);
    try result.ensureTotalCapacity(allocator, value.len);
    var idx: usize = 0;
    while (idx < value.len) {
        if (value[idx] == '\\' and idx + 1 < value.len) {
            const next_char = value[idx + 1];
            if (is_double_quoted) {
                const escaped_char = switch (next_char) {
                    'n' => '\n',
                    'r' => '\r',
                    't' => '\t',
                    '\\' => '\\',
                    '\"' => '\"',
                    '\'' => '\'',
                    else => next_char,
                };
                try result.append(allocator, escaped_char);
            } else {
                if (next_char == '\'') {
                    try result.append(allocator, '\'');
                } else {
                    try result.append(allocator, '\\');
                    try result.append(allocator, next_char);
                }
            }
            idx += 2;
        } else {
            try result.append(allocator, value[idx]);
            idx += 1;
        }
    }
    return try result.toOwnedSlice(allocator);
}
