const std = @import("std");
const zap = @import("zap");
const signup = @import("signup.zig");

// Route handler for signup
fn handleSignup(r: zap.Request) !void {
    // Delegate to signup module's signup handler
    try signup.handleSignupRequest(r);
}

pub fn main() !void {
    // Create route for /users/signup
    var router = zap.Router.init(.{
        .log = true,
    });
    defer router.deinit();

    // Define route with specific path
    router.add(.{ .path = "/users/signup", .method = .POST, .handler = handleSignup });

    // Create listener
    var listener = zap.HttpListener.init(.{
        .port = 8080,
        .router = router,
        .log = true,
    });

    try listener.listen();

    // Start worker threads
    zap.start(.{
        .threads = 2,
        .workers = 1,
    });
}
