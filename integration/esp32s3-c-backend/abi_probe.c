#include <stdint.h>
/* Inspect this object with Espressif objdump; no runtime/firmware required.
   Pairs: size/alignment of pointer, long long, double, long double, uint64_t. */
const uint32_t mimoc_gcc_abi[] = {
    sizeof(void *), _Alignof(void *), sizeof(long long), _Alignof(long long),
    sizeof(double), _Alignof(double), sizeof(long double), _Alignof(long double),
    sizeof(uint64_t), _Alignof(uint64_t)
};
