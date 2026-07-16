const std = @import("std");
const version_info = @import("version_info");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    // Parse command line arguments
    var args = init.minimal.args.iterate();

    // Skip the program name
    _ = args.next();

    var input_path: []const u8 = "package.json";
    var output_path: []const u8 = "version-info.ts";
    var git_path: []const u8 = ".git";

    // Parse arguments
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) {
            try version_info.printToolVersion(allocator);
            return;
        } else if (std.mem.eql(u8, arg, "--input") or std.mem.eql(u8, arg, "-i")) {
            if (args.next()) |value| {
                input_path = value;
            }
        } else if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
            if (args.next()) |value| {
                output_path = value;
            }
        } else if (std.mem.eql(u8, arg, "--git") or std.mem.eql(u8, arg, "-g")) {
            if (args.next()) |value| {
                git_path = value;
            }
        }
    }

    try version_info.generateVersionInfo(allocator, io, input_path, output_path, git_path);
}
