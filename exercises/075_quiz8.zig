const print = @import("std").debug.print;

const TripError = error{ Unreachable, EatenByAGrue };

const Place = struct {
    name: []const u8,
    paths: []const Path = undefined,
};

var a = Place{ .name = "Archer's Point" };
var b = Place{ .name = "Bridge" };
var c = Place{ .name = "Cottage" };
var d = Place{ .name = "Dogwood Grove" };
var e = Place{ .name = "East Pond" };
var f = Place{ .name = "Fox Pond" };

const place_count = 6;

const Path = struct {
    from: *const Place,
    to: *const Place,
    dist: u8,
};

const paths: []const []const Path = parsePaths(
    \\a -> (b[2])
    \\b -> (a[2] d[1])
    \\c -> (d[3] e[2])
    \\d -> (b[1] c[3] f[7])
    \\e -> (c[2] f[1])
    \\f -> (d[7])
);

fn count(comptime str: []const u8, toFind: u8) usize {
    var res: usize = 0;
    for (str) |ch| {
        if (ch == toFind) {
            res += 1;
        }
    }
    return res;
}

fn parsePaths(comptime input: []const u8) []const []const Path {
    const linesCount = count(input, '\n') + 1;
    var res: [linesCount][]const Path = undefined;
    var nextPath = 0;
    var lineStart = 0;
    for (0..input.len + 1) |i| {
        if (i == input.len or input[i] == '\n') {
            res[nextPath] = makePathDsl(input[lineStart..i]);
            nextPath += 1;
            lineStart = i + 1;
        }
    }
    const c_res = comptime res;
    return c_res[0..];
}

fn makePathDsl(comptime s:[] const u8) []const Path {
    const size = count(s, ' ') - 1;
    var res: [size]Path = undefined;
    const from = &@field(@This(), s[0..1]);
    var i: usize = 6;
    var next_entry = 0;
    while (true) {
        const to = &@field(@This(), s[i..(i + 1)]);
        res[next_entry] = Path { .from = from, .to = to, .dist = s[i + 2] - '0' };
        next_entry += 1;
        if (s[i + 4] == ')') break;
        i += 5;
    }
    const c_res = comptime res;
    return c_res[0..];
}

const TripItem = union(enum) {
    place: *const Place,
    path: *const Path,

    fn printMe(self: TripItem) void {
        switch (self) {
            .place => |p| print("{s}", .{p.name}),
            .path => |p| print("--{}->", .{p.dist}),
        }
    }
};

const NotebookEntry = struct {
    place: *const Place,
    coming_from: ?*const Place,
    via_path: ?*const Path,
    dist_to_reach: u16,
};

const HermitsNotebook = struct {
    entries: [place_count]?NotebookEntry = .{null} ** place_count,
    next_entry: u8 = 0,
    end_of_entries: u8 = 0,

    fn getEntry(self: *HermitsNotebook, place: *const Place) ?*NotebookEntry {
        for (&self.entries, 0..) |*entry, i| {
            if (i >= self.end_of_entries) break;
            if (place == entry.*.?.place) return &entry.*.?;
        }
        return null;
    }

    fn checkNote(self: *HermitsNotebook, note: NotebookEntry) void {
        const existing_entry = self.getEntry(note.place);

        if (existing_entry == null) {
            self.entries[self.end_of_entries] = note;
            self.end_of_entries += 1;
        } else if (note.dist_to_reach < existing_entry.?.dist_to_reach) {
            existing_entry.?.* = note;
        }
    }

    fn hasNextEntry(self: *HermitsNotebook) bool {
        return self.next_entry < self.end_of_entries;
    }

    fn getNextEntry(self: *HermitsNotebook) *const NotebookEntry {
        defer self.next_entry += 1;
        return &self.entries[self.next_entry].?;
    }

    fn getTripTo(self: *HermitsNotebook, trip: []?TripItem, dest: *Place) TripError!void {
        const destination_entry = self.getEntry(dest);

        if (destination_entry == null) {
            return TripError.Unreachable;
        }

        var current_entry = destination_entry.?;
        var i: u8 = 0;

        while (true) : (i += 2) {
            trip[i] = TripItem{ .place = current_entry.place };
            if (current_entry.coming_from == null) break;
            trip[i + 1] = TripItem{ .path = current_entry.via_path.? };
            const previous_entry = self.getEntry(current_entry.coming_from.?);
            if (previous_entry == null) return TripError.EatenByAGrue;
            current_entry = previous_entry.?;
        }
    }
};

pub fn main() void {
    const start = &a; // Archer's Point
    const destination = &f; // Fox Pond

    const letters = "abcdef";
    inline for (0..letters.len) |i| {
        @field(@This(), letters[i..i + 1]).paths = paths[i][0..];
    }

    var notebook = HermitsNotebook{};
    var working_note = NotebookEntry{
        .place = start,
        .coming_from = null,
        .via_path = null,
        .dist_to_reach = 0,
    };
    notebook.checkNote(working_note);

    while (notebook.hasNextEntry()) {
        const place_entry = notebook.getNextEntry();

        for (place_entry.place.paths) |*path| {
            working_note = NotebookEntry{
                .place = path.to,
                .coming_from = place_entry.place,
                .via_path = path,
                .dist_to_reach = place_entry.dist_to_reach + path.dist,
            };
            notebook.checkNote(working_note);
        }
    }

    var trip = [_]?TripItem{null} ** (place_count * 2);

    notebook.getTripTo(trip[0..], destination) catch |err| {
        print("Oh no! {}\n", .{err});
        return;
    };

    printTrip(trip[0..]);
}

fn printTrip(trip: []?TripItem) void {
    var i: u8 = @intCast(trip.len);

    while (i > 0) {
        i -= 1;
        if (trip[i] == null) continue;
        trip[i].?.printMe();
    }

    print("\n", .{});
}
