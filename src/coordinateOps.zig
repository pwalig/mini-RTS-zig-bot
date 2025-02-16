const ops = @This();

pub fn distance(x1: u32, y1: u32, x2: u32, y2: u32) u32 {
    if (x1 > x2) {
        if (y1 > y2) {
            return x1 - x2 + y1 - y2;
        } else return x1 - x2 + y2 - y1;
    } else {
        if (y1 > y2) {
            return x2 - x1 + y1 - y2;
        } else return x2 - x1 + y2 - y1;
    }
}

pub fn towards(sx: u32, sy: u32, tx: u32, ty: u32) coords {
    var dist: u32 = 0;
    var x: u32 = 0;
    if (sx > tx) {
        x = sx - 1;
        dist = sx - tx;
    } else if (sx < tx) {
        x = sx + 1;
        dist = tx - sx;
    }
    if (sy > ty and sy - ty > dist) {
        return coords{ .x = sx, .y = sy - 1 };
    } else if (sy < ty and ty - sy > dist) {
        return coords{ .x = sx, .y = sy + 1 };
    }
    return coords{ .x = x, .y = sy };
}

pub const coords = struct {
    x: u32,
    y: u32,

    pub fn distance(c1: coords, c2: coords) u32 {
        return ops.distance(c1.x, c1.y, c2.x, c2.y);
    }

    pub fn towards(sc: coords, tc: coords) coords {
        return ops.towards(sc.x, sc.y, tc.x, tc.y);
    }

    pub fn eql(c1: coords, c2: coords) bool {
        return (c1.x == c2.x and c1.y == c2.y);
    }
};
