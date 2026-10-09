#ifndef MIMOC_UI_SMOKE_H
#define MIMOC_UI_SMOKE_H
#include <stddef.h>
#include <stdint.h>
/* Verification ABI only, not a production API commitment. */
void mimoc_ui_smoke_init(void);
void mimoc_ui_smoke_step(uint32_t now_ms, uint32_t input_mask);
uint32_t mimoc_ui_smoke_render(uint8_t *framebuffer, size_t len);
#endif
