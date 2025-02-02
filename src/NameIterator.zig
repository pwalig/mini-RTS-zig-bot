const std = @import("std");
const Self = @This();

const prefferedChars = [_][]const u8{
    "zZ2sS", "iI1lL", "gGqQ", "bB", "oO0Q", "tT7",
};

name: [9]u8 = [9]u8{ 'z', 'i', 'g', 'b', 'o', 't', '!', '!', '!' },
allowedChars: []const u8,
prefferedPos: [6]u8 = [6]u8{ 0, 0, 0, 0, 0, 0 },
allowedPos: [9]u8 = [9]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0 },
charId: u4 = 6,
nameLen: u4 = 6,

fn in(char: u8, allowed: []const u8) bool {
    for (allowed) |c| {
        if (char == c) return true;
    }
    return false;
}

fn fail(self: *Self) bool {
    for (self.allowedPos) |pos| {
        if (pos != self.allowedChars.len) return false;
    }
    return true;
}

pub fn init(allowed: []const u8) ?Self {
    var nameIter = Self{ .allowedChars = allowed };

    for (0..6) |i| {
        while (!in(nameIter.name[i], allowed)) {
            nameIter.prefferedPos[i] += 1;
            if (nameIter.prefferedPos[i] >= prefferedChars[i].len) break;
            nameIter.name[i] = prefferedChars[i][nameIter.prefferedPos[i]];
        }

        while (!in(nameIter.name[i], allowed)) {
            nameIter.allowedPos[i] += 1;
            if (nameIter.allowedPos[i] >= allowed.len) return null;
            nameIter.name[i] = allowed[nameIter.allowedPos[i]];
        }
    }
    return nameIter;
}

pub fn current(self: *Self) []const u8 {
    return self.name[0..self.nameLen];
}

pub fn next(self: *Self) ?[]const u8 {
    if (self.fail()) return null;
    if (self.charId < prefferedChars.len and self.prefferedPos[self.charId] < prefferedChars[self.charId].len) {
        self.name[self.charId] = prefferedChars[self.charId][self.prefferedPos[self.charId]]; // TO DO omit unallowed characters
        self.prefferedPos[self.charId] += 1;
        self.charId = 6;
    } else if (self.allowedPos[self.charId] < self.allowedChars.len) {
        self.nameLen = self.charId + 1;
        self.name[self.charId] = self.allowedChars[self.allowedPos[self.charId]];
        self.allowedPos[self.charId] += 1;
    } else {
        self.charId += 1;
        if (self.charId >= self.name.len) {
            self.charId = 0;
            self.allowedPos[6] = 0;
            self.allowedPos[7] = 0;
            self.allowedPos[8] = 0;
            self.nameLen = 6;
        }
        return self.next();
    }

    return self.current();
}
