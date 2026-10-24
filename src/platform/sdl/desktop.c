/* Generic SDL3 window/pixel bridge. Rendering and application policy remain in Zig. */
#include <SDL3/SDL.h>
#include <stdint.h>
static SDL_Window *window;
static SDL_Renderer *renderer;
static SDL_Texture *textures[3];
int mimoc_sdl_open(const char *title, int fullscreen) {
    if (!SDL_Init(SDL_INIT_VIDEO)) return 0;
    window = SDL_CreateWindow(title,1280,720,SDL_WINDOW_RESIZABLE|SDL_WINDOW_HIGH_PIXEL_DENSITY|(fullscreen?SDL_WINDOW_FULLSCREEN:0));
    if (!window) return 0;
    SDL_SetWindowMinimumSize(window,64,128);
    renderer=SDL_CreateRenderer(window,NULL);
    if (!renderer) return 0;
    SDL_SetRenderVSync(renderer,1);
    SDL_HideCursor();
    return 1;
}
const char *mimoc_sdl_error(void) {return SDL_GetError();}
void mimoc_sdl_close(void) {
    for(int i=0;i<3;i++) if(textures[i]) {SDL_DestroyTexture(textures[i]); textures[i]=NULL;}
    SDL_DestroyRenderer(renderer); SDL_DestroyWindow(window); SDL_Quit();
}
/* 1 quit, 2 Space down, 3 Space up, 4 focus lost, 5 fullscreen, 6 focus gained */
int mimoc_sdl_poll(void) {
    SDL_Event e;
    while(SDL_PollEvent(&e)) {
        if(e.type==SDL_EVENT_QUIT) return 1;
        if(e.type==SDL_EVENT_WINDOW_FOCUS_LOST) return 4;
        if(e.type==SDL_EVENT_WINDOW_FOCUS_GAINED) return 6;
        if(e.type==SDL_EVENT_KEY_DOWN && !e.key.repeat) {
            if(e.key.key==SDLK_ESCAPE) return 1;
            if(e.key.key==SDLK_F11) return 5;
            if(e.key.key==SDLK_SPACE) return 2;
        }
        if(e.type==SDL_EVENT_KEY_UP && e.key.key==SDLK_SPACE) return 3;
    }
    return 0;
}
uint64_t mimoc_sdl_time(void) {return SDL_GetTicksNS();}
void mimoc_sdl_delay(void) {SDL_Delay(2);}
void mimoc_sdl_fullscreen(void) {SDL_SetWindowFullscreen(window,!(SDL_GetWindowFlags(window)&SDL_WINDOW_FULLSCREEN));}
void mimoc_sdl_size(int *w,int *h) {SDL_GetRenderOutputSize(renderer,w,h);}
void mimoc_sdl_begin(void) {SDL_SetRenderDrawColor(renderer,15,23,21,255); SDL_RenderClear(renderer);}
/* Caller provides row-major ARGB8888. Destination is physical pixels; no logical scaling. */
int mimoc_sdl_present(int slot,const uint32_t *pixels,int w,int h,int x,int y,int scale) {
    if(slot<0 || slot>=3 || scale<1) return 0;
    if(!textures[slot]) {
        textures[slot]=SDL_CreateTexture(renderer,SDL_PIXELFORMAT_ARGB8888,SDL_TEXTUREACCESS_STREAMING,w,h);
        if(!textures[slot]) return 0;
        SDL_SetTextureScaleMode(textures[slot],SDL_SCALEMODE_NEAREST);
    }
    if(!SDL_UpdateTexture(textures[slot],NULL,pixels,w*4)) return 0;
    SDL_FRect dst={(float)x,(float)y,(float)(w*scale),(float)(h*scale)};
    return SDL_RenderTexture(renderer,textures[slot],NULL,&dst);
}
void mimoc_sdl_end(void) {SDL_RenderPresent(renderer);}
#ifdef MIMOC_SDL_TEST
/* Compiled only into the optional integration probe. */
void mimoc_sdl_test_key(int down,int repeat) {
    SDL_Event e={0};e.type=down?SDL_EVENT_KEY_DOWN:SDL_EVENT_KEY_UP;
    e.key.key=SDLK_SPACE;e.key.repeat=repeat!=0;SDL_PushEvent(&e);
}
void mimoc_sdl_test_focus(void) {SDL_Event e={0};e.type=SDL_EVENT_WINDOW_FOCUS_LOST;SDL_PushEvent(&e);}
#endif
