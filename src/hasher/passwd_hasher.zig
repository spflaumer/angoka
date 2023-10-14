const std = @import("std");
const ArrayList = std.ArrayList;

const AngokaContext = @import("root").config.AngokaContext;
const printf = @import("root").utils.printf;

/// allocate and return a buffer of user input from stdin
/// caller doesn't own memory
fn _userInputAlloc(ctx: *AngokaContext) ![]const u8 {
        // get a handle to stdin
        const stdin = std.io.getStdIn();
        // store the read content as an ArrayList
        var content_aslist = ArrayList(u8).init(ctx.arena.allocator());
        defer content_aslist.deinit();

        // read from stdin
        try stdin.reader().streamUntilDelimiter(content_aslist.writer(), '\n', null);

        // return the contents of the ArrayList as a slice
        return try content_aslist.toOwnedSlice();
}

/// add the user password to the hash state
pub fn generateHash(ctx: *AngokaContext) !void {
        // prompt the password
        try printf("Enter your Password:\n", .{});

        // get the users password
        const password = try _userInputAlloc(ctx);

        // add the slice to the hashers state
        ctx.hasher.update(password);
}