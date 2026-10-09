#include "smoke.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
void c_mimoc_ui_smoke_init(void);
void c_mimoc_ui_smoke_step(uint32_t, uint32_t);
uint32_t c_mimoc_ui_smoke_render(uint8_t *, size_t);
static unsigned frames;
static unsigned changes;
static uint8_t previous[1024];
static void init(void) { mimoc_ui_smoke_init(); c_mimoc_ui_smoke_init(); }
static void step(uint32_t now, uint32_t mask) { mimoc_ui_smoke_step(now,mask); c_mimoc_ui_smoke_step(now,mask); }
static void compare(const char *name, uint32_t now, uint32_t mask) {
    uint8_t a[1026], b[1026]; memset(a,0xa5,sizeof a); memset(b,0xa5,sizeof b);
    if (mimoc_ui_smoke_render(a+1,1024) || c_mimoc_ui_smoke_render(b+1,1024)) { fprintf(stderr,"render failed: %s\n",name); exit(1); }
    if (a[0]!=0xa5 || a[1025]!=0xa5 || b[0]!=0xa5 || b[1025]!=0xa5) { fprintf(stderr,"buffer overrun\n"); exit(1); }
    for (size_t i=0; i<1024; i++) if(a[i+1]!=b[i+1]) {
        unsigned diff=a[i+1]^b[i+1], bit=0; while(!(diff&(1u<<bit))) bit++;
        fprintf(stderr,"FAIL %s frame=%u time=%u mask=0x%x byte=%zu pixel=(%zu,%zu) native=0x%02x C=0x%02x\n",name,frames,now,mask,i,i%128,(i/128)*8+bit,a[i+1],b[i+1]); exit(1);
    }
    if(frames && memcmp(previous,a+1,1024)) changes++;
    memcpy(previous,a+1,1024); frames++;
}
int main(void) {
    init();
    uint8_t invalid[1024]; memset(invalid,0x5a,sizeof invalid);
    if(mimoc_ui_smoke_render(NULL,1024)!=1 || c_mimoc_ui_smoke_render(NULL,1024)!=1 ||
       mimoc_ui_smoke_render(invalid,1023)!=1 || c_mimoc_ui_smoke_render(invalid,1023)!=1) return 1;
    for(size_t i=0;i<1024;i++) if(invalid[i]!=0x5a) return 1;
    compare("initial",0,0);
    step(0,8); compare("focus-right",0,8);
    step(0,2); compare("focus-down",0,2);
    step(0,16); compare("selection-animation-t0",0,16);
    const uint32_t times[]={100,250,500};
    for(size_t i=0;i<3;i++) { step(times[i],0); compare("animation",times[i],0); }
    step(600,32); compare("back-reset",600,32);
    step(850,0); compare("reset-settled",850,0);
    /* Cross the u32 time boundary with an active track. */
    init(); step(UINT32_MAX-100,16); compare("clock-wrap-start",UINT32_MAX-100,16);
    step(50,0); compare("clock-wrap-middle",50,0); step(200,0); compare("clock-wrap-settled",200,0);
    /* Reinitialization, continuous retargeting, simultaneous masks and deterministic PRNG. */
    init(); uint32_t rng=0x4d494d4fu, now=0;
    for(unsigned i=0;i<2048;i++) {
        rng=rng*1664525u+1013904223u; now+=(rng>>24)%33;
        uint32_t choice=(rng>>16)%9;
        uint32_t mask=choice<6 ? 1u<<choice : choice==6 ? rng&63u : 0;
        step(now,mask); compare("seeded-sequence",now,mask);
    }
    if(changes<20) { fprintf(stderr,"insufficient visible coverage: %u\n",changes); return 1; }
    printf("PASS: %u frames x 1024 bytes equal; %u visible changes; seed=0x4d494d4f; ABI guards/canaries OK\n",frames,changes);
    return 0;
}
