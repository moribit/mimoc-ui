#import <AppKit/AppKit.h>
#include <stdint.h>

extern void mimoc_key(int key);
extern void mimoc_click(int x, int y);
extern void mimoc_tick(uint32_t now_ms);

uint32_t mimoc_now_ms(void) {
    return (uint32_t)(uint64_t)([NSProcessInfo processInfo].systemUptime * 1000.0);
}

static const uint8_t *pixels;
static NSView *canvas;
static int display_width;
static int display_height;
static int display_scale;

@interface MimocView : NSView
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
    else [super keyDown:event];
}
- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    mimoc_click((int)(point.x / display_scale), (int)(point.y / display_scale));
}
@end

@interface MimocDelegate : NSObject <NSWindowDelegate>
@end
@implementation MimocDelegate
- (void)windowWillClose:(NSNotification *)notification { [NSApp terminate:nil]; }
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
            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
            backing:NSBackingStoreBuffered defer:NO];
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
