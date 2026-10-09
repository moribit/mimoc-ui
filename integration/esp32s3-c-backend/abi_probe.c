#include <stdint.h>
#include <stddef.h>
#define ABI(T) sizeof(T), _Alignof(T)
struct mixed {
    uint8_t prefix;
    unsigned long long integer;
    double number;
    uint8_t suffix;
};
/* Order is shared with abi_expect.zig and the verification script. */
const uint32_t mimoc_gcc_abi[] = {
    ABI(char), ABI(signed char), ABI(unsigned char),
    ABI(short), ABI(unsigned short), ABI(int), ABI(unsigned int),
    ABI(long), ABI(unsigned long), ABI(long long), ABI(unsigned long long),
    ABI(float), ABI(double), ABI(long double), ABI(void *),
    ABI(size_t), ABI(ptrdiff_t), ABI(intptr_t), ABI(uintptr_t),
    ABI(int8_t), ABI(uint8_t), ABI(int16_t), ABI(uint16_t),
    ABI(int32_t), ABI(uint32_t), ABI(int64_t), ABI(uint64_t),
    sizeof(struct mixed), _Alignof(struct mixed), offsetof(struct mixed, prefix),
    offsetof(struct mixed, integer), offsetof(struct mixed, number), offsetof(struct mixed, suffix),
};
