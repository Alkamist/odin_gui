const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "pugl",
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();

    var gen_step = std.build.Step.WriteFile.create(b);
    lib.step.dependOn(&gen_step.step);

    switch (target.getOsTag()) {
        .windows => {
            lib.addCSourceFile("pugl-main/src/win.c", &[_][]const u8{});
            lib.addCSourceFile("pugl-main/src/win_gl.c", &[_][]const u8{});
        },
        else => {
            @panic("Unsupported OS");
        },
    }

    lib.addCSourceFile("pugl-main/src/common.c", &[_][]const u8{});
    lib.addCSourceFile("pugl-main/src/internal.c", &[_][]const u8{});

    lib.addIncludePath("pugl-main/include");

    lib.defineCMacro("PUGL_STATIC", null);

    b.installArtifact(lib);
}

const srcdir = struct {
    fn getSrcDir() []const u8 {
        return std.fs.path.dirname(@src().file).?;
    }
}.getSrcDir();
