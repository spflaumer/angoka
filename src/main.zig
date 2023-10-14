//    Angoka - A file integrity dependent password generator
//    Copyright (C) 2023 - Simon Peter "spflaumer" Pflaumer
//
//    This program is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    This program is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
//    The text and the terms above apply to every file within this sub-directory

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