const std = @import("std");

const helpMessage =
    "Usage:\n" ++
    "(1) {s} <host> <port> [runModeOptions]\n" ++
    "(2) {s} [infoOptions]\n" ++
    "\n" ++
    "Arguments:\n" ++
    "\t<host>\t\t IPv4 address of the server\n" ++
    "\t<port>\t\t Port number of the server\n" ++
    "\n" ++
    "[runModeOptions]:\n" ++
    "\t--gamesToPlay <number>\tPlay <number> games then exit (by default zig-bot tries to play unlimited number of games)\n" ++
    "\n" ++
    "[infoOptions]:\n" ++
    "\t-h, --help\t\tPrint this help and exit\n" ++
    "\t-v, --version\t\tPrint version number and exit\n" ++
    "\n";

pub fn printHelpMessage(programName: []const u8) !void {
    try std.io.getStdOut().writer().print(helpMessage, .{ programName, programName });
}

pub fn printErrorMessage(programName: []const u8, comptime format: []const u8, args: anytype) !void {
    try std.io.getStdOut().writer().print(format, args);
    try printHelpMessage(programName);
}
