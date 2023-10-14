const std = @import("std");
const ArenaAllocator = std.heap.ArenaAllocator;
const Thread = std.Thread;
const ArrayList = std.ArrayList;
const Mutex = std.Thread.Mutex;
const sha3_512 = std.crypto.hash.sha3.Sha3_512;

const single_threaded = @import("builtin").single_threaded;

const clap = @import("clap");

const HashInputPaths = @import("root").hasher.file_hasher.HashInputPaths;

/// contains the state of the hashing thread pool
pub const ThreadContext = struct {
        // thread specific allocator, stays alive until the thread pool is closed
        // used for allocations relating to the thread pool
        arena: ArenaAllocator,
        // mutex for the arena allocator
        arena_lock: Mutex,
        // the amount of threads
        jobs: u32,
        // the threads that will run the hashing function
        threads: ArrayList(Thread),
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
                for(0..ctx.jobs) |_| {
                        // for some reason, using .append() causes the following error
                        // "thread <id> panic: start index 16 is larger than end index 0"
                        // calling .ensureCapacity(1) beforehand or using .addOne() instead seems to resolve the issue
                        var thread = try ctx.threads.addOne();
                        thread.* =  try Thread.spawn(.{.allocator = ctx.arena.allocator()}, func, args);
                }
                // join the threads
                // since the threads are popped off of the list, we can insure that no repeated calls are made to consumed threads
                while(ctx.threads.popOrNull()) |thread| @as(Thread, thread).join();
        }

        /// initialize the thread pool and arena allocator
        pub fn init(ctx: *AngokaContext, allocator: std.mem.Allocator) !Self {
                // intialize an ArenaAllocator that will be used by the thread pool
                var arena = ArenaAllocator.init(allocator);

                return .{
                        .arena = arena,
                        .arena_lock = Mutex{},
                        .jobs = ctx.jobs,
                        .threads = ArrayList(Thread).init(arena.allocator()),
                        .hasher = &ctx.hasher,
                        .hasher_lock = Mutex{},
                        .inputs = &ctx.input,
                        .inputs_lock = Mutex{},
                };
        }

        /// stop the worker threads and deallocate all used resources
        pub fn deinit(self: *Self) void {
                // technically this is a no-op considering that the list is managed by an arena
                self.threads.deinit();
                self.arena.deinit();
        }
};

/// contains the state of the main program
pub const AngokaContext = struct {
        // global allocator aka. Arena1, stays alive until .deinit() is called on the AngokuConfig struct this was initialized with
        // used or minor alocations that will get cleaned at the end of the main function
        arena: *ArenaAllocator,
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
        pub fn init(conf: *AngokaConfig) !Self {
                // initialize the global ArenaAllocator
                var arena = &conf._arena;

                // parse the list of input files/folders
                var input_list = std.ArrayList(HashInputPaths).init(arena.allocator());
                for (conf.input) |input| {
                        // the path and folder are split by a semicolon
                        // split them and parse the string for folder to a bool
                        try input_list.append(input_path: {
                                var tokens = std.mem.tokenizeAny(u8, input, ":");
                                // the first part should be the input path
                                const path = tokens.next() orelse return error.BadInputParamPath;
                                // the second part should be the boolean as string
                                const folder = folder: {
                                        const folder_str = tokens.next() orelse return error.BadInputParamPath;
                                        // parse the string and return an error if it is not a boolean
                                        break :folder if (std.mem.eql(u8, folder_str, "true"))
                                                true else if (std.mem.eql(u8, folder_str, "false")) false else return error.BadInputParamPathKindFolder;
                                };

                                break :input_path .{
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

        /// the ArenaAllocator is actually managed by the config struct
        /// the only thing that needs .deinit() called on is the list of input
        /// technically this is a no-op
        pub fn deinit(self: *Self) void {
                self.input.deinit();
        }
};

const AngokaJSON = struct {
        jobs: u32,
        input: []const []const u8,
        output: []const u8,
};

pub const AngokaConfig = struct {
        jobs: u32,
        input: []const []const u8,
        output: ?[]const u8,
        // deinit() needs to free the duplicated strings
        _arena: ArenaAllocator,

        const Self = @This();

        /// parses the configuration from a JSON object string
        pub fn init(json_str: []const u8, allocator: std.mem.Allocator) !Self {
                // parse the JSON object
                var json_args = try std.json.parseFromSlice(AngokaJSON, allocator, json_str, .{});
                defer json_args.deinit();

                var arena = std.heap.ArenaAllocator.init(allocator);

                // initialize the config
                return .{
                        .input = inputs: {
                                var input = try arena.allocator().dupe([]const u8, json_args.value.input);
                                for (0..input.len) |i| {
                                        input[i] = try arena.allocator().dupe(u8, json_args.value.input[i]);
                                }
                                break :inputs input;
                        },
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

/// initialize this struct with options received from the command-line
pub fn initConfig(allocator: std.mem.Allocator) !AngokaConfig {
        // define commandline arguments and parse them into a struct useable by zig-clap
        const params = comptime clap.parseParamsComptime(
        \\-h, --help                    display this help message
        \\-i, --input   <str>...        input file(s)/folder(s) to take as hash
        \\-o, --output  <str>           output keyfile (leave empty for stdout)
        \\-j, --jobs    <u32>           how many threads should be spawned
        \\-c, --config  <str>           specify the config file to use (default ./angoka.json > /etc/angoka.json)
        \\
        );

        // parse the commandline arguments given
        var diag = clap.Diagnostic{};
        const res = clap.parse(clap.Help, &params, clap.parsers.default, .{.diagnostic = &diag}) catch |err| {
                try diag.report(std.io.getStdErr().writer(), err);
                return err;
        };
        defer res.deinit();

        // print help and exit if the help parameter was used
        if(res.args.help != 0) {
                clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{}) catch {};
                std.os.exit(0);
        }

        // open and read from the file specified by --config
        const cwd = std.fs.cwd();  // open a handle to the current working directory
        const stat = try cwd.statFile("./angoka.json");  // get stats for the current file
        const contents_file = try cwd.readFileAlloc(allocator, "./angoka.json", stat.size + 1);

        // get the AngokuConfig from a provided config file
        // or default angoku config location (./angoku.json or /etc/angoku/angoku.json)
        var config = try AngokaConfig.init(contents_file, allocator);

        // overwrite the config with commandline arguments
        if(res.args.input.len > 0) {
                config.input = inputs: {
                                var input = try config._arena.allocator().dupe([]const u8, res.args.input);
                                for (0..input.len) |i| {
                                        input[i] = try config._arena.allocator().dupe(u8, res.args.input[i]);
                                }
                                break :inputs input;
                        };
        }

        if(res.args.output) |output| {
                config.output = try config._arena.allocator().dupe(u8, output);
        }

        if(res.args.jobs) |jobs| {
                config.jobs = jobs;
        }

        // config will now have following precedence
        // commandline arguemtns > (config file in local folder || config file in default folder)*
        // * needs to be implemented first
        return config;
}