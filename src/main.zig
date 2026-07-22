const std = @import("std");
const cli = @import("cli");
const version_info = @import("version_info");

pub fn main(init: std.process.Init) !void {
    var args = try init.minimal.args.iterateAllocator(init.gpa);
    defer args.deinit();
    _ = args.next();

    switch (cli.parse(&args)) {
        .help => try printHelp(init.io),
        .version => try version_info.printToolVersion(init.gpa),
        .invalid => |invalid| {
            var stderr_buffer: [4096]u8 = undefined;
            var stderr_writer = std.Io.File.stderr().writer(init.io, &stderr_buffer);
            try cli.writeInvalidArgument(&stderr_writer.interface, invalid);
            try cli.writeHelp(&stderr_writer.interface);
            try stderr_writer.interface.flush();
            std.process.exit(2);
        },
        .generate => |options| {
            if (options.verbose) {
                try version_info.generateVersionInfoWithOptions(
                    init.gpa,
                    init.io,
                    options.input_path,
                    options.output_path,
                    options.git_path,
                    .{ .verbose = true },
                );
            } else {
                try version_info.generateVersionInfo(
                    init.gpa,
                    init.io,
                    options.input_path,
                    options.output_path,
                    options.git_path,
                );
            }
        },
    }
}

fn printHelp(io: std.Io) !void {
    var stderr_buffer: [4096]u8 = undefined;
    var stderr_writer = std.Io.File.stderr().writer(io, &stderr_buffer);
    try cli.writeHelp(&stderr_writer.interface);
    try stderr_writer.interface.flush();
}
