const std = @import("std");
const utils = @import("root").utils;

const AngokaContext = @import("root").config.AngokaContext;

pub fn writeKey(ctx: *AngokaContext, hash: []const u8) !void {
        if(ctx.output) |out| {
                // get a handle to the current working directory
                const cwd = std.fs.cwd();

                // open the target file for writing
                // file will be overwritten
                const file = try cwd.createFile(out, .{ .truncate = true });
                defer file.close();

                // create a BufferedWriter
                var buffer = std.io.bufferedWriter(file.writer());

                try buffer.writer().writeAll(hash);

                // finalize the write
                try buffer.flush();
        } else {
                // simply write the key to stdout if no output was specified
                try utils.printf("{s}", .{hash});
        }
}