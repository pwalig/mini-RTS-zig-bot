const std = @import("std");
const parseInt = std.fmt.parseInt;

pub const Type = enum(u8) { config = 'c', players = 'p', resources = 'r', join = 'j', leave = 'l', move = 'm', attack = 'a', mine = 'd', unit = 'u', new_resource = 'f', tick = 't', queue = 'q', yes = 'y', no = 'n', lost = 'L', win = 'W' };

const ParseError = error{InvalitType};

pub fn getInts(msg: []const u8, list: *std.ArrayList(u32)) !void {
    var it = std.mem.tokenizeAny(u8, msg[1..], " ,;\n");
    while (it.next()) |num| {
        const n = try parseInt(u32, num, 10);
        try list.append(n);
    }
}

pub fn findTerminatedIndex(buff: []const u8) ?usize {
    for (buff, 0..) |byte, index| {
        if (byte == '\n') return index;
    }
    return null;
}

test "type enum" {
    const t = Type.attack;
    const c: u8 = @intFromEnum(t);
    const s: u8 = 'a';
    try std.testing.expectEqual(s, c);
    try std.testing.expectEqual('L', @intFromEnum(Type.lost));
    const t2: Type = @enumFromInt('W');
    try std.testing.expectEqual(Type.win, t2);
}
