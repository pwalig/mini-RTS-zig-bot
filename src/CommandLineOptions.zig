const std = @import("std");
const ArgIterator = std.process.ArgIterator;

const Self = @This();

gamesToPlay: ?u32 = null,
dontWin: bool = false,

pub fn init(args: ArgIterator, writer: anytype) !Self {
    var cmdops: Self = Self{};
    var arg = args;

    while (arg.next()) |option| {
        if (std.mem.eql(u8, option, "--gamesToPlay")) {
            if (cmdops.gamesToPlay != null) {
                try writer.print("--gamesToPlay option specified twice\n", .{});
                return error.parseError;
            }
            if (arg.next()) |number| {
                cmdops.gamesToPlay = std.fmt.parseUnsigned(u32, number, 10) catch {
                    try writer.print("invalid number of games to play {s}\n", .{number});
                    return error.parseError;
                };
            } else {
                try writer.print("number of games to play not provided\n", .{});
                return error.parseError;
            }
        } else if (std.mem.eql(u8, option, "--dontWin")) {
            if (cmdops.dontWin) {
                try writer.print("--dontWin option specified twice\n", .{});
                return error.parseError;
            } else cmdops.dontWin = true;
        } else {
            try writer.print("unrecognised option: {s}\n", .{option});
            return error.parseError;
        }
    }
    return cmdops;
}
