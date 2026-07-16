const std = @import("std");

const color = struct {
    const reset = "\x1b[0m";
    const red = "\x1b[31m";
    const green = "\x1b[32m";
    const yellow = "\x1b[33m";
    const bright_cyan = "\x1b[96m";
};

pub const GenerateOptions = struct {
    input_path: []const u8 = "package.json",
    output_path: []const u8 = "version-info.ts",
    git_path: []const u8 = ".git",
    verbose: bool = false,
};

pub const InvalidArgument = union(enum) {
    unknown: []const u8,
    missing_value: []const u8,
};

pub const Action = union(enum) {
    help,
    version,
    generate: GenerateOptions,
    invalid: InvalidArgument,
};

pub fn parse(args: anytype) Action {
    var options: GenerateOptions = .{};

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            return .help;
        } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) {
            return .version;
        } else if (std.mem.eql(u8, arg, "--verbose")) {
            options.verbose = true;
        } else if (std.mem.eql(u8, arg, "--input") or std.mem.eql(u8, arg, "-i")) {
            const value = args.next() orelse return .{ .invalid = .{ .missing_value = arg } };
            if (std.mem.startsWith(u8, value, "-")) return .{ .invalid = .{ .missing_value = arg } };
            options.input_path = value;
        } else if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
            const value = args.next() orelse return .{ .invalid = .{ .missing_value = arg } };
            if (std.mem.startsWith(u8, value, "-")) return .{ .invalid = .{ .missing_value = arg } };
            options.output_path = value;
        } else if (std.mem.eql(u8, arg, "--git") or std.mem.eql(u8, arg, "-g")) {
            const value = args.next() orelse return .{ .invalid = .{ .missing_value = arg } };
            if (std.mem.startsWith(u8, value, "-")) return .{ .invalid = .{ .missing_value = arg } };
            options.git_path = value;
        } else {
            return .{ .invalid = .{ .unknown = arg } };
        }
    }

    return .{ .generate = options };
}

pub fn writeHelp(writer: anytype) !void {
    try writer.writeAll(
        "\n" ++ color.bright_cyan ++ "Package Version Info" ++ color.reset ++
            "\n\n" ++ color.yellow ++ "Usage:" ++ color.reset ++
            "\n  package-version-info [options]" ++
            "\n\n" ++ color.yellow ++ "Options:" ++ color.reset ++
            "\n  " ++ color.green ++ "-h, --help" ++ color.reset ++
            "                     Display usage information." ++
            "\n  " ++ color.green ++ "-v, --version" ++ color.reset ++
            "                  Display current version." ++
            "\n      " ++ color.green ++ "--verbose" ++ color.reset ++
            "                  Display detailed generation progress." ++
            "\n  " ++ color.green ++ "-i, --input <path>" ++ color.reset ++
            "             Input package.json (default: package.json)." ++
            "\n  " ++ color.green ++ "-o, --output <path>" ++ color.reset ++
            "            Output TypeScript file (default: version-info.ts)." ++
            "\n  " ++ color.green ++ "-g, --git <path>" ++ color.reset ++
            "               Git directory (default: .git)." ++
            "\n\n",
    );
}

pub fn writeInvalidArgument(writer: anytype, invalid: InvalidArgument) !void {
    switch (invalid) {
        .unknown => |arg| try writer.print(
            color.red ++ "Error:" ++ color.reset ++ " unknown argument '{s}'.\n\n",
            .{arg},
        ),
        .missing_value => |arg| try writer.print(
            color.red ++ "Error:" ++ color.reset ++ " option '{s}' requires a value.\n\n",
            .{arg},
        ),
    }
}

const TestIterator = struct {
    args: []const []const u8,
    index: usize = 0,

    fn next(iterator: *TestIterator) ?[]const u8 {
        if (iterator.index == iterator.args.len) return null;
        defer iterator.index += 1;
        return iterator.args[iterator.index];
    }
};

fn parseTest(args: []const []const u8) Action {
    var iterator: TestIterator = .{ .args = args };
    return parse(&iterator);
}

test "no arguments generate with default paths" {
    const options = parseTest(&.{}).generate;
    try std.testing.expectEqualStrings("package.json", options.input_path);
    try std.testing.expectEqualStrings("version-info.ts", options.output_path);
    try std.testing.expectEqualStrings(".git", options.git_path);
    try std.testing.expect(!options.verbose);
}

test "help flags show help" {
    try std.testing.expectEqual(.help, std.meta.activeTag(parseTest(&.{"-h"})));
    try std.testing.expectEqual(.help, std.meta.activeTag(parseTest(&.{"--help"})));
}

test "version flags show version" {
    try std.testing.expectEqual(.version, std.meta.activeTag(parseTest(&.{"-v"})));
    try std.testing.expectEqual(.version, std.meta.activeTag(parseTest(&.{"--version"})));
}

test "generation options are parsed" {
    const action = parseTest(&.{
        "--verbose",
        "--input",
        "input.json",
        "-o",
        "generated/info.ts",
        "-g",
        "../.git",
    });
    const options = action.generate;
    try std.testing.expectEqualStrings("input.json", options.input_path);
    try std.testing.expectEqualStrings("generated/info.ts", options.output_path);
    try std.testing.expectEqualStrings("../.git", options.git_path);
    try std.testing.expect(options.verbose);
}

test "verbose enables detailed generation progress" {
    const options = parseTest(&.{"--verbose"}).generate;
    try std.testing.expect(options.verbose);
    try std.testing.expectEqualStrings("package.json", options.input_path);
}

test "unknown argument is invalid" {
    const action = parseTest(&.{"--unknown"});
    try std.testing.expectEqualStrings("--unknown", action.invalid.unknown);

    const removed_command = parseTest(&.{"generate"});
    try std.testing.expectEqualStrings("generate", removed_command.invalid.unknown);
}

test "options require values" {
    inline for (.{ "--input", "-i", "--output", "-o", "--git", "-g" }) |arg| {
        const action = parseTest(&.{arg});
        try std.testing.expectEqualStrings(arg, action.invalid.missing_value);
    }

    const followed_by_option = parseTest(&.{ "--output", "--verbose" });
    try std.testing.expectEqualStrings("--output", followed_by_option.invalid.missing_value);
}

test "help contains usage commands and options" {
    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try writeHelp(&output.writer);
    const help = output.writer.buffered();
    try std.testing.expect(std.mem.startsWith(u8, help, "\n"));
    try std.testing.expect(std.mem.endsWith(u8, help, "\n\n"));
    try std.testing.expect(std.mem.indexOf(u8, help, "Usage:") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "Options:") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "Commands:") == null);
    try std.testing.expect(std.mem.indexOf(u8, help, " generate") == null);
    try std.testing.expect(std.mem.indexOf(u8, help, "--help") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "--verbose") != null);
}
