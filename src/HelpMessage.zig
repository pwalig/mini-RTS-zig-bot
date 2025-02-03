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
    "\tfor now there are no runModeOptions\n" ++
    "\n" ++
    "[infoOptions]:\n" ++
    "\t-h, --help\tPrint this help and exit\n" ++
    "\t-v, --version\tPrint version number and exit\n" ++
    "\n";

pub fn printHelpMessage(programName: []const u8) !void {
    try std.io.getStdOut().writer().print(helpMessage, .{ programName, programName });
}
