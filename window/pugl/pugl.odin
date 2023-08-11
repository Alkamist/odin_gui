package pugl

import "core:c"

Coord :: i16
Span :: u16

Rect :: struct {
    x: Coord,
    y: Coord,
    width: Span,
    height: Span,
}

StringHint :: enum c.int {
    CLASS_NAME = 1,
    WINDOW_TITLE,
}

EventType :: enum c.int {
    NOTHING,
    REALIZE,
    UNREALIZE,
    CONFIGURE,
    UPDATE,
    EXPOSE,
    CLOSE,
    FOCUS_IN,
    FOCUS_OUT,
    KEY_PRESS,
    KEY_RELEASE,
    TEXT,
    POINTER_IN,
    POINTER_OUT,
    BUTTON_PRESS,
    BUTTON_RELEASE,
    MOTION,
    SCROLL,
    CLIENT,
    TIMER,
    LOOP_ENTER,
    LOOP_LEAVE,
    DATA_OFFER,
    DATA,
}

EventFlag :: enum u32 {
    IS_SEND_EVENT,
    IS_HINT,
}

EventFlags :: bit_set[EventFlag; u32]

CrossingMode :: enum c.int {
    NORMAL,
    GRAB,
    UNGRAB,
}

AnyEvent :: struct {
    type: EventType,
    flags: EventFlags,
}

ViewStyleFlag :: enum u32 {
    MAPPED,
    MODAL,
    ABOVE,
    BELOW,
    HIDDEN,
    TALL,
    WIDE,
    FULLSCREEN,
    RESIZING,
    DEMANDING,
}

ViewStyleFlags :: bit_set[ViewStyleFlag; u32]

RealizeEvent :: AnyEvent
UnrealizeEvent :: AnyEvent

ConfigureEvent :: struct {
    type: EventType,
    flags: EventFlags,
    x: Coord,
    y: Coord,
    width: Span,
    height: Span,
    style: ViewStyleFlags,
}

LoopEnterEvent :: AnyEvent
LoopLeaveEvent :: AnyEvent
CloseEvent :: AnyEvent
UpdateEvent :: AnyEvent

ExposeEvent :: struct {
    type: EventType,
    flags: EventFlags,
    x: Coord,
    y: Coord,
    width: Span,
    height: Span,
}

Key :: enum u32 {
    BACKSPACE = 0x00000008,
    ENTER = 0x0000000D,
    ESCAPE = 0x0000001B,
    DELETE = 0x0000007F,
    SPACE = 0x00000020,
    F1 = 0x0000E000,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,
    PAGE_UP = 0xE031,
    PAGE_DOWN,
    END,
    HOME,
    LEFT,
    UP,
    RIGHT,
    DOWN,
    PRINT_SCREEN = 0xE041,
    INSERT,
    PAUSE,
    MENU,
    NUM_LOCK,
    SCROLL_LOCK,
    CAPS_LOCK,
    SHIFT_L = 0xE051,
    SHIFT_R,
    CTRL_L,
    CTRL_R,
    ALT_L,
    ALT_R,
    SUPER_L,
    SUPER_R,
    PAD_0 = 0xE060,
    PAD_1,
    PAD_2,
    PAD_3,
    PAD_4,
    PAD_5,
    PAD_6,
    PAD_7,
    PAD_8,
    PAD_9,
    PAD_ENTER,
    PAD_PAGE_UP = 0xE071,
    PAD_PAGE_DOWN,
    PAD_END,
    PAD_HOME,
    PAD_LEFT,
    PAD_UP,
    PAD_RIGHT,
    PAD_DOWN,
    PAD_CLEAR = 0xE09D,
    PAD_INSERT,
    PAD_DELETE,
    PAD_EQUAL,
    PAD_MULTIPLY = 0xE0AA,
    PAD_ADD,
    PAD_SEPARATOR,
    PAD_SUBTRACT,
    PAD_DECIMAL,
    PAD_DIVIDE,
}

Mod :: enum u32 {
    SHIFT,
    CTRL,
    ALT,
    SUPER,
}

Mods :: bit_set[Mod; u32]

FocusEvent :: struct {
    type: EventType,
    flags: EventFlags,
    mode: CrossingMode,
}

KeyEvent :: struct {
    type: EventType,
    flags: EventFlags,
    time: f64,
    x: f64,
    y: f64,
    xRoot: f64,
    yRoot: f64,
    state: Mods,
    keycode: u32,
    key: Key,
}

TextEvent :: struct {
    type: EventType,
    flags: EventFlags,
    time: f64,
    x: f64,
    y: f64,
    xRoot: f64,
    yRoot: f64,
    state: Mods,
    keycode: u32,
    character: u32,
    string: [8]u8,
}

ScrollDirection :: enum c.int {
    UP,
    DOWN,
    LEFT,
    RIGHT,
    SMOOTH,
}

CrossingEvent :: struct {
    type: EventType,
    flags: EventFlags,
    time: f64,
    x: f64,
    y: f64,
    xRoot: f64,
    yRoot: f64,
    state: Mods,
    mode: CrossingMode,
}

ButtonEvent :: struct {
    type: EventType,
    flags: EventFlags,
    time: f64,
    x: f64,
    y: f64,
    xRoot: f64,
    yRoot: f64,
    state: Mods,
    button: u32,
}

MotionEvent :: struct {
    type: EventType,
    flags: EventFlags,
    time: f64,
    x: f64,
    y: f64,
    xRoot: f64,
    yRoot: f64,
    state: Mods,
}

ScrollEvent :: struct {
    type: EventType,
    flags: EventFlags,
    time: f64,
    x: f64,
    y: f64,
    xRoot: f64,
    yRoot: f64,
    state: Mods,
    direction: ScrollDirection,
    dx: f64,
    dy: f64,
}

ClientEvent :: struct {
    type: EventType,
    flags: EventFlags,
    data1: uintptr,
    data2: uintptr,
}

TimerEvent :: struct {
    type: EventType,
    flags: EventFlags,
    id: uintptr,
}

DataOfferEvent :: struct {
    type: EventType,
    flags: EventFlags,
    time: f64,
}

DataEvent :: struct {
    type: EventType,
    flags: EventFlags,
    time: f64,
    typeIndex: u32,
}

Event :: struct #raw_union {
    any: AnyEvent,
    type: EventType,
    button: ButtonEvent,
    configure: ConfigureEvent,
    expose: ExposeEvent,
    key: KeyEvent,
    text: TextEvent,
    crossing: CrossingEvent,
    motion: MotionEvent,
    scroll: ScrollEvent,
    focus: FocusEvent,
    client: ClientEvent,
    timer: TimerEvent,
    offer: DataOfferEvent,
    data: DataEvent,
}

Status :: enum c.int {
    SUCCESS,
    FAILURE,
    UNKNOWN_ERROR,
    BAD_BACKEND,
    BAD_CONFIGURATION,
    BAD_PARAMETER,
    BACKEND_FAILED,
    REGISTRATION_FAILED,
    REALIZE_FAILED,
    SET_FORMAT_FAILED,
    CREATE_CONTEXT_FAILED,
    UNSUPPORTED,
    NO_MEMORY,
}

World :: struct {}
WorldHandle :: rawptr

WorldType :: enum c.int {
    PROGRAM,
    MODULE,
}

WorldFlag :: enum u32 {
    WORLD_THREADS,
}

WorldFlags :: bit_set[WorldFlag; u32]

View :: struct {}
Backend :: struct {}

NativeView :: uintptr
Handle :: rawptr

ViewHint :: enum c.int {
    CONTEXT_API,
    CONTEXT_VERSION_MAJOR,
    CONTEXT_VERSION_MINOR,
    CONTEXT_PROFILE,
    CONTEXT_DEBUG,
    RED_BITS,
    GREEN_BITS,
    BLUE_BITS,
    ALPHA_BITS,
    DEPTH_BITS,
    STENCIL_BITS,
    SAMPLE_BUFFERS,
    SAMPLES,
    DOUBLE_BUFFER,
    SWAP_INTERVAL,
    RESIZABLE,
    IGNORE_KEY_REPEAT,
    REFRESH_RATE,
    VIEW_TYPE,
    DARK_FRAME,
}

ViewHintValue :: enum c.int {
    DONT_CARE = -1,
    FALSE = 0,
    TRUE = 1,
    OPENGL_API = 2,
    OPENGL_ES_API = 3,
    OPENGL_CORE_PROFILE = 4,
    OPENGL_COMPATIBILITY_PROFILE = 5,
}

ViewType :: enum c.int {
    NORMAL,
    UTILITY,
    DIALOG,
}

SizeHint :: enum c.int {
    DEFAULT_SIZE,
    MIN_SIZE,
    MAX_SIZE,
    FIXED_ASPECT,
    MIN_ASPECT,
    MAX_ASPECT,
}

ShowCommand :: enum c.int {
    PASSIVE,
    RAISE,
    FORCE_RAISE,
}

Cursor :: enum c.int {
    ARROW,
    CARET,
    CROSSHAIR,
    HAND,
    NO,
    LEFT_RIGHT,
    UP_DOWN,
    UP_LEFT_DOWN_RIGHT,
    UP_RIGHT_DOWN_LEFT,
    ALL_SCROLL,
}

EventFunc :: #type proc "c" (view: ^View, event: ^Event) -> Status

foreign import pugl { "pugl.lib", "system:user32.lib", "system:dwmapi.lib", "system:gdi32.lib", "system:opengl32.lib" }

@(default_calling_convention="c", link_prefix="pugl")
foreign pugl {
    Strerror :: proc(status: Status) -> cstring ---
    NewWorld :: proc(type: WorldType, flags: WorldFlags) -> ^World ---
    FreeWorld :: proc(world: ^World) ---
    SetWorldHandle :: proc(world: ^World, handle: WorldHandle) ---
    GetWorldHandle :: proc(world: ^World) -> WorldHandle ---
    GetNativeWorld :: proc(world: ^World) -> rawptr ---
    SetWorldString :: proc(world: ^World, key: StringHint, value: cstring) -> Status ---
    GetWorldString :: proc(world: ^World, key: StringHint) -> cstring ---
    GetTime :: proc(world: ^World) -> f64 ---
    Update :: proc(world: ^World, timeout: f64) -> Status ---
    NewView :: proc(world: ^World) -> ^View ---
    FreeView :: proc(view: ^View) ---
    GetWorld :: proc(view: ^View) -> ^World ---
    SetHandle :: proc(view: ^View, handle: Handle) ---
    GetHandle :: proc(view: ^View) -> Handle ---
    SetBackend :: proc(view: ^View, backend: ^Backend) -> Status ---
    GetBackend :: proc(view: ^View) -> ^Backend ---
    SetEventFunc :: proc(view: ^View, eventFunc: EventFunc) -> Status ---
    SetViewHint :: proc(view: ^View, hint: ViewHint, value: c.int) -> Status ---
    GetViewHint :: proc(view: ^View, hint: ViewHint) -> c.int ---
    SetViewString :: proc(view: ^View, key: StringHint, value: cstring) -> Status ---
    GetViewString :: proc(view: ^View, key: StringHint) -> cstring ---
    GetScaleFactor :: proc(view: ^View) -> f64 ---
    GetFrame :: proc(view: ^View) -> Rect ---
    SetFrame :: proc(view: ^View, frame: Rect) -> Status ---
    SetPosition :: proc(view: ^View, x, y: c.int) -> Status ---
    SetSize :: proc(view: ^View, width, height: c.uint) -> Status ---
    SetSizeHint :: proc(view: ^View, hint: SizeHint, width, height: Span) -> Status ---
    SetParentWindow :: proc(view: ^View, parent: NativeView) -> Status ---
    GetParentWindow :: proc(view: ^View) -> NativeView ---
    SetTransientParent :: proc(view: ^View, parent: NativeView) -> Status ---
    GetTransientParent :: proc(view: ^View) -> NativeView ---
    Realize :: proc(view: ^View) -> Status ---
    Unrealize :: proc(view: ^View) -> Status ---
    Show :: proc(view: ^View, command: ShowCommand) -> Status ---
    Hide :: proc(view: ^View) -> Status ---
    SetViewStyle :: proc(view: ^View, flags: ViewStyleFlags) -> Status ---
    GetViewStyle :: proc(view: ^View) -> ViewStyleFlags ---
    GetVisible :: proc(view: ^View) -> bool ---
    GetNativeView :: proc(view: ^View) -> NativeView ---
    GetContext :: proc(view: ^View) -> rawptr ---
    PostRedisplay :: proc(view: ^View) -> Status ---
    PostRedisplayRect :: proc(view: ^View, rect: Rect) -> Status ---
    GrabFocus :: proc(view: ^View) -> Status ---
    HasFocus :: proc(view: ^View) -> bool ---
    Paste :: proc(view: ^View) -> Status ---
    GetNumClipboardTypes :: proc(view: ^View) -> u32 ---
    GetClipboardType :: proc(view: ^View, typeIndex: u32) -> cstring ---
    AcceptOffer :: proc(view: ^View, offer: ^DataOfferEvent, typeIndex: u32) -> Status ---
    SetClipboard :: proc(view: ^View, type: cstring, data: rawptr, len: uint) -> Status ---
    GetClipboard :: proc(view: ^View, typeIndex: u32, len: ^uint) -> rawptr ---
    SetCursor :: proc(view: ^View, cursor: Cursor) -> Status ---
    StartTimer :: proc(view: ^View, id: uintptr, timeout: f64) -> Status ---
    StopTimer :: proc(view: ^View, id: uintptr) -> Status ---
    SendEvent :: proc(view: ^View, event: ^Event) -> Status ---

    // GL procs
    GetProcAddress :: proc(name: cstring) -> rawptr ---
    EnterContext :: proc(view: ^View) -> Status ---
    LeaveContext :: proc(view: ^View) -> Status ---
    GlBackend :: proc() -> ^Backend ---
}

gl_set_proc_address :: proc(p: rawptr, name: cstring) {
	(^rawptr)(p)^ = GetProcAddress(name)
}