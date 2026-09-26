const std = @import("std");
const gdk = @import("gdk");
const gio = @import("gio");
const glib = @import("glib");
const gobject = @import("gobject");

const Common = @import("../class.zig").Common;

/// A content provider that lets a drag be dropped outside of any window.
///
/// It offers the `application/x-rootwindow-drop` type, which compositors
/// (e.g. Mutter) and GDK use to let a drag succeed when it is dropped onto
/// the desktop rather than a window. The content is never actually used:
/// writing it only records that the drag was dropped outside of any window,
/// which can be checked once the drag has ended. This is the same approach
/// libadwaita uses for dragging tabs out into new windows.
///
/// Combine this with other providers using `gdk.ContentProvider.newUnion`.
pub const RootWindowDrop = extern struct {
    const Self = @This();
    parent_instance: Parent,
    pub const Parent = gdk.ContentProvider;
    pub const getGObjectType = gobject.ext.defineClass(Self, .{
        .name = "GhosttyRootWindowDrop",
        .classInit = &Class.init,
        .parent_class = &Class.parent,
        .private = .{ .Type = Private, .offset = &Private.offset },
    });

    const mime_type = "application/x-rootwindow-drop";

    const Private = struct {
        /// True if the drag was dropped outside of any window.
        dropped: bool = false,

        pub var offset: c_int = 0;
    };

    pub fn new() *Self {
        return gobject.ext.newInstance(Self, .{});
    }

    /// Returns true if the drag was dropped outside of any window.
    pub fn getDropped(self: *Self) bool {
        return self.private().dropped;
    }

    /// Record that the drag was dropped outside of any window. This is for
    /// cases where the drop is detected some other way, such as a drag
    /// being cancelled because it had no target.
    pub fn setDropped(self: *Self) void {
        self.private().dropped = true;
    }

    fn refFormats(_: *Self) callconv(.c) *gdk.ContentFormats {
        var mime_types = [_][*:0]const u8{mime_type};
        return gdk.ContentFormats.new(&mime_types, mime_types.len);
    }

    fn writeMimeTypeAsync(
        self: *Self,
        _: [*:0]const u8,
        _: *gio.OutputStream,
        io_priority: c_int,
        cancellable: ?*gio.Cancellable,
        callback: ?gio.AsyncReadyCallback,
        user_data: ?*anyopaque,
    ) callconv(.c) void {
        self.private().dropped = true;

        const task = gio.Task.new(
            self.as(gobject.Object),
            cancellable,
            callback,
            user_data,
        );
        defer task.unref();
        task.setPriority(io_priority);
        task.returnBoolean(@intFromBool(true));
    }

    fn writeMimeTypeFinish(
        _: *Self,
        result: *gio.AsyncResult,
        err: ?*?*glib.Error,
    ) callconv(.c) c_int {
        const task = gobject.ext.cast(
            gio.Task,
            result,
        ) orelse return @intFromBool(false);
        return task.propagateBoolean(err);
    }

    const C = Common(Self, Private);
    pub const as = C.as;
    pub const ref = C.ref;
    pub const unref = C.unref;
    const private = C.private;

    pub const Class = extern struct {
        parent_class: Parent.Class,
        var parent: *Parent.Class = undefined;
        pub const Instance = Self;

        fn init(class: *Class) callconv(.c) void {
            gdk.ContentProvider.virtual_methods.ref_formats.implement(
                class,
                &refFormats,
            );
            gdk.ContentProvider.virtual_methods.write_mime_type_async.implement(
                class,
                &writeMimeTypeAsync,
            );
            gdk.ContentProvider.virtual_methods.write_mime_type_finish.implement(
                class,
                &writeMimeTypeFinish,
            );
        }
    };
};
