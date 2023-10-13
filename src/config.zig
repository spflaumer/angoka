const std = @import("std");
const ArenaAllocator = std.heap.ArenaAllocator;
const Thread = std.Thread;
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
        // the threads that will run the hashing function
        threads: []Thread,
        // the hashing function and it's state
        hasher: *sha3_512,
        // mutex for the hasher
        hasher_lock: Mutex,
        // input file paths
        inputs: *ArrayList(HashInputPaths),
        // the mutex for the inputs
        inputs_lock: Mutex,

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
        pub fn init(ctx: *AngokuContext, allocator: std.mem.Allocator) !Self {
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
                        .hasher = &ctx.hasher,
                        .hasher_lock = Mutex{},
                        .inputs = &ctx.input,
                        .inputs_lock = Mutex{},
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
        // the global hash state
        hasher: sha3_512,

        const Self = @This();

        // initialize the context from the configuration
        pub fn init(allocator: std.mem.Allocator, conf: *const AngokuConfig) !Self {
                // initialize the global ArenaAllocator
                var arena = ArenaAllocator.init(allocator);

                var input_list = std.ArrayList(HashInputPaths).init(arena.allocator());
                for (conf.input) |input| {
                        try input_list.append(input: {
                                var tokens = std.mem.tokenizeAny(u8, input, ":");
                                const path = tokens.next() orelse return error.BadInputParamPath;
                                const folder = folder: {
                                        const folder_str = tokens.next() orelse return error.BadInputParamPath;
                                        break :folder if (std.mem.eql(u8, folder_str, "true"))
                                                true else if (std.mem.eql(u8, folder_str, "false")) false else return error.BadInputParamPathKindFolder;
                                };

                                break :input .{
                                        .path = path,
                                        .folder = folder,
                                };
                        });
                }

                return .{
                        .arena = arena,
                        .jobs = conf.jobs,
                        .input = input_list,
                        .output = conf.output,
                        .hasher = sha3_512{},
                };
        }
};

const AngokuJSON = struct {
        jobs: u32,
        input: []const []const u8,
        output: []const u8,
};

pub const AngokuConfig = struct {
        jobs: u32,
        input: [][]const u8,
        output: ?[]const u8,
        // deinit() needs to free the duplicated strings
        _arena: std.heap.ArenaAllocator,

        const Self = @This();

        /// parses the configuration from a JSON object string
        pub fn init(json_str: []const u8, allocator: std.mem.Allocator) !Self {
                // parse the JSON object
                var json_args = try std.json.parseFromSlice(AngokuJSON, allocator, json_str, .{});
                defer json_args.deinit();

                var arena = std.heap.ArenaAllocator.init(allocator);

                // initialize the config
                return .{
                        .input = try arena.allocator().dupe([]const u8, json_args.value.input),
                        .jobs = json_args.value.jobs,
                        // is no output file is provided, write to stdout
                        .output = if(std.mem.eql(u8, json_args.value.output, "") or std.mem.eql(u8, json_args.value.output, "stdout")) null else
                                try arena.allocator().dupe(u8, json_args.value.output),
                        ._arena = arena,
                };
        }

        /// frees the duplicated strings (input and output)
        pub fn deinit(self: *Self) void {
                self._arena.deinit();
        }
};