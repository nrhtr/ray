const std = @import("std");
const fs = std.fs;
const print = std.debug.print;

pub fn Point3(comptime T: type) type {
    return struct {
        const Self = @This();
        x: T,
        y: T,
        z: T,

        // Shortcut constructor
        pub fn v(x: T, y: T, z: T) Self {
            return Point3(T){
                .x = x,
                .y = y,
                .z = z,
            };
        }

        pub fn add(left: *const Self, right: *const Self) Self {
            return Point3(T){
                .x = left.x + right.x,
                .y = left.y + right.y,
                .z = left.z + right.z,
            };
        }

        pub fn sub(left: *const Self, right: *const Self) Vec3(T) {
            return Vec3(T){
                .x = left.x - right.x,
                .y = left.y - right.y,
                .z = left.z - right.z,
            };
        }

        pub fn mul(vec: *const Self, scale: T) Vec3(T) {
            return Vec3(T){
                .x = vec.x * scale,
                .y = vec.y * scale,
                .z = vec.z * scale,
            };
        }

        pub fn length(vec: *const Self) T {
            const m = std.math;
            return m.sqrt(m.pow(T, vec.x, 2) + m.pow(T, vec.y, 2) + m.pow(T, vec.z, 2));
        }

        pub fn unit(vec: *const Self) Self {
            return vec.mul(-vec.length());
        }
    };
}

const Vec3 = Point3;
const Colour = Point3(f32);

const Sphere = struct {
    radius: f32,
};

const Ray = struct {
    origin: Point3(f32),
    direction: Vec3(f32),

    pub fn at(self: Ray, t: f64) Point3(f32) {
        // P(t)=A+tb
        return self.origin.add(self.direction.mul(t));
    }

    pub fn colour(self: Ray) Colour {
        const unit_dir = self.direction.unit();
        const t = 0.5 * (unit_dir.y + 1.0);

        const end = Colour{ .x = 0.5, .y = 0.7, .z = 1.0 };
        const start = Colour{ .x = 0, .y = 0, .z = 1 };

        //return Colour{ .x = 1, .y = 0, .z = 1 };
        return start.mul(1.0 - t).add(&end.mul(t));
    }
};

const Mesh = struct {
    vertices: std.ArrayList(Point3(f32)),
    indices: [*]usize,

    pub fn load(filename: []const u8) !Mesh {
        var verts: std.ArrayList(Point3((f32))) = undefined;
        var indices: [*]usize = undefined;

        const f = try fs.cwd().openFile(filename, fs.File.OpenFlags{ .read = true });
        defer f.close();

        const io = std.io;
        var buf_reader = io.bufferedReader(f.reader());
        var in_stream = buf_reader.reader();
        var buffer: [1024]u8 = undefined;

        // Read
        while (try in_stream.readUntilDelimiterOrEof(buffer[0..], '\n')) |line| {
            switch (line[0]) {
                // Vertex
                'v' => {
                    var lptr = line[1..];
                    var split = std.mem.split(line, " ");
                    while (split.next()) |part| {
                        print("part: {}\n", .{part});
                    }
                    //const x = std.fmt.parseFloat(f32, line);
                    //print("Vertex: {}\n", .{line});
                },
                // Face
                'f' => {},
                else => {},
            }
        }

        return Mesh{
            .vertices = undefined,
            .indices = undefined,
        };
    }
};

pub fn write_colour(f: std.fs.File, c: Colour) !void {
    const w = f.writer();
    try w.print("{} {} {}\n", .{ @floatToInt(i32, 255.999 * c.x), @floatToInt(i32, 255.999 * c.y), @floatToInt(i32, 255.999 * c.z) });
}

pub fn main() anyerror!void {
    const stdout_file = std.io.getStdOut();
    const stdout = std.io.getStdOut().writer();

    const aspect_ratio = 16.0 / 9.0;
    const image_width = 400;
    const image_height = @floatToInt(i32, image_width / aspect_ratio);

    const viewport_height = 2.0;
    const viewport_width = viewport_height * aspect_ratio;
    const focal_length = 1.0;

    //const origin = Point3(f32).v(0, 0, 0);
    const origin = Point3(f32){ .x = 0, .y = 0, .z = 0 };
    const horizontal = Vec3(f32){ .x = viewport_width, .y = 0, .z = 0 };
    const vertical = Vec3(f32){ .x = 0, .y = viewport_height, .z = 0 };

    const hor_2 = horizontal.mul(0.5);
    const ver_2 = vertical.mul(0.5);
    const lower_left_corner = origin.sub(&hor_2).sub(&ver_2).sub(&Vec3(f32).v(0, 0, focal_length));

    try stdout.print("P3\n{} {}\n255\n", .{ image_width, image_height });

    var j: i32 = 0;
    while (j < image_height) : (j += 1) {
        var i: i32 = 0;
        while (i < image_width) : (i += 1) {
            const fi: f32 = @intToFloat(f32, i);
            const fj: f32 = @intToFloat(f32, j);
            const u: f32 = fi / @intToFloat(f32, (image_width - 1));
            const v: f32 = fj / @intToFloat(f32, (image_height - 1));
            //print("({},{}) ", .{ i, j });
            const target = lower_left_corner.add(&vertical.mul(v)).add(&horizontal.mul(u)).sub(&origin);
            const ray = Ray{ .origin = origin, .direction = target };
            const pixel_colour = ray.colour();
            try write_colour(stdout_file, pixel_colour);
        }
    }
}
