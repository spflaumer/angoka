const std = @import("std");
const config = @import("config");


pub const HashInputPaths = struct {
        // the path in the filesystem
        path: []const u8,
        // if the path above would be a folder, specify that
        folder: bool,
};