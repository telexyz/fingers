const std = @import("std");

const packages = @import("deps.zig");

pub fn build(b: *std.build.Builder) void {
    const lib = b.addSharedLibrary("telexyz", "main.zig", .unversioned);
    packages.pkgs.addAllTo(lib);
    lib.setBuildMode(.ReleaseSmall);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.install();
}
