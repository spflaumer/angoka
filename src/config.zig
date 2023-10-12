const std = @import("std");
const ArenaAllocator = std.heap.ArenaAllocator;
const ThreadPool = std.Thread.Pool;
const WaitGroup = std.Thread.WaitGroup;
const ArrayList = std.ArrayList;

const HashInputPaths = @import("file_hasher.zig").HashInputPaths;

/// contains the state of the thread pool
pub const ThreadContext = struct {
        // thread specific allocator, stays alive until the thread pool is closed
        // used for allocations relating to the thread pool
        arena: ArenaAllocator,
        // the thread pool containing all the worker threads
        pool: ThreadPool,

        const Self = @This();

        /// initialize the thread pool and arena allocator
        pub fn init(ctx: *const AngokuContext, allocator: std.mem.Allocator) !Self {
                // intialize an ArenaAllocator that will be used by the thread pool
                var arena = ArenaAllocator.init(allocator);
                // create the thread pool
                var pool: *ThreadPool = try arena.allocator().create(ThreadPool);
                pool.init(.{
                        .allocator = arena.allocator(),
                        .n_jobs = ctx.jobs,
                });

                return .{
                        .arena = arena,
                        .pool = pool,
                };
        }

        /// stop the worker threads and deallocate all used resources
        pub fn deinit(self: *Self) void {
                self.threads.deinit();
                self.arena.deinit();
        }
};

/// contains the state of the main program
pub const AngokuContext = struct {
        // global allocator aka. Arena1, stays alive until .deinit() is called
        // used or minor alocations that will get cleaned at the end of the main function
        arena: ArenaAllocator,
        // the amount of jobs/worker threads the thread pool should have
        jobs: u32,
        // input files that need to be still read from
        input: ArrayList(HashInputPaths),
        // output file that will contain the key
        // if null, write to stdout
        output: ?[]const u8,
};