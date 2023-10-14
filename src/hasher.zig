const std = @import("std");

const AngokaContext = @import("root").config.AngokaContext;

pub const file_hasher = @import("hasher/file_hasher.zig");
pub const passwd_hasher = @import("hasher/passwd_hasher.zig");

/// get the final hash as a slice
pub fn getHash(ctx: *AngokaContext) ![]u8 {
        // allocate 64 bytes (digest length of the sha3_512 hash)
        var hash: [64]u8 = .{0}**@TypeOf(ctx.hasher).digest_length; 

        // get the hash
        ctx.hasher.final(&hash);

        // copy the hash into allocated memory
        const hash_alloc = try ctx.arena.allocator().alloc(u8, @TypeOf(ctx.hasher).digest_length);
        @memcpy(hash_alloc, &hash);

        return hash_alloc;
}