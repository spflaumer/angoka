const std = @import("std");

/// formatted print to stdout
pub fn printf(comptime format: []const u8, args: anytype) !void {
        // get a handle to stdout's writer
        // and create a buffered writer from it
        var stdout_buffered = std.io.bufferedWriter(std.io.getStdOut().writer());
        
        // pass along the formatting and the args to the print function
        try stdout_buffered.writer().print(format, args);
        // empty the buffer by "flushing" the contents out to stdout
        try stdout_buffered.flush();
}