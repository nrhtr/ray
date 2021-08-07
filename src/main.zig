// Based on "Ray Tracing in One Weekend"
//
const std = @import("std");
const rand = std.rand;
const fs = std.fs;
const print = std.debug.print;
const m = std.math;

pub fn Vec3(comptime T: type) type {
    return struct {
        const Self = @This();

        x: T,
        y: T,
        z: T,

        pub fn init(x: T, y: T, z: T) Self {
            return Vec3(T){
                .x = x,
                .y = y,
                .z = z,
            };
        }

        pub fn plus(left: *const Self, right: *const Self) Self {
            return Vec3(T){
                .x = left.x + right.x,
                .y = left.y + right.y,
                .z = left.z + right.z,
            };
        }

        pub fn minus(left: *const Self, right: *const Self) Vec3(T) {
            return Vec3(T){
                .x = left.x - right.x,
                .y = left.y - right.y,
                .z = left.z - right.z,
            };
        }

        pub fn div(vec: *const Self, scale: T) Vec3(T) {
            return Vec3(T){
                .x = vec.x / scale,
                .y = vec.y / scale,
                .z = vec.z / scale,
            };
        }

        pub fn mul(vec: *const Self, scale: T) Vec3(T) {
            return Vec3(T){
                .x = vec.x * scale,
                .y = vec.y * scale,
                .z = vec.z * scale,
            };
        }

        pub fn dot(u: *const Self, v: *const Self) T {
            return u.x * v.x +
                u.y * v.y +
                u.z * v.z;
        }

        pub fn length(vec: *const Self) T {
            return m.sqrt(m.pow(T, vec.x, 2) + m.pow(T, vec.y, 2) + m.pow(T, vec.z, 2));
        }

        pub fn length_squared(vec: *const Self) T {
            return m.pow(T, vec.x, 2) + m.pow(T, vec.y, 2) + m.pow(T, vec.z, 2);
        }

        pub fn unit(vec: *const Self) Self {
            return vec.div(vec.length());
        }
    };
}

const Point3 = Vec3;
const Colour = Point3(f32);

pub fn rgb(r: f32, g: f32, b: f32) Colour {
    return Colour{
        .x = r,
        .y = g,
        .z = b,
    };
}

const HitRecord = struct {
    p: Point3(f32),
    normal: Vec3(f32),
    t: f32,
    front_face: bool,

    pub const Self = @This();

    pub fn setFaceNormal(self: *Self, ray: *const Ray, out_normal: Vec3(f32)) void {
        self.front_face = (ray.direction.dot(&out_normal) < 0);
        self.normal = if (self.front_face) out_normal else out_normal.mul(-1);
    }
};

const Sphere = struct {
    center: Point3(f32),
    radius: f32,

    pub fn hit(self: *const Sphere, ray: *const Ray, t_min: f32, t_max: f32) ?HitRecord {
        const radius = self.radius;
        const center = self.center;

        // https://stackoverflow.com/a/1986458
        const oc = ray.origin.minus(&center);
        const r2 = radius * radius;

        const a = ray.direction.length_squared();
        const half_b = oc.dot(&ray.direction);
        const c = oc.length_squared() - r2;

        const discriminant = half_b * half_b - a * c;

        if (discriminant < 0.0) {
            return null;
        }

        const sqrtd = m.sqrt(discriminant);
        var root = (-half_b - sqrtd) / a;
        if (root < t_min or root > t_max) {
            root = (-half_b + sqrtd) / a;
            if (root < t_min or root > t_max) {
                return null;
            }
        }

        const t = root;
        const p = ray.at(t);

        const normal = p.minus(&center).div(radius);
        var rec = HitRecord{
            .t = t,
            .p = p,
            .normal = undefined,
            .front_face = undefined,
        };

        rec.setFaceNormal(ray, normal);

        return rec;
    }
};

const Ray = struct {
    origin: Point3(f32),
    direction: Vec3(f32),

    pub fn at(ray: Ray, t: f32) Point3(f32) {
        // P(t)=A+tb
        return ray.origin.plus(&ray.direction.mul(t));
    }

    pub fn hitSphere(ray: Ray, radius: f32, center: Point3(f32)) f32 {
        // https://stackoverflow.com/a/1986458
        const oc = ray.origin.minus(&center);
        const r2 = radius * radius;

        const a = ray.direction.length_squared();
        const half_b = oc.dot(&ray.direction);
        const c = oc.length_squared() - r2;

        const discriminant = half_b * half_b - a * c;

        if (discriminant < 0.0) {
            return -1.0;
        } else {
            return (-half_b - m.sqrt(discriminant)) / a;
        }
    }

    pub fn colour(ray: Ray) Colour {
        const inf = m.inf(f32);
        const maybeHit = hitSpheres(&spheres, &ray, 0, inf);

        if (maybeHit) |hit| {
            const N = hit.normal;

            // map RGB to normal XYZ in interval 0-1
            return N.plus(&rgb(1, 1, 1)).mul(0.5);
        }

        const unit_dir = ray.direction.unit();
        const tz = 0.5 * (unit_dir.y + 1.0);

        const end = rgb(0.5, 0.7, 1.0);
        const start = rgb(0, 0, 1);

        return start.mul(1.0 - tz).plus(&end.mul(tz));
    }
};

pub fn writeColour(f: std.fs.File, col: Colour, samples_per_pixel: i32) !void {
    const w = f.writer();

    //const scale: f32 = @divFloor(@intToFloat(f32, 1), @intToFloat(f32, samples_per_pixel));

    // XXX: Change to mul to avoid divides?
    const c = col.div(@intToFloat(f32, samples_per_pixel));

    try w.print("{} {} {}\n", .{ @floatToInt(i32, 255.999 * c.x), @floatToInt(i32, 255.999 * c.y), @floatToInt(i32, 255.999 * c.z) });
}

pub fn hitSpheres(s: *const [4]Sphere, ray: *const Ray, t_min: f32, t_max: f32) ?HitRecord {
    var nearest = t_max;
    var lastHit: ?HitRecord = undefined;

    for (s) |sphere| {
        if (sphere.hit(ray, t_min, nearest)) |hit| {
            lastHit = hit;
            nearest = hit.t;
        }
    }

    return lastHit;
}

const spheres = [_]Sphere{
    Sphere{
        .center = Point3(f32){ .x = 0, .y = 0, .z = -3 },
        .radius = 0.5,
    },
    Sphere{
        .center = Point3(f32){ .x = -0.7, .y = 0, .z = -2 },
        .radius = 0.5,
    },
    Sphere{
        .center = Point3(f32){ .x = 1, .y = 0, .z = -4 },
        .radius = 0.5,
    },
    Sphere{
        .center = Point3(f32){ .x = 0, .y = -100.5, .z = -1 },
        .radius = 100,
    },
};

pub fn main() anyerror!void {
    const stdout_file = std.io.getStdOut();
    const stdout = std.io.getStdOut().writer();

    const aspect_ratio = 16.0 / 9.0;
    const image_width = 600;
    const image_height = @floatToInt(i32, image_width / aspect_ratio);
    const samples_per_pixel = 100;

    const viewport_height = 2.0;
    const viewport_width = aspect_ratio * viewport_height;
    const focal_length = 1.0;

    const origin = Point3(f32){ .x = 0, .y = 0, .z = 0 };
    const horizontal = Vec3(f32){ .x = viewport_width, .y = 0, .z = 0 };
    const vertical = Vec3(f32){ .x = 0, .y = viewport_height, .z = 0 };

    const hor_2 = horizontal.mul(0.5);
    const ver_2 = vertical.mul(0.5);
    const lower_left_corner = origin.minus(&hor_2).minus(&ver_2).minus(&Vec3(f32){ .x = 0, .y = 0, .z = focal_length });

    var prng = std.rand.DefaultPrng.init(0);

    try stdout.print("P3\n{} {}\n255\n", .{ image_width, image_height });

    var j: i32 = image_height - 1;
    while (j >= 0) : (j -= 1) {
        var i: i32 = 0;
        while (i < image_width) : (i += 1) {
            var pixel_colour = rgb(0, 0, 0);
            const fi: f32 = @intToFloat(f32, i);
            const fj: f32 = @intToFloat(f32, j);
            var s: i32 = 0;
            while (s < samples_per_pixel) : (s += 1) {
                const rand_u = prng.random.float(f32);
                const rand_v = prng.random.float(f32);
                const u: f32 = (rand_u + fi) / @intToFloat(f32, (image_width - 1));
                const v: f32 = (rand_u + fj) / @intToFloat(f32, (image_height - 1));
                const target = lower_left_corner.plus(&vertical.mul(v)).plus(&horizontal.mul(u)).minus(&origin);
                const ray = Ray{ .origin = origin, .direction = target };
                pixel_colour = pixel_colour.plus(&ray.colour());
            }

            try writeColour(stdout_file, pixel_colour, samples_per_pixel);
        }
    }
}
