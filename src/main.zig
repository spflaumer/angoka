const std = @import("std");
pub const config = @import("config");
pub const hasher = @import("hasher");
pub const utils = @import("utils");
pub const keyWriter = @import("keyWriter");

pub fn main() !void {
        // setup the configuration for the program
        var conf = try config.initConfig(std.heap.page_allocator);
        defer conf.deinit();

        // create a global context for all sub-sequent functions
        var ctx = try config.AngokaContext.init(&conf);
        defer ctx.deinit();

        // hash the password first
        try hasher.passwd_hasher.generateHash(&ctx);

        // then hash the files in order to avoid having the user wait
        try hasher.file_hasher.generateHash(&ctx);

        // retrieve the final hash
        const hash = try hasher.getHash(&ctx);

        // write the final hash to it's final location
        try keyWriter.writeKey(&ctx, hash);
}