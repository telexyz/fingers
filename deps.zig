const std = @import("std");
const Pkg = std.build.Pkg;
const FileSource = std.build.FileSource;

pub const pkgs = struct {
    pub const wapc = Pkg{
        .name = "wapc",
        .path = FileSource{
            .path = ".gyro/wapc-guest-zig-trashhalo-github.com-ef669c24/pkg/wapc.zig",
        },
    };

    pub fn addAllTo(artifact: *std.build.LibExeObjStep) void {
        artifact.addPackage(pkgs.wapc);
    }
};

pub const exports = struct {
    pub const @"create-zig-wasm-app" = Pkg{
        .name = "create-zig-wasm-app",
        .path = "src/main.zig",
        .dependencies = &[_]Pkg{
            pkgs.wapc,
        },
    };
};
