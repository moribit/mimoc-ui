#import <AppKit/AppKit.h>
#import <CoreText/CoreText.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
static CTLineRef scalarLine(uint32_t scalar) {
    UniChar chars[2]; CFIndex count = 1;
    if (scalar <= 0xffff) chars[0] = scalar;
    else { scalar -= 0x10000; chars[0] = 0xd800 + (scalar >> 10); chars[1] = 0xdc00 + (scalar & 1023); count = 2; }
    CFStringRef string = CFStringCreateWithCharacters(NULL, chars, count);
    CTFontRef base = CTFontCreateWithName(CFSTR("Menlo"), 13, NULL);
    CTFontRef fallback = CTFontCreateForString(base, string, CFRangeMake(0, count));
    NSDictionary *attrs = @{ (__bridge NSString *)kCTFontAttributeName: (__bridge id)fallback, (__bridge NSString *)kCTForegroundColorFromContextAttributeName: @YES };
    NSAttributedString *text = [[NSAttributedString alloc] initWithString:(__bridge NSString *)string attributes:attrs];
    CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)text);
    CFRelease(fallback); CFRelease(base); CFRelease(string); return line;
}
uint8_t mimoc_font_advance(uint32_t scalar) {
    @autoreleasepool { CTLineRef line = scalarLine(scalar); double width = CTLineGetTypographicBounds(line, NULL, NULL, NULL); CFRelease(line); return (uint8_t)fmin(32, fmax(1, ceil(width))); }
}
void mimoc_font_mask(uint32_t scalar, uint8_t *mask) {
    @autoreleasepool {
        uint8_t gray[1024] = {0}; memset(mask, 0, 128);
        CGColorSpaceRef space = CGColorSpaceCreateDeviceGray();
        CGContextRef context = CGBitmapContextCreate(gray, 32, 32, 8, 32, space, kCGImageAlphaNone);
        CGColorSpaceRelease(space); if (!context) return;
        CGContextSetShouldAntialias(context, false); CGContextSetAllowsFontSmoothing(context, false);
        CGContextSetGrayFillColor(context, 1, 1); CGContextSetTextMatrix(context, CGAffineTransformIdentity); CGContextSetTextPosition(context, 0, 19);
        CTLineRef line = scalarLine(scalar); CTLineDraw(line, context);
        for (int y = 0; y < 32; y++) for (int x = 0; x < 32; x++) if (gray[y*32+x] >= 128) mask[y*4+x/8] |= 0x80 >> (x%8);
        CFRelease(line); CGContextRelease(context);
    }
}
