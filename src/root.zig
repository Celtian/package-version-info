//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

const embedded_package_json = @embedFile("package.json");

const Color = struct {
    pub const RESET = "\x1b[0m";
    pub const BOLD = "\x1b[1m";
    pub const RED = "\x1b[31m";
    pub const GREEN = "\x1b[32m";
    pub const YELLOW = "\x1b[33m";
    pub const BLUE = "\x1b[34m";
    pub const MAGENTA = "\x1b[35m";
    pub const CYAN = "\x1b[36m";
    pub const WHITE = "\x1b[37m";
    pub const BRIGHT_GREEN = "\x1b[92m";
    pub const BRIGHT_BLUE = "\x1b[94m";
    pub const BRIGHT_MAGENTA = "\x1b[95m";
    pub const BRIGHT_CYAN = "\x1b[96m";
};

/// Helper function for colored logging
fn log(comptime color: []const u8, comptime emoji: []const u8, comptime fmt: []const u8, args: anytype) void {
    std.debug.print("{s}" ++ emoji ++ " " ++ fmt ++ "{s}\n", .{color} ++ args ++ .{Color.RESET});
}

/// Helper function for printing empty line
fn logNewLine() void {
    std.debug.print("\n", .{});
}

/// Prints the tool's version from embedded package.json
pub fn printToolVersion(allocator: std.mem.Allocator) !void {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, embedded_package_json, .{});
    defer parsed.deinit();

    const version = parsed.value.object.get("version").?.string;
    const name = parsed.value.object.get("name").?.string;

    logNewLine();
    log(Color.BRIGHT_CYAN, "📦", "{s}", .{name});
    log(Color.BRIGHT_CYAN, "📌", "Version: {s}", .{version});
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
};

/// Reads the current git branch and commit hash from a Git directory.
/// Returns null if the directory is not a Git repository.
pub fn getGitInfo(allocator: std.mem.Allocator, io: std.Io, git_path: []const u8) !?GitInfo {
    const head_path = try std.fs.path.join(allocator, &.{ git_path, "HEAD" });
    defer allocator.free(head_path);

    const cwd = std.Io.Dir.cwd();
    const head_file = cwd.openFile(io, head_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            return null; // Not a git repository
        }
        return err;
    };
    defer head_file.close(io);

    var head_reader = head_file.reader(io, &.{});
    const head_content = try head_reader.interface.allocRemaining(allocator, .limited(1024));
    defer allocator.free(head_content);

    // Parse the ref from HEAD (format: "ref: refs/heads/branch-name\n")
    const head_trimmed = std.mem.trim(u8, head_content, " \n\r\t");

    var branch: []const u8 = "unknown";
    var ref_path_raw: []const u8 = undefined;

    if (std.mem.startsWith(u8, head_trimmed, "ref: ")) {
        ref_path_raw = head_trimmed[5..]; // Skip "ref: " prefix

        // Extract branch name from refs/heads/branch-name
        if (std.mem.startsWith(u8, ref_path_raw, "refs/heads/")) {
            branch = ref_path_raw[11..]; // Skip "refs/heads/"
        }

        const ref_path = try std.fs.path.join(allocator, &.{ git_path, ref_path_raw });
        defer allocator.free(ref_path);

        // Try to read the commit hash from the ref file
        var commit_owned: []const u8 = undefined;

        if (cwd.openFile(io, ref_path, .{})) |ref_file| {
            defer ref_file.close(io);
            var ref_reader = ref_file.reader(io, &.{});
            const commit_content = try ref_reader.interface.allocRemaining(allocator, .limited(1024));
            defer allocator.free(commit_content);
            const commit = std.mem.trim(u8, commit_content, " \n\r\t");
            commit_owned = try allocator.dupe(u8, commit);
        } else |err| {
            if (err == error.FileNotFound) {
                // Ref file not found, try packed-refs
                const packed_refs_path = try std.fs.path.join(allocator, &.{ git_path, "packed-refs" });
                defer allocator.free(packed_refs_path);
                const packed_refs_file = cwd.openFile(io, packed_refs_path, .{}) catch |packed_err| {
                    if (packed_err == error.FileNotFound) {
                        return null; // Neither individual ref nor packed-refs found
                    }
                    return packed_err;
                };
                defer packed_refs_file.close(io);

                var packed_reader = packed_refs_file.reader(io, &.{});
                const packed_content = try packed_reader.interface.allocRemaining(allocator, .limited(1024 * 1024));
                defer allocator.free(packed_content);

                // Search for the ref in packed-refs format: "<commit> <ref>\n"
                var lines = std.mem.splitScalar(u8, packed_content, '\n');
                while (lines.next()) |line| {
                    if (line.len == 0 or line[0] == '#' or line[0] == '^') continue;

                    var parts = std.mem.splitScalar(u8, line, ' ');
                    const commit_hash = parts.next() orelse continue;
                    const ref_name = parts.next() orelse continue;

                    if (std.mem.eql(u8, ref_name, ref_path_raw)) {
                        const commit = std.mem.trim(u8, commit_hash, " \n\r\t");
                        commit_owned = try allocator.dupe(u8, commit);
                        break;
                    }
                } else {
                    return null; // Ref not found in packed-refs
                }
            } else {
                return err;
            }
        }

        return GitInfo{
            .branch = try allocator.dupe(u8, branch),
            .commit = commit_owned,
        };
    } else {
        // Detached HEAD state - HEAD contains the commit hash directly
        return GitInfo{
            .branch = try allocator.dupe(u8, "HEAD"),
            .commit = try allocator.dupe(u8, head_trimmed),
        };
    }
}

fn writeTypescriptHeader(writer: anytype) !void {
    try writer.writeAll("/**\n");
    try writer.writeAll(" * Generated by script 🍺\n");
    try writer.writeAll(" * Do not edit manually.\n");
    try writer.writeAll(" */\n\n");
}

/// Writes the VERSION_INFO export statement to the output
fn writeVersionInfo(writer: anytype, version: []const u8, date_str: []const u8, author_info: ?AuthorInfo, git_info: ?GitInfo) !void {
    try writer.print("export const VERSION_INFO = {{\n", .{});
    try writer.print("  version: \"{s}\",\n", .{version});
    try writer.print("  date: \"{s}\"", .{date_str});

    if (author_info) |author| {
        try writer.print(",\n", .{});
        try writer.print("  author: {{\n", .{});
        try writer.print("    name: \"{s}\",\n", .{author.name});
        try writer.print("    email: \"{s}\",\n", .{author.email});
        try writer.print("    url: \"{s}\"\n", .{author.url});
        try writer.print("  }}", .{});
    }

    if (git_info) |info| {
        try writer.print(",\n", .{});
        try writer.print("  git: {{\n", .{});
        try writer.print("    branch: \"{s}\",\n", .{info.branch});
        try writer.print("    commit: \"{s}\"\n", .{info.commit});
        try writer.print("  }}", .{});
    }

    try writer.print("\n}};\n", .{});
}

/// Formats a Unix timestamp in milliseconds to ISO 8601 format (YYYY-MM-DDTHH:MM:SS.sssZ)
fn formatTimestampISO8601(buffer: []u8, millis: i64) ![]const u8 {
    const seconds = @divTrunc(millis, 1000);
    const ms = @mod(millis, 1000);

    // Calculate date components from Unix timestamp
    const seconds_per_day: i64 = 86400;
    const days_since_epoch = @divTrunc(seconds, seconds_per_day);
    const seconds_today = @mod(seconds, seconds_per_day);

    // Unix epoch is 1970-01-01, which is day 719468 in the proleptic Gregorian calendar
    const days_from_0 = days_since_epoch + 719468;

    // Calculate year, month, day using algorithm
    const era = @divTrunc(days_from_0, 146097);
    const doe = @mod(days_from_0, 146097);
    const yoe = @divTrunc(doe - @divTrunc(doe, 1460) + @divTrunc(doe, 36524) - @divTrunc(doe, 146096), 365);
    const y = yoe + era * 400;
    const doy = doe - (365 * yoe + @divTrunc(yoe, 4) - @divTrunc(yoe, 100));
    const mp = @divTrunc(5 * doy + 2, 153);
    const d = doy - @divTrunc(153 * mp + 2, 5) + 1;
    const m = if (mp < 10) mp + 3 else mp - 9;
    const year = if (m <= 2) y + 1 else y;

    const hours = @divTrunc(seconds_today, 3600);
    const minutes = @divTrunc(@mod(seconds_today, 3600), 60);
    const secs = @mod(seconds_today, 60);

    return try std.fmt.bufPrint(buffer, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}Z", .{
        @as(u32, @intCast(year)),  @as(u32, @intCast(m)),       @as(u32, @intCast(d)),
        @as(u32, @intCast(hours)), @as(u32, @intCast(minutes)), @as(u32, @intCast(secs)),
        @as(u32, @intCast(ms)),
    });
}

/// Generates a version-info.ts file from package.json
pub fn generateVersionInfo(allocator: std.mem.Allocator, io: std.Io, package_json_path: []const u8, output_path: []const u8, git_path: []const u8) !void {
    const start_time = std.Io.Clock.awake.now(io);
    logNewLine();
    log(Color.YELLOW, "🚀", "Starting version info generation...", .{});

    logNewLine();
    log(Color.BLUE, "📖", "Reading {s}...", .{package_json_path});
    const cwd = std.Io.Dir.cwd();
    const file = try cwd.openFile(io, package_json_path, .{});
    defer file.close(io);

    var file_reader = file.reader(io, &.{});
    const file_content = try file_reader.interface.allocRemaining(allocator, .limited(1024 * 1024));
    defer allocator.free(file_content);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, file_content, .{});
    defer parsed.deinit();

    const version = parsed.value.object.get("version").?.string;
    log(Color.BLUE, "📦", "Version: {s}", .{version});

    logNewLine();
    log(Color.BRIGHT_BLUE, "👤", "Reading author info...", .{});
    var author_info: ?AuthorInfo = null;
    if (parsed.value.object.get("author")) |author_value| {
        if (author_value == .object) {
            const author_obj = author_value.object;
            if (author_obj.get("name")) |name| {
                const author_name = name.string;
                const author_email = if (author_obj.get("email")) |email| email.string else "";
                const author_url = if (author_obj.get("url")) |url| url.string else "";

                author_info = AuthorInfo{
                    .name = author_name,
                    .email = author_email,
                    .url = author_url,
                };

                log(Color.BRIGHT_BLUE, "✍️ ", "Name: {s}", .{author_name});
                if (author_email.len > 0) {
                    log(Color.BRIGHT_BLUE, "📧", "Email: {s}", .{author_email});
                }
                if (author_url.len > 0) {
                    log(Color.BRIGHT_BLUE, "🔗", "URL: {s}", .{author_url});
                }
            }
        }
    }
    if (author_info == null) {
        log(Color.YELLOW, "⚠️ ", "No author info found in package.json", .{});
    }

    logNewLine();
    log(Color.CYAN, "⏰", "Generating timestamp...", .{});
    const millis = std.Io.Clock.real.now(io).toMilliseconds();
    var date_buffer: [30]u8 = undefined;
    const date_str = try formatTimestampISO8601(&date_buffer, millis);
    log(Color.CYAN, "📅", "Date: {s}", .{date_str});

    logNewLine();
    log(Color.BRIGHT_MAGENTA, "🌿", "Reading git info...", .{});
    const git_info = try getGitInfo(allocator, io, git_path);

    if (git_info) |info| {
        log(Color.BRIGHT_MAGENTA, "📍", "Branch: {s}", .{info.branch});
        log(Color.BRIGHT_MAGENTA, "🔖", "Commit: {s}", .{info.commit});
    } else {
        log(Color.YELLOW, "⚠️ ", "Not a git repository (git info skipped)", .{});
    }

    logNewLine();
    log(Color.BRIGHT_GREEN, "✍️ ", "Writing to {s}...", .{output_path});

    // Ensure parent directory exists
    if (std.fs.path.dirname(output_path)) |dir_path| {
        try cwd.createDirPath(io, dir_path);
    }

    const output_file = try cwd.createFile(io, output_path, .{});
    defer output_file.close(io);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = output_file.writer(io, &stdout_buffer);
    const writer = &stdout_writer.interface;

    try writeTypescriptHeader(writer);
    try writeVersionInfo(writer, version, date_str, author_info, git_info);

    try writer.flush();

    // Free git_info memory after writing
    if (git_info) |info| {
        allocator.free(info.branch);
        allocator.free(info.commit);
    }

    const end_time = std.Io.Clock.awake.now(io);
    const duration_ms = start_time.durationTo(end_time).toMilliseconds();
    log(Color.BRIGHT_GREEN, "✅", "Successfully generated {s}", .{output_path});
    logNewLine();
    log(Color.YELLOW, "⏱️ ", "Duration: {d}ms", .{duration_ms});
    logNewLine();
}
