#import <AppKit/AppKit.h>
#include <stdint.h>
#include <math.h>

extern void mimoc_key(int key);
extern void mimoc_click(int x, int y);
extern void mimoc_tick(uint32_t now_ms);
static void (*hover_callback)(int, int);
void mimoc_window_set_hover(void (*callback)(int, int)) { hover_callback = callback; }

uint32_t mimoc_now_ms(void) {
    return (uint32_t)(uint64_t)([NSProcessInfo processInfo].systemUptime * 1000.0);
}

static const uint8_t *pixels;
static NSView *canvas;
static int display_width;
static int display_height;
static int display_scale;
static BOOL desktop_mode;
static double wheel_x, wheel_y;
static void (*desktop_event)(int, int, int, int, int, const char *, size_t);
static void (*desktop_resize)(int, int);
static int desktopKey(unsigned short code) {
    switch(code) { case 36: case 76:return 0; case 53:return 1; case 48:return 2; case 51:return 3; case 117:return 4; case 49:return 5; case 126:return 6; case 125:return 7; case 123:return 8; case 124:return 9; case 115:return 10; case 119:return 11; default:return 12; }
}
static void pointerEvent(NSView *view, NSEvent *event, int kind) {
    NSPoint p = [view convertPoint:event.locationInWindow fromView:nil];
    desktop_event(kind, 0, (int)floor(p.x/display_scale), (int)floor(p.y/display_scale), 0, NULL, 0);
}
void mimoc_window_present(const uint8_t *buffer, int width, int height) { pixels = buffer; display_width = width; display_height = height; [canvas setNeedsDisplay:YES]; }
void mimoc_window_viewport(int *width, int *height) { *width = display_width; *height = display_height; }


@interface MimocView : NSView <NSTextInputClient>
@property(nonatomic,strong) NSAttributedString *marked;
@end

@implementation MimocView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor colorWithCalibratedWhite:0.04 alpha:1] setFill];
    NSRectFill(self.bounds);
    [[NSColor colorWithCalibratedWhite:0.92 alpha:1] setFill];
    for (int y = 0; y < display_height; ++y) {
        for (int x = 0; x < display_width; ++x) {
            if (pixels[(y / 8) * display_width + x] & (1u << (y % 8))) {
                NSRectFill(NSMakeRect(x * display_scale, y * display_scale, display_scale, display_scale));
            }
        }
    }
}
- (void)keyDown:(NSEvent *)event {
    if (desktop_mode) {
        if (self.hasMarkedText) { [self interpretKeyEvents:@[event]]; return; }
        desktop_event(0, desktopKey(event.keyCode), 0, 0, event.isARepeat, NULL, 0);
        if (desktopKey(event.keyCode) == 12 || event.keyCode == 49) {
            if (!(event.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagControl))) [self interpretKeyEvents:@[event]];
        }
        return;
    }
    switch (event.keyCode) {
        case 126: mimoc_key(0); return; // up
        case 125: mimoc_key(1); return; // down
        case 123: mimoc_key(2); return; // left
        case 124: mimoc_key(3); return; // right
        case 36: case 49: mimoc_key(4); return; // return, space
        case 53: mimoc_key(5); return; // escape
        default: break;
    }
    NSString *characters = event.charactersIgnoringModifiers.lowercaseString;
    if ([characters isEqualToString:@"w"]) mimoc_key(0);
    else if ([characters isEqualToString:@"s"]) mimoc_key(1);
    else if ([characters isEqualToString:@"a"]) mimoc_key(2);
    else if ([characters isEqualToString:@"d"]) mimoc_key(3);
    else if ([characters isEqualToString:@"r"]) mimoc_key(6);
    else if ([characters isEqualToString:@"p"]) mimoc_key(7);
    else if ([characters isEqualToString:@"x"]) mimoc_key(8);
    else if ([characters isEqualToString:@"n"]) mimoc_key(9);
    else if ([characters isEqualToString:@"f"]) mimoc_key(10);
    else if ([characters isEqualToString:@"t"]) mimoc_key(11);
    else if ([characters isEqualToString:@"o"]) mimoc_key(12);
    else if ([characters isEqualToString:@"z"]) mimoc_key(13);
    else if ([characters isEqualToString:@"m"]) mimoc_key(14);
    else if ([characters isEqualToString:@"l"]) mimoc_key(15);
    else [super keyDown:event];
}
- (void)insertText:(id)value { [self insertText:value replacementRange:NSMakeRange(NSNotFound,0)]; }
- (void)insertText:(id)value replacementRange:(NSRange)range {
    if (!desktop_mode) return;
    self.marked = nil;
    NSString *s = [value isKindOfClass:[NSAttributedString class]] ? [value string] : value;
    NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding]; desktop_event(2, 0, 0, 0, 0, d.bytes, d.length);
}
- (BOOL)hasMarkedText { return self.marked.length > 0; }
- (NSRange)markedRange { return self.hasMarkedText ? NSMakeRange(0,self.marked.length) : NSMakeRange(NSNotFound,0); }
- (NSRange)selectedRange { return NSMakeRange(NSNotFound,0); }
- (void)setMarkedText:(id)value selectedRange:(NSRange)selected replacementRange:(NSRange)replacement {
    self.marked = [value isKindOfClass:[NSAttributedString class]] ? value : [[NSAttributedString alloc] initWithString:value];
}
- (void)unmarkText { if (self.hasMarkedText) [self insertText:self.marked]; }
- (NSArray<NSAttributedStringKey> *)validAttributesForMarkedText { return @[]; }
- (NSAttributedString *)attributedSubstringForProposedRange:(NSRange)range actualRange:(NSRangePointer)actual { return nil; }
- (NSUInteger)characterIndexForPoint:(NSPoint)point { return NSNotFound; }
- (NSRect)firstRectForCharacterRange:(NSRange)range actualRange:(NSRangePointer)actual {
    return [self.window convertRectToScreen:[self convertRect:NSMakeRect(8,self.bounds.size.height-40,1,16) toView:nil]];
}
- (void)doCommandBySelector:(SEL)selector { }
- (void)keyUp:(NSEvent *)event { if (desktop_mode) desktop_event(1, desktopKey(event.keyCode), 0, 0, 0, NULL, 0); }
- (void)mouseUp:(NSEvent *)event { if (desktop_mode) pointerEvent(self, event, 4); }
- (void)mouseMoved:(NSEvent *)event {
    if (desktop_mode) pointerEvent(self, event, 5);
    else if (hover_callback) {
        NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
        hover_callback((int)floor(p.x/display_scale), (int)floor(p.y/display_scale));
    }
}
- (void)mouseDragged:(NSEvent *)event { if (desktop_mode) pointerEvent(self, event, 5); }
- (void)scrollWheel:(NSEvent *)event {
    if (desktop_mode) { NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
        double multiplier = event.hasPreciseScrollingDeltas ? 1.0 : 8.0;
        wheel_x -= event.scrollingDeltaX * multiplier / display_scale;
        wheel_y -= event.scrollingDeltaY * multiplier / display_scale;
        int dx = (int)trunc(wheel_x), dy = (int)trunc(wheel_y);
        wheel_x -= dx; wheel_y -= dy;
        if (dx || dy) desktop_event(6, dx, (int)(p.x/display_scale), (int)(p.y/display_scale), dy, NULL, 0); }

}
- (void)mouseDown:(NSEvent *)event {
    if (desktop_mode) { pointerEvent(self, event, 3); return; }
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    mimoc_click((int)(point.x / display_scale), (int)(point.y / display_scale));
}
@end

@interface MimocDelegate : NSObject <NSWindowDelegate>
@end
@implementation MimocDelegate
- (void)windowWillClose:(NSNotification *)notification { [NSApp terminate:nil]; }
- (void)windowDidResize:(NSNotification *)notification {
    if (desktop_mode && desktop_resize) desktop_resize((int)floor(canvas.bounds.size.width/display_scale), (int)floor(canvas.bounds.size.height/display_scale));
    [canvas setNeedsDisplay:YES];
}
- (void)windowDidResignKey:(NSNotification *)notification { if (desktop_mode) desktop_event(7, 0, 0, 0, 0, NULL, 0); }
- (void)tick:(NSTimer *)timer { mimoc_tick(mimoc_now_ms()); }
@end

void mimoc_window_redraw(void) {
    [canvas setNeedsDisplay:YES];
}

void mimoc_window_run(const uint8_t *framebuffer, int width, int height, int scale, const char *title) {
    @autoreleasepool {
        pixels = framebuffer;
        display_width = width;
        display_height = height;
        display_scale = scale;
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        NSRect rect = NSMakeRect(0, 0, width * scale, height * scale);
        NSWindow *window = [[NSWindow alloc] initWithContentRect:rect
            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | (desktop_mode ? NSWindowStyleMaskResizable : 0)
            backing:NSBackingStoreBuffered defer:NO];
        window.acceptsMouseMovedEvents = YES;
        window.contentMinSize = NSMakeSize(128 * scale, 64 * scale);
        window.title = [NSString stringWithUTF8String:title];
        MimocDelegate *delegate = [MimocDelegate new];
        window.delegate = delegate;
        canvas = [[MimocView alloc] initWithFrame:rect];
        window.contentView = canvas;
        [window center];
        [window makeKeyAndOrderFront:nil];
        [window makeFirstResponder:canvas];
        [NSApp activateIgnoringOtherApps:YES];
        [NSTimer scheduledTimerWithTimeInterval:1.0 / 60.0 target:delegate selector:@selector(tick:) userInfo:nil repeats:YES];
        [NSApp run];
    }
}

// Separate mode: logical pixels are AppKit points / scale, never backing pixels.
void mimoc_desktop_run(const uint8_t *buffer, int width, int height, int scale, const char *title,
    void (*event)(int,int,int,int,int,const char *,size_t), void (*resize)(int,int)) {
    desktop_mode = YES; desktop_event = event; desktop_resize = resize;
    mimoc_window_run(buffer, width, height, scale, title);
}
