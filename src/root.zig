//! Generates TypeScript version information from package metadata and Git.
const std = @import("std");

const embedded_package_json = @embedFile("package.json");
const compact_summary_format = "✅ Generated {s} (v{s}, {d}ms)";

const color = struct {
    const reset = "\x1b[0m";
    const yellow = "\x1b[33m";
    const blue = "\x1b[34m";
    const cyan = "\x1b[36m";
    const bright_green = "\x1b[92m";
    const bright_blue = "\x1b[94m";
    const bright_magenta = "\x1b[95m";
    const bright_cyan = "\x1b[96m";
};

fn log(comptime color_code: []const u8, comptime emoji: []const u8, comptime fmt: []const u8, args: anytype) void {
    std.debug.print("{s}" ++ emoji ++ " " ++ fmt ++ "{s}\n", .{color_code} ++ args ++ .{color.reset});
}

fn logNewLine() void {
    std.debug.print("\n", .{});
}

fn writeCompactSummary(writer: anytype, output_path: []const u8, version: []const u8, duration_ms: i64) !void {
    try writer.print(compact_summary_format, .{ output_path, version, duration_ms });
}

fn logCompactSummary(output_path: []const u8, version: []const u8, duration_ms: i64) void {
    std.debug.print("{s}" ++ compact_summary_format ++ "{s}\n", .{
        color.bright_green,
        output_path,
        version,
        duration_ms,
        color.reset,
    });
}

/// Prints the tool's version from embedded package.json
pub fn printToolVersion(allocator: std.mem.Allocator) !void {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, embedded_package_json, .{});
    defer parsed.deinit();

    const version = parsed.value.object.get("version").?.string;
    const name = parsed.value.object.get("name").?.string;

    logNewLine();
    log(color.bright_cyan, "📦", "{s}", .{name});
    log(color.bright_cyan, "📌", "Version: {s}", .{version});
    logNewLine();
}

/// Structure to hold author information
pub const AuthorInfo = struct {
    name: []const u8,
    email: []const u8,
    url: []const u8,
};

/// Structure to hold git information
pub const GitInfo = struct {
    branch: []const u8,
    commit: []const u8,

    pub fn deinit(info: GitInfo, allocator: std.mem.Allocator) void {
        allocator.free(info.branch);
        allocator.free(info.commit);
    }
};

pub const GenerateOptions = struct {
    verbose: bool = false,
};

fn readFileAlloc(allocator: std.mem.Allocator, io: std.Io, path: []const u8, limit: std.Io.Limit) ![]u8 {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);

    var reader = file.reader(io, &.{});
    return reader.interface.allocRemaining(allocator, limit);
}

fn readGitFileAlloc(allocator: std.mem.Allocator, io: std.Io, git_path: []const u8, file_path: []const u8, limit: std.Io.Limit) !?[]u8 {
    const path = try std.fs.path.join(allocator, &.{ git_path, file_path });
    defer allocator.free(path);

    return readFileAlloc(allocator, io, path, limit) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
}

fn findPackedCommit(content: []const u8, ref_name: []const u8) ?[]const u8 {
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (line.len == 0 or line[0] == '#' or line[0] == '^') continue;

        var parts = std.mem.splitScalar(u8, line, ' ');
        const commit = parts.next() orelse continue;
        const ref = parts.next() orelse continue;
        if (std.mem.eql(u8, std.mem.trim(u8, ref, "\r"), ref_name)) return commit;
    }
    return null;
}

fn readOwnedCommit(allocator: std.mem.Allocator, io: std.Io, git_path: []const u8, ref_name: []const u8) !?[]const u8 {
    if (try readGitFileAlloc(allocator, io, git_path, ref_name, .limited(1024))) |content| {
        defer allocator.free(content);
        return try allocator.dupe(u8, std.mem.trim(u8, content, " \n\r\t"));
    }

    const packed_refs = try readGitFileAlloc(allocator, io, git_path, "packed-refs", .limited(1024 * 1024)) orelse return null;
    defer allocator.free(packed_refs);

    const commit = findPackedCommit(packed_refs, ref_name) orelse return null;
    return try allocator.dupe(u8, commit);
}

fn initGitInfo(allocator: std.mem.Allocator, branch: []const u8, owned_commit: []const u8) !GitInfo {
    errdefer allocator.free(owned_commit);
    return .{
        .branch = try allocator.dupe(u8, branch),
        .commit = owned_commit,
    };
}

/// Reads the current git branch and commit hash from a Git directory.
/// Returns null if the directory is not a Git repository.
/// The caller owns the returned strings and must free them with `GitInfo.deinit`.
pub fn getGitInfo(allocator: std.mem.Allocator, io: std.Io, git_path: []const u8) !?GitInfo {
    const head_content = try readGitFileAlloc(allocator, io, git_path, "HEAD", .limited(1024)) orelse return null;
    defer allocator.free(head_content);

    const head = std.mem.trim(u8, head_content, " \n\r\t");
    if (!std.mem.startsWith(u8, head, "ref: ")) {
        return try initGitInfo(allocator, "HEAD", try allocator.dupe(u8, head));
    }

    const ref_name = head["ref: ".len..];
    const commit = try readOwnedCommit(allocator, io, git_path, ref_name) orelse return null;
    const branch = if (std.mem.startsWith(u8, ref_name, "refs/heads/"))
        ref_name["refs/heads/".len..]
    else
        "unknown";

    return try initGitInfo(allocator, branch, commit);
}

fn getAuthor(package: std.json.Value) ?AuthorInfo {
    const author = package.object.get("author") orelse return null;
    if (author != .object) return null;

    const name = author.object.get("name") orelse return null;
    return .{
        .name = name.string,
        .email = if (author.object.get("email")) |email| email.string else "",
        .url = if (author.object.get("url")) |url| url.string else "",
    };
}

fn writeVersionInfo(writer: anytype, version: []const u8, date_str: []const u8, author_info: ?AuthorInfo, git_info: ?GitInfo) !void {
    try writer.writeAll(
        \\/**
        \\ * Generated by script 🍺
        \\ * Do not edit manually.
        \\ */
        \\
        \\export const VERSION_INFO = {
        \\
    );
    try writer.print("  version: \"{s}\",\n", .{version});
    try writer.print("  date: \"{s}\"", .{date_str});

    if (author_info) |author| {
        try writer.writeAll(",\n  author: {\n");
        try writer.print("    name: \"{s}\",\n", .{author.name});
        try writer.print("    email: \"{s}\",\n", .{author.email});
        try writer.print("    url: \"{s}\"\n", .{author.url});
        try writer.writeAll("  }");
    }

    if (git_info) |info| {
        try writer.writeAll(",\n  git: {\n");
        try writer.print("    branch: \"{s}\",\n", .{info.branch});
        try writer.print("    commit: \"{s}\"\n", .{info.commit});
        try writer.writeAll("  }");
    }

    try writer.writeAll("\n};\n");
}

/// Formats a Unix timestamp in milliseconds to ISO 8601 format (YYYY-MM-DDTHH:MM:SS.sssZ)
fn formatTimestampISO8601(buffer: []u8, millis: i64) ![]const u8 {
    const epoch: std.time.epoch.EpochSeconds = .{
        .secs = @intCast(@divTrunc(millis, std.time.ms_per_s)),
    };
    const year_day = epoch.getEpochDay().calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const day_seconds = epoch.getDaySeconds();

    return std.fmt.bufPrint(buffer, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}Z", .{
        year_day.year,
        month_day.month.numeric(),
        month_day.day_index + 1,
        day_seconds.getHoursIntoDay(),
        day_seconds.getMinutesIntoHour(),
        day_seconds.getSecondsIntoMinute(),
        @as(u16, @intCast(@mod(millis, std.time.ms_per_s))),
    });
}

/// Generates a version-info.ts file from package.json
pub fn generateVersionInfo(allocator: std.mem.Allocator, io: std.Io, package_json_path: []const u8, output_path: []const u8, git_path: []const u8) !void {
    return generateVersionInfoWithOptions(allocator, io, package_json_path, output_path, git_path, .{});
}

/// Generates a version-info.ts file from package.json with configurable logging.
pub fn generateVersionInfoWithOptions(
    allocator: std.mem.Allocator,
    io: std.Io,
    package_json_path: []const u8,
    output_path: []const u8,
    git_path: []const u8,
    options: GenerateOptions,
) !void {
    const start_time = std.Io.Clock.awake.now(io);
    if (options.verbose) {
        logNewLine();
        log(color.yellow, "🚀", "Starting version info generation...", .{});

        logNewLine();
        log(color.blue, "📖", "Reading {s}...", .{package_json_path});
    }
    const cwd = std.Io.Dir.cwd();
    const file_content = try readFileAlloc(allocator, io, package_json_path, .limited(1024 * 1024));
    defer allocator.free(file_content);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, file_content, .{});
    defer parsed.deinit();

    const version = parsed.value.object.get("version").?.string;
    if (options.verbose) {
        log(color.blue, "📦", "Version: {s}", .{version});

        logNewLine();
        log(color.bright_blue, "👤", "Reading author info...", .{});
    }
    const author_info = getAuthor(parsed.value);
    if (options.verbose) {
        if (author_info) |author| {
            log(color.bright_blue, "✍️ ", "Name: {s}", .{author.name});
            if (author.email.len > 0) log(color.bright_blue, "📧", "Email: {s}", .{author.email});
            if (author.url.len > 0) log(color.bright_blue, "🔗", "URL: {s}", .{author.url});
        } else {
            log(color.yellow, "⚠️ ", "No author info found in package.json", .{});
        }

        logNewLine();
        log(color.cyan, "⏰", "Generating timestamp...", .{});
    }

    const millis = std.Io.Clock.real.now(io).toMilliseconds();
    var date_buffer: [30]u8 = undefined;
    const date_str = try formatTimestampISO8601(&date_buffer, millis);
    if (options.verbose) {
        log(color.cyan, "📅", "Date: {s}", .{date_str});

        logNewLine();
        log(color.bright_magenta, "🌿", "Reading git info...", .{});
    }
    const git_info = try getGitInfo(allocator, io, git_path);
    defer if (git_info) |info| info.deinit(allocator);

    if (options.verbose) {
        if (git_info) |info| {
            log(color.bright_magenta, "📍", "Branch: {s}", .{info.branch});
            log(color.bright_magenta, "🔖", "Commit: {s}", .{info.commit});
        } else {
            log(color.yellow, "⚠️ ", "Not a git repository (git info skipped)", .{});
        }

        logNewLine();
        log(color.bright_green, "✍️ ", "Writing to {s}...", .{output_path});
    }

    if (std.fs.path.dirname(output_path)) |dir_path| {
        try cwd.createDirPath(io, dir_path);
    }

    const output_file = try cwd.createFile(io, output_path, .{});
    defer output_file.close(io);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = output_file.writer(io, &stdout_buffer);
    const writer = &stdout_writer.interface;

    try writeVersionInfo(writer, version, date_str, author_info, git_info);

    try writer.flush();

    const end_time = std.Io.Clock.awake.now(io);
    const duration_ms = start_time.durationTo(end_time).toMilliseconds();
    if (options.verbose) {
        log(color.bright_green, "✅", "Successfully generated {s}", .{output_path});
        logNewLine();
        log(color.yellow, "⏱️ ", "Duration: {d}ms", .{duration_ms});
        logNewLine();
    } else {
        logCompactSummary(output_path, version, duration_ms);
    }
}

test "formats Unix epoch as ISO 8601" {
    var buffer: [30]u8 = undefined;
    try std.testing.expectEqualStrings(
        "1970-01-01T00:00:00.000Z",
        try formatTimestampISO8601(&buffer, 0),
    );
}

test "formats leap day as ISO 8601" {
    var buffer: [30]u8 = undefined;
    try std.testing.expectEqualStrings(
        "2024-02-29T12:34:56.789Z",
        try formatTimestampISO8601(&buffer, 1_709_210_096_789),
    );
}

test "finds commit in packed refs" {
    const packed_refs =
        \\# pack-refs with: peeled fully-peeled sorted
        \\1111111111111111111111111111111111111111 refs/heads/main
        \\^2222222222222222222222222222222222222222
        \\3333333333333333333333333333333333333333 refs/heads/release
    ;

    try std.testing.expectEqualStrings(
        "3333333333333333333333333333333333333333",
        findPackedCommit(packed_refs, "refs/heads/release").?,
    );
    try std.testing.expectEqual(null, findPackedCommit(packed_refs, "refs/heads/missing"));
}

test "writes compact generation summary" {
    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try writeCompactSummary(&output.writer, "generated/version-info.ts", "0.0.0", 2);
    try std.testing.expectEqualStrings(
        "✅ Generated generated/version-info.ts (v0.0.0, 2ms)",
        output.writer.buffered(),
    );
}

test "writes complete TypeScript file" {
    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try writeVersionInfo(
        &output.writer,
        "1.2.3",
        "2026-07-16T12:34:56.789Z",
        .{ .name = "Name", .email = "mail@example.com", .url = "https://example.com" },
        .{ .branch = "main", .commit = "abc123" },
    );

    try std.testing.expectEqualStrings(
        \\/**
        \\ * Generated by script 🍺
        \\ * Do not edit manually.
        \\ */
        \\
        \\export const VERSION_INFO = {
        \\  version: "1.2.3",
        \\  date: "2026-07-16T12:34:56.789Z",
        \\  author: {
        \\    name: "Name",
        \\    email: "mail@example.com",
        \\    url: "https://example.com"
        \\  },
        \\  git: {
        \\    branch: "main",
        \\    commit: "abc123"
        \\  }
        \\};
        \\
    , output.writer.buffered());
}
