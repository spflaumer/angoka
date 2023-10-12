const std = @import("std");
const ArrayList = std.ArrayList;

const config = @import("config");
const AngokuConfig = config.AngokuContext;
const ThreadContext = config.ThreadContext;
const sha3_512 = std.crypto.hash.sha3.Sha3_512;

pub const HashInputPaths = struct {
        // the path in the filesystem
        path: []const u8,
        // if the path above would be a folder, specify that
        folder: bool,
};

inline fn __hashFile(ctx: *ThreadContext, path: []const u8) !void {
        // open the file
        const cwd = std.fs.cwd();
        const file = try cwd.openFile(path, .{});
        const stat_file = try file.stat();

        // create the buffer where the file's content will end up in
        ctx.arena_lock.lock();
        var contents = ctx.arena.allocator().alloc(u8, stat_file.size + 1);
        ctx.arena_lock.unlock();
        // read the file into the buffer
        _ = try file.reader().readAll(contents);

        // add the contents into the hasher state
        ctx.hasher_lock.lock();
        ctx.hasher.update(contents);
        ctx.hasher_lock.unlock();
}

fn _hashFromPath(ctx: *ThreadContext, inputs: *ArrayList(HashInputPaths)) !void {
        // get a handle to the current working directory
        const cwd = std.fs.cwd();

        // get an input path element from the list
        while(inputs.popOrNull()) |inpu| {
                var input = @as(HashInputPaths, inpu);
                switch (input.folder) {
                        // if the path is a folder
                        true => {
                                var iter_folder = try cwd.openIterableDir(input.path, .{});
                                var walker_folder = try iter_folder.walk(ctx.arena.allocator());
                                defer walker_folder.deinit();
                                while(walker_folder.next()) {
                                        try __hashFile(ctx, input.path);
                                }
                        },
                        else => {
                                try __hashFile(ctx, input.path);
                        },
                }
        } 
}

/// get the hash of all input files
pub fn getHash(ctx: *AngokuConfig) ![sha3_512.digest_length]u8 {
        // initialize the threads
        var threads = try ThreadContext.init(ctx, std.heap.page_allocator);
        defer threads.deinit();

        // spawn the thread pool with the actual hashing function
        threads.work(_hashFromPath, .{&threads, ctx.input});

        // get the final hash
        var final_files: [64]u8 = undefined;
        threads.hasher.final(final_files);

        return final_files;
}