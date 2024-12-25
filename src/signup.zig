const std = @import("std");
const zap = @import("zap");
const pg = @import("pg");

pub const SignupError = error{ InvalidRequest, DatabaseError, UserExists };

pub fn handleSignupRequest(r: zap.Request) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Parse JSON body
    const body = r.body orelse {
        try r.sendJson(.{ .@"error" = "Invalid request body" });
        return;
    };

    // Validate and parse request
    const signup_data = std.json.parseFromSlice(SignupRequest, allocator, body, .{}) catch {
        try r.sendJson(.{ .@"error" = "Invalid JSON format" });
        return;
    };
    defer signup_data.deinit();

    // Perform signup logic
    const result = performSignup(allocator, signup_data.value.name, signup_data.value.email, signup_data.value.password) catch |err| {
        switch (err) {
            SignupError.UserExists => {
                try r.sendJson(.{ .@"error" = "User already exists" });
            },
            else => {
                try r.sendJson(.{ .@"error" = "Signup failed" });
            },
        }
        return;
    };

    // Successful response
    try r.sendJson(.{ .message = "User created successfully", .email = result.email });
}

const SignupRequest = struct {
    name: []const u8,
    email: []const u8,
    password: []const u8,
};

fn performSignup(allocator: std.mem.Allocator, name: []const u8, email: []const u8, password: []const u8) !struct { email: []const u8 } {
    // Database connection
    var pool = try pg.Pool.init(allocator, .{ .size = 5, .connect = .{
        .host = std.os.getenv("PGHOST") orelse "localhost",
        .port = std.fmt.parseInt(u16, std.os.getenv("PGPORT") orelse "5432", 10) catch 5432,
    }, .auth = .{
        .username = std.os.getenv("PGUSER") orelse "postgres",
        .database = std.os.getenv("PGDATABASE") orelse "userdb",
        .password = std.os.getenv("PGPASSWORD") orelse return SignupError.DatabaseError,
    } });
    defer pool.deinit();

    // Check user existence
    const existing_user = try pool.query("SELECT * FROM users WHERE email = $1", .{email});
    defer existing_user.deinit();

    if ((try existing_user.next()) != null) {
        return SignupError.UserExists;
    }

    // Insert new user
    _ = try pool.exec("INSERT INTO users (name, email, password) VALUES ($1, $2, $3)", .{ name, email, password });

    return .{ .email = email };
}
