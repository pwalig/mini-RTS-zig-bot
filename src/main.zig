const std = @import("std");
const net = std.net;
const print = std.debug.print;

const Client = @import("client.zig").Client;
const Help = @import("Help.zig");

const version = "1.1.0";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.ArgIterator.initWithAllocator(allocator);
    defer args.deinit();

    const program_name = args.next() orelse "mini-RTS-zig-bot";

    const host_value = args.next() orelse {
        try Help.printErrorMessage(program_name, "no host provided\n", .{});
        return;
    };

    if (std.mem.eql(u8, host_value, "-v") or std.mem.eql(u8, host_value, "--version")) {
        if (args.next()) |option| {
            try Help.printErrorMessage(program_name, "unnecessary additional option: {s}\n", .{option});
        } else try std.io.getStdOut().writer().print("{s}\n", .{version});
        return;
    } else if (std.mem.eql(u8, host_value, "-h") or std.mem.eql(u8, host_value, "--help")) {
        if (args.next()) |option| try std.io.getStdOut().writer().print("unnecessary additional option: {s}\n", .{option});
        try Help.printHelpMessage(program_name);
        return;
    }

    const port_value = args.next() orelse {
        try Help.printErrorMessage(program_name, "no port provided\n", .{});
        return;
    };

    var gamesToPlay: ?u32 = null;
    while (args.next()) |option| {
        if (std.mem.eql(u8, option, "--gamesToPlay")) {
            if (args.next()) |number| {
                gamesToPlay = std.fmt.parseUnsigned(u32, number, 10) catch {
                    try Help.printErrorMessage(program_name, "invalid number of games to play {s}\n", .{number});
                    return;
                };
            } else {
                try Help.printErrorMessage(program_name, "number of games to play not provided\n", .{});
                return;
            }
        } else {
            try Help.printErrorMessage(program_name, "unrecognised option: {s}\n", .{option});
            return;
        }
    }

    const port = std.fmt.parseUnsigned(u16, port_value, 10) catch {
        try Help.printErrorMessage(program_name, "invalid port number {s}\n", .{port_value});
        return;
    };

    var cli = try Client.init(host_value, port, gamesToPlay);
    defer cli.deinit();
    cli.loop(allocator);
}
