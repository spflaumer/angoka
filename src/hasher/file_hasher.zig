const std = @import("std");
const builtin = @import("builtin");
const ArrayList = std.ArrayList;

const config = @import("root").config;
const AngokuConfig = config.AngokaContext;
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
        var contents = try ctx.arena.allocator().alloc(u8, stat_file.size + 1);
        ctx.arena_lock.unlock();
        // read the file into the buffer
        _ = try file.reader().readAll(contents);

        // add the contents into the hasher state
        ctx.hasher_lock.lock();
        ctx.hasher.update(contents);
        ctx.hasher_lock.unlock();
}

fn _hashFromPath(ctx: *ThreadContext) !void {
        // get a handle to the current working directory
        const cwd = std.fs.cwd();

        // get an input path element from the list
        while(inputs: {
                ctx.inputs_lock.lock();
                defer ctx.inputs_lock.unlock();
                break :inputs ctx.inputs.popOrNull();
        }) |input| {
                switch (input.folder) {
                        // if the path is a folder
                        true => {
                                var iter_folder = try cwd.openIterableDir(input.path, .{});
                                var walker_folder = try iter_folder.walk(ctx.arena.allocator());
                                defer walker_folder.deinit();
                                while(try walker_folder.next()) |entry| {
                                        // since all entries are relative to the directory opened as iterator
                                        // the absolute path will have to be used instead
                                        ctx.arena_lock.lock();
                                        const path_full = try std.fs.path.join(ctx.arena.allocator(), &.{input.path, entry.path});
                                        ctx.arena_lock.unlock();
                                        if(entry.kind == .file) try __hashFile(ctx, path_full);
                                }
                        },
                        else => {
                                try __hashFile(ctx, input.path);
                        },
                }
        } 
}

/// add the hash of the input files to the hash state
pub fn generateHash(ctx: *AngokuConfig) !void {
        // initialize the threads
        var threads = try ThreadContext.init(ctx, std.heap.page_allocator);
        defer threads.deinit();

        // spawn the thread pool with the actual file hashing function
        try threads.work(_hashFromPath, .{&threads});
}