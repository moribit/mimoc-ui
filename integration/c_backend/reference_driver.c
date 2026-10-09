#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
int mimoc_reference_render(uint32_t index, uint8_t *buffer, size_t len);
int main(int argc, char **argv) {
    if (argc != 2) return 4;
    const uint32_t count = (uint32_t)strtoul(argv[1], NULL, 10);
    uint8_t frame[1024];
    for (uint32_t i=0; i<count; ++i) {
        if (mimoc_reference_render(i, frame, sizeof frame)) return 2;
        if (fwrite(frame, 1, sizeof frame, stdout) != sizeof frame) return 3;
    }
    return 0;
}
