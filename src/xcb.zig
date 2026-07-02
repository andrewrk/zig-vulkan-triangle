extern "xcb" fn xcb_connect(displayname: ?[*:0]const u8, screenp: *c_int) callconv(.c) ?*connection_t;
pub const connect = xcb_connect;

extern "xcb" fn xcb_get_setup(c: *connection_t) callconv(.c) *const xcb_setup_t;
pub const get_setup = xcb_get_setup;

extern "xcb" fn xcb_connection_has_error(c: *connection_t) callconv(.c) c_int;
pub const connection_has_error = xcb_connection_has_error;

extern "xcb" fn xcb_setup_roots_iterator(R: *const xcb_setup_t) callconv(.c) xcb_screen_iterator_t;
pub const setup_roots_iterator = xcb_setup_roots_iterator;

extern "xcb" fn xcb_screen_next(i: *xcb_screen_iterator_t) callconv(.c) void;
pub const screen_next = xcb_screen_next;

extern "xcb" fn xcb_generate_id(c: *connection_t) callconv(.c) u32;
pub const generate_id = xcb_generate_id;

extern "xcb" fn xcb_create_window(
    c: *connection_t,
    depth: u8,
    wid: window_t,
    parent: window_t,
    x: i16,
    y: i16,
    width: u16,
    height: u16,
    border_width: u16,
    _class: u16,
    visual: visualid_t,
    value_mask: u32,
    value_list: ?*const anyopaque,
) callconv(.c) xcb_void_cookie_t;
pub const create_window = xcb_create_window;

pub const wait_for_event = @extern(*const fn (c: *connection_t) callconv(.c) ?*generic_event_t, .{
    .name = "xcb_wait_for_event",
    .library_name = "xcb",
});
pub const poll_for_event = @extern(*const fn (c: *connection_t) callconv(.c) ?*generic_event_t, .{
    .name = "xcb_poll_for_event",
    .library_name = "xcb",
});
pub const intern_atom = @extern(*const InternAtomFn, .{
    .name = "xcb_intern_atom",
    .library_name = "xcb",
});

extern "xcb" fn xcb_intern_atom_reply(
    c: *connection_t,
    cookie: intern_atom_cookie_t,
    e: ?**xcb_generic_error_t,
) callconv(.c) ?*intern_atom_reply_t;
pub const intern_atom_reply = xcb_intern_atom_reply;

extern "xcb" fn xcb_change_property(
    c: *connection_t,
    mode: prop_mode_t,
    window: window_t,
    property: atom_t,
    type: atom_t,
    format: u8,
    data_len: u32,
    data: ?*const anyopaque,
) callconv(.c) xcb_void_cookie_t;
pub const change_property = xcb_change_property;

extern "xcb" fn xcb_map_window(c: *connection_t, window: window_t) callconv(.c) xcb_void_cookie_t;
pub const map_window = xcb_map_window;

pub const InternAtomFn = fn (
    c: *connection_t,
    only_if_exists: u8,
    name_len: u16,
    name: [*:0]const u8,
) callconv(.c) intern_atom_cookie_t;

pub const InternAtomReplyFn = fn (
    c: *connection_t,
    cookie: intern_atom_cookie_t,
    e: ?**xcb_generic_error_t,
) callconv(.c) *intern_atom_reply_t;

pub const connection_t = opaque {};
pub const keycode_t = u8;
pub const window_t = u32;
pub const colormap_t = u32;
pub const visualid_t = u32;
pub const timestamp_t = u32;

pub const CW = struct {
    pub const BACK_PIXMAP = 1;
    pub const BACK_PIXEL = 2;
    pub const BORDER_PIXMAP = 4;
    pub const BORDER_PIXEL = 8;
    pub const BIT_GRAVITY = 16;
    pub const WIN_GRAVITY = 32;
    pub const BACKING_STORE = 64;
    pub const BACKING_PLANES = 128;
    pub const BACKING_PIXEL = 256;
    pub const OVERRIDE_REDIRECT = 512;
    pub const SAVE_UNDER = 1024;
    pub const EVENT_MASK = 2048;
    pub const DONT_PROPAGATE = 4096;
    pub const COLORMAP = 8192;
    pub const CURSOR = 16384;
};

pub const EVENT_MASK = struct {
    pub const NO_EVENT = 0;
    pub const KEY_PRESS = 1;
    pub const KEY_RELEASE = 2;
    pub const BUTTON_PRESS = 4;
    pub const BUTTON_RELEASE = 8;
    pub const ENTER_WINDOW = 16;
    pub const LEAVE_WINDOW = 32;
    pub const POINTER_MOTION = 64;
    pub const POINTER_MOTION_HINT = 128;
    pub const BUTTON_1_MOTION = 256;
    pub const BUTTON_2_MOTION = 512;
    pub const BUTTON_3_MOTION = 1024;
    pub const BUTTON_4_MOTION = 2048;
    pub const BUTTON_5_MOTION = 4096;
    pub const BUTTON_MOTION = 8192;
    pub const KEYMAP_STATE = 16384;
    pub const EXPOSURE = 32768;
    pub const VISIBILITY_CHANGE = 65536;
    pub const STRUCTURE_NOTIFY = 131072;
    pub const RESIZE_REDIRECT = 262144;
    pub const SUBSTRUCTURE_NOTIFY = 524288;
    pub const SUBSTRUCTURE_REDIRECT = 1048576;
    pub const FOCUS_CHANGE = 2097152;
    pub const PROPERTY_CHANGE = 4194304;
    pub const COLOR_MAP_CHANGE = 8388608;
    pub const OWNER_GRAB_BUTTON = 16777216;
};

pub const COPY_FROM_PARENT: c_long = 0;

pub const intern_atom_reply_t = extern struct {
    response_type: u8,
    pad0: u8,
    sequence: u16,
    length: u32,
    atom: atom_t,
};

const xcb_generic_error_t = extern struct {
    response_type: u8,
    error_code: u8,
    sequence: u16,
    resource_id: u32,
    minor_code: u16,
    major_code: u8,
    pad0: u8,
    pad: [5]u32,
    full_sequence: u32,
};

pub const intern_atom_cookie_t = extern struct {
    sequence: c_uint,
};

const xcb_void_cookie_t = extern struct {
    sequence: c_uint,
};

const xcb_setup_t = extern struct {
    status: u8,
    pad0: u8,
    protocol_major_version: u16,
    protocol_minor_version: u16,
    length: u16,
    release_number: u32,
    resource_id_base: u32,
    resource_id_mask: u32,
    motion_buffer_size: u32,
    vendor_len: u16,
    maximum_request_length: u16,
    roots_len: u8,
    pixmap_formats_len: u8,
    image_byte_order: u8,
    bitmap_format_bit_order: u8,
    bitmap_format_scanline_unit: u8,
    bitmap_format_scanline_pad: u8,
    min_keycode: keycode_t,
    max_keycode: keycode_t,
    pad1: [4]u8,
};

const xcb_screen_iterator_t = extern struct {
    data: *xcb_screen_t,
    rem: c_int,
    index: c_int,
};
const xcb_screen_t = extern struct {
    root: window_t,
    default_colormap: colormap_t,
    white_pixel: u32,
    black_pixel: u32,
    current_input_masks: u32,
    width_in_pixels: u16,
    height_in_pixels: u16,
    width_in_millimeters: u16,
    height_in_millimeters: u16,
    min_installed_maps: u16,
    max_installed_maps: u16,
    root_visual: visualid_t,
    backing_stores: u8,
    save_unders: u8,
    root_depth: u8,
    allowed_depths_len: u8,
};

pub const prop_mode_t = enum(c_int) {
    REPLACE = 0,
    PREPEND = 1,
    APPEND = 2,
    _,
};

pub const atom_t = enum(u32) {
    NONE = 0,
    PRIMARY = 1,
    SECONDARY = 2,
    ARC = 3,
    ATOM = 4,
    BITMAP = 5,
    CARDINAL = 6,
    COLORMAP = 7,
    CURSOR = 8,
    CUT_BUFFER0 = 9,
    CUT_BUFFER1 = 10,
    CUT_BUFFER2 = 11,
    CUT_BUFFER3 = 12,
    CUT_BUFFER4 = 13,
    CUT_BUFFER5 = 14,
    CUT_BUFFER6 = 15,
    CUT_BUFFER7 = 16,
    DRAWABLE = 17,
    FONT = 18,
    INTEGER = 19,
    PIXMAP = 20,
    POINT = 21,
    RECTANGLE = 22,
    RESOURCE_MANAGER = 23,
    RGB_COLOR_MAP = 24,
    RGB_BEST_MAP = 25,
    RGB_BLUE_MAP = 26,
    RGB_DEFAULT_MAP = 27,
    RGB_GRAY_MAP = 28,
    RGB_GREEN_MAP = 29,
    RGB_RED_MAP = 30,
    STRING = 31,
    VISUALID = 32,
    WINDOW = 33,
    WM_COMMAND = 34,
    WM_HINTS = 35,
    WM_CLIENT_MACHINE = 36,
    WM_ICON_NAME = 37,
    WM_ICON_SIZE = 38,
    WM_NAME = 39,
    WM_NORMAL_HINTS = 40,
    WM_SIZE_HINTS = 41,
    WM_ZOOM_HINTS = 42,
    MIN_SPACE = 43,
    NORM_SPACE = 44,
    MAX_SPACE = 45,
    END_SPACE = 46,
    SUPERSCRIPT_X = 47,
    SUPERSCRIPT_Y = 48,
    SUBSCRIPT_X = 49,
    SUBSCRIPT_Y = 50,
    UNDERLINE_POSITION = 51,
    UNDERLINE_THICKNESS = 52,
    STRIKEOUT_ASCENT = 53,
    STRIKEOUT_DESCENT = 54,
    ITALIC_ANGLE = 55,
    X_HEIGHT = 56,
    QUAD_WIDTH = 57,
    WEIGHT = 58,
    POINT_SIZE = 59,
    RESOLUTION = 60,
    COPYRIGHT = 61,
    NOTICE = 62,
    FONT_NAME = 63,
    FAMILY_NAME = 64,
    FULL_NAME = 65,
    CAP_HEIGHT = 66,
    WM_CLASS = 67,
    WM_TRANSIENT_FOR = 68,
    _,
};

pub const window_class_t = enum(c_int) {
    COPY_FROM_PARENT = 0,
    INPUT_OUTPUT = 1,
    INPUT_ONLY = 2,
    _,
};

pub const generic_event_t = extern struct {
    response_type: ResponseType,
    pad0: u8,
    sequence: u16,
    pad: [7]u32,
    full_sequence: u32,
};

pub const ResponseType = packed struct(u8) {
    op: Op,
    mystery: u1,

    pub const Op = enum(u7) {
        KEY_PRESS = 2,
        KEY_RELEASE = 3,
        BUTTON_PRESS = 4,
        BUTTON_RELEASE = 5,
        MOTION_NOTIFY = 6,
        ENTER_NOTIFY = 7,
        LEAVE_NOTIFY = 8,
        FOCUS_IN = 9,
        FOCUS_OUT = 10,
        KEYMAP_NOTIFY = 11,
        EXPOSE = 12,
        GRAPHICS_EXPOSURE = 13,
        NO_EXPOSURE = 14,
        VISIBILITY_NOTIFY = 15,
        CREATE_NOTIFY = 16,
        DESTROY_NOTIFY = 17,
        UNMAP_NOTIFY = 18,
        MAP_NOTIFY = 19,
        MAP_REQUEST = 20,
        REPARENT_NOTIFY = 21,
        CONFIGURE_NOTIFY = 22,
        CONFIGURE_REQUEST = 23,
        GRAVITY_NOTIFY = 24,
        RESIZE_REQUEST = 25,
        CIRCULATE_NOTIFY = 26,
        CIRCULATE_REQUEST = 27,
        PROPERTY_NOTIFY = 28,
        SELECTION_CLEAR = 29,
        SELECTION_REQUEST = 30,
        SELECTION_NOTIFY = 31,
        COLORMAP_NOTIFY = 32,
        CLIENT_MESSAGE = 33,
        MAPPING_NOTIFY = 34,
        GE_GENERIC = 35,
    };
};

pub const client_message_event_t = extern struct {
    response_type: ResponseType,
    format: u8,
    sequence: u16,
    window: window_t,
    type: atom_t,
    data: client_message_data_t,
};

pub const client_message_data_t = extern union {
    data8: [20]u8,
    data16: [10]u16,
    data32: [5]u32,
};

pub const configure_notify_event_t = extern struct {
    response_type: ResponseType,
    pad0: u8,
    sequence: u16,
    event: window_t,
    window: window_t,
    above_sibling: window_t,
    x: i16,
    y: i16,
    width: u16,
    height: u16,
    border_width: u16,
    override_redirect: u8,
    pad1: u8,
};

pub const key_press_event_t = extern struct {
    response_type: ResponseType,
    detail: keycode_t,
    sequence: u16,
    time: timestamp_t,
    root: window_t,
    event: window_t,
    child: window_t,
    root_x: i16,
    root_y: i16,
    event_x: i16,
    event_y: i16,
    state: u16,
    same_screen: u8,
    pad0: u8,
};
