const std = @import("std");
const ArenaAllocator = std.heap.ArenaAllocator;
const Thread = std.Thread;
const WaitGroup = std.Thread.WaitGroup;
const ArrayList = std.ArrayList;
const Mutex = std.Thread.Mutex;
const sha3_512 = std.crypto.hash.sha3.Sha3_512;

const single_threaded = @import("builtin").single_threaded;

const HashInputPaths = @import("file_hasher.zig").HashInputPaths;

/// contains the state of the hashing thread pool
pub const ThreadContext = struct {
        // thread specific allocator, stays alive until the thread pool is closed
        // used for allocations relating to the thread pool
        arena: ArenaAllocator,
        // mutex for the arena allocator
        arena_lock: Mutex,
        // the thread pool containing all the worker threads
        threads: []Thread,
        // the wait group that will be used with the thread pool
        wait_group: WaitGroup,
        // the hashing function and it's state
        hasher: sha3_512,
        // mutex for the hasher
        hasher_lock: Mutex,

        const Self = @This();

        /// wrapper around pool.spawn() and pool.waitAndWork()
        /// the function supplied should use this struct's WaitGroup
        /// this SHOULD NOT be called twice
        pub fn work(ctx: *Self, comptime func: anytype, args: anytype) !void {
                // spawn the requested amount of threads
                for(0..ctx.jobs) |i| ctx.threads[i] = try Thread.spawn(.{}, func, args);
                // join the threads
                for (0..ctx.jobs) |i| ctx.threads[i].join();
        }

        /// initialize the thread pool and arena allocator
        pub fn init(ctx: *const AngokuContext, allocator: std.mem.Allocator) !Self {
                // intialize an ArenaAllocator that will be used by the thread pool
                var arena = ArenaAllocator.init(allocator);

                return .{
                        .arena = arena,
                        .arena_lock = Mutex{},
                        .threads = try arena.allocator().alloc(Thread, jobs: {
                                // create only one extern thread if single threaded
                                if(single_threaded) {
                                        break :jobs 1;
                                } else {
                                        break :jobs ctx.jobs;
                                }
                        }),
                        .wait_group = WaitGroup{},
                        .hasher = sha3_512.init(.{}),
                        .hasher_lock = Mutex{},
                };
        }

        /// stop the worker threads and deallocate all used resources
        pub fn deinit(self: *Self) void {
                self.pool.deinit();
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