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

@interface MimocView : NSView
@end

@implementation MimocView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor colorWithCalibratedWhite:0.04 alpha:1] setFill];
    NSRectFill(self.bounds);
    [[NSColor colorWithCalibratedWhite:0.92 alpha:1] setFill];
    for (int y = 0; y < 64; ++y) {
        for (int x = 0; x < 128; ++x) {
            if (pixels[(y / 8) * 128 + x] & (1u << (y % 8))) {
                NSRectFill(NSMakeRect(x * 8, y * 8, 8, 8));
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
    else [super keyDown:event];
}
- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    mimoc_click((int)(point.x / 8), (int)(point.y / 8));
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

void mimoc_window_run(const uint8_t *framebuffer) {
    @autoreleasepool {
        pixels = framebuffer;
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        NSRect rect = NSMakeRect(0, 0, 1024, 512);
        NSWindow *window = [[NSWindow alloc] initWithContentRect:rect
            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
            backing:NSBackingStoreBuffered defer:NO];
        window.title = @"Mimoc UI — Virtual SSD1306";
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
