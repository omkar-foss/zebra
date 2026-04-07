const std = @import("std");
const constants = @import("constants.zig");

/// Returns true if needle found in haystack, assumes haystack is sorted already.
pub fn binarySearch(haystack: []const []const u8, needle: []const u8) bool {
    var left: usize = 0;
    var right: usize = haystack.len;
    while (left < right) {
        const mid = left + (right - left) / 2;
        const cmp = std.mem.order(u8, needle, haystack[mid]);
        switch (cmp) {
            .eq => return true,
            .lt => right = mid,
            .gt => left = mid + 1,
        }
    }
    return false;
}

/// returns true if key name could contain sensitive information, false otherwise
pub fn isSensitiveKey(key_name: []const u8) !bool {
    var buf: [256]u8 = undefined; // max key length
    const key_name_upper = std.ascii.upperString(buf[0..key_name.len], key_name);

    // check if known keywords match key name
    for (constants.KW_SENSITIVE_GENERIC) |kw| {
        if (std.mem.indexOf(u8, key_name_upper, kw) != null) {
            return true;
        }
    }
    if (binarySearch(constants.KW_SENSITIVE_SPECIFIC[0..], key_name_upper)) {
        return true;
    }
    return false;
}
