const std = @import("std");
const rl = @import("raylib");

const WIDTH = 1000;
const HEIGHT = 800;

const CELL_SIZE = 5;

const WORLD_WIDTH = WIDTH / CELL_SIZE;
const WORLD_HEIGHT = HEIGHT / CELL_SIZE;

const Terrain = enum {
    Undefined,
    Mountains,
    Forest,
    Plains,
    Water,
    DeepWater,
    HighMountains,
    Desert,

    const types: usize = 7;

    fn color(self: Terrain) rl.Color {
        return switch (self) {
            .Undefined => rl.Color.black,
            .Mountains => rl.Color.gray,
            .Forest => rl.Color.dark_green,
            .Plains => rl.Color.green,
            .Water => rl.Color.blue,
            .DeepWater => rl.Color.dark_blue,
            .HighMountains => rl.Color.white,
            .Desert => rl.Color.orange,
        };
    }

    fn isCompatibleWith(self: Terrain, other: Terrain) bool {
        return switch (self) {
            .Undefined => true,
            .Mountains => switch (other) {
                .Undefined, .Mountains, .HighMountains, .Forest => true,
                else => false,
            },
            .Forest => switch (other) {
                .Undefined, .Mountains, .Forest, .Plains => true,
                else => false,
            },
            .Plains => switch (other) {
                .Undefined, .Plains, .Water, .Forest, .Desert => true,
                else => false,
            },
            .Water => switch (other) {
                .Undefined, .Water, .DeepWater, .Plains => true,
                else => false,
            },
            .DeepWater => switch (other) {
                .Undefined, .DeepWater, .Water => true,
                else => false,
            },
            .HighMountains => switch (other) {
                .Undefined, .HighMountains, .Mountains => true,
                else => false,
            },
            .Desert => switch (other) {
                .Undefined, .Desert, .Plains => true,
                else => false,
            },
        };
    }
};

const ThreadFuncArgs = struct {
    world: *[WORLD_WIDTH][WORLD_HEIGHT]Terrain,
    rand: std.rand.Random,
};

pub fn main() anyerror!void {
    const rand = std.crypto.random;

    rl.setConfigFlags(.{ .window_resizable = false });
    rl.initWindow(WIDTH, HEIGHT, "Procedural maps");
    defer rl.closeWindow();

    var world: [WORLD_WIDTH][WORLD_HEIGHT]Terrain = undefined;
    for (world, 0..) |row, x| {
        for (row, 0..) |_, y| {
            world[x][y] = .Undefined;
            if (@sqrt(std.math.pow(f32, @as(f32, @floatFromInt(x)) - WORLD_WIDTH * 0.5, 2) +
                std.math.pow(f32, @as(f32, @floatFromInt(y)) - WORLD_HEIGHT * 0.5, 2)) > 75.0)
            {
                world[x][y] = .DeepWater;
            }
        }
    }

    const camera = rl.Camera2D{
        .zoom = 1,
        .offset = .{ .x = 0.0, .y = 0.0 },
        .target = .{ .x = WIDTH / 2.0, .y = HEIGHT / 2.0 },
        .rotation = 0,
    };

    const args = ThreadFuncArgs{
        .world = &world,
        .rand = rand,
    };

    rl.setTargetFPS(60);
    _ = try std.Thread.spawn(.{}, run, .{args});

    while (!rl.windowShouldClose()) {
        rl.beginMode2D(camera);
        defer rl.endMode2D();
        rl.beginDrawing();
        defer rl.endDrawing();

        for (world, 0..) |row, x| {
            for (row, 0..) |cell, y| {
                rl.drawRectangle(
                    @as(i32, @intCast(x * CELL_SIZE)),
                    @as(i32, @intCast(y * CELL_SIZE)),
                    @as(i32, CELL_SIZE),
                    @as(i32, CELL_SIZE),
                    cell.color(),
                );
            }
        }
    }
}

fn run(args: ThreadFuncArgs) void {
    while (!generateMap(args.rand, args.world)) {}
}

fn generateMap(rand: std.rand.Random, world: *[WORLD_WIDTH][WORLD_HEIGHT]Terrain) bool {
    var finished = true;
    var x: usize = undefined;
    var y: usize = undefined;
    var conflicts: i32 = undefined;
    const tries: usize = 20;

    for (WORLD_WIDTH * WORLD_HEIGHT) |_| {
        x = rand.uintLessThan(usize, WORLD_WIDTH);
        y = rand.uintLessThan(usize, WORLD_HEIGHT);

        conflicts = checkConflicts(x, y, world.*);
        if (conflicts > 0 or world.*[x][y] == .Undefined) {
            finished = false;
            var best_type: Terrain = .Undefined;
            var least_conflicts: i32 = std.math.maxInt(i32);
            var temp_t: Terrain = .Undefined;
            var temp_c: i32 = undefined;
            for (0..tries) |_| {
                temp_t = @enumFromInt(1 + rand.uintLessThan(usize, Terrain.types));
                world.*[x][y] = temp_t;
                temp_c = checkConflicts(x, y, world.*);

                if (temp_c < least_conflicts) {
                    best_type = temp_t;
                    least_conflicts = temp_c;
                }
            }
            world.*[x][y] = best_type;
        }
    }
    return finished;
}
fn checkConflicts(x: usize, y: usize, world: [WORLD_WIDTH][WORLD_HEIGHT]Terrain) i32 {
    var conflicts: i32 = 0;
    const range: isize = 3;

    var dx: isize = -range;
    var dy: isize = -range;
    while (dx <= range) : (dx += 1) {
        while (dy <= range) : (dy += 1) {
            const tx = @mod((dx + @as(isize, (@intCast(x))) + WORLD_WIDTH), WORLD_WIDTH);
            const ty = @mod((dy + @as(isize, (@intCast(y))) + WORLD_HEIGHT), WORLD_HEIGHT);

            if (!world[x][y].isCompatibleWith(world[@intCast(tx)][@intCast(ty)])) {
                conflicts += 1;
            }
        }
        dy = -range;
    }
    return conflicts;
}
