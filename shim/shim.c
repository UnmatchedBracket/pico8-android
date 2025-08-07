// i forgot why this define is here
#define _GNU_SOURCE
#include <SDL2/SDL.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <dlfcn.h>


#include <stdio.h>
// #include <string.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <unistd.h>

#define FINDSDL(VAR, NAME) \
    if (!(VAR)) { \
        VAR = dlsym(RTLD_NEXT, #NAME); \
        if (!(VAR)) { \
            fprintf(stderr, "Error: could not find %s\n", #NAME); \
            abort(); \
        } \
    }

#define INPUT_FIFO "/tmp/pico8_in"
#define OUTPUT_FIFO "/tmp/pico8_out"
static int input_fd = -1;
static int output_fd = -1;

static Uint8 keystate[256];

static uint8_t* picoram = NULL;
#define PICORAM_INDEX_ISINEDITOR 0x2586c
#define PICORAM_INDEX_ISINGAME 0x25868
// this address is garbage lol
#define PICORAM_INDEX_ISPAUSED 0x3726c
// devkit address is *probably* correct?
#define PICORAM_INDEX_DEVKIT 0x2c8e5

#define PIDOT_EVENT_MOUSEEV 1
#define PIDOT_EVENT_KEYEV 2
#define PIDOT_EVENT_CHAREV 3

#define IN_PACKET_SIZE 8
static char in_packet[IN_PACKET_SIZE];
int picosync_try_read() {

    int available = 0;
    if (ioctl(input_fd, FIONREAD, &available) == -1) {
        perror("ioctl");
        abort();
    }

    if (available >= IN_PACKET_SIZE) {
        ssize_t n = read(input_fd, in_packet, IN_PACKET_SIZE);
        if (n == IN_PACKET_SIZE) {
            for (int i = 0; i < IN_PACKET_SIZE; ++i)
                printf("%02x ", (unsigned char)in_packet[i]);
            printf("\n");
            return true;
        } else if (n == 0) {
            printf("EOF reached\n");
            abort();
        } else if (n < 0) {
            perror("read");
            abort();
        }
    } else {
        return false;
    }
}

static bool false_start = true;

DECLSPEC int SDLCALL SDL_Init(Uint32 flags) {
    static int (*realf)(Uint32) = NULL;
    FINDSDL(realf, SDL_Init);

    if (false_start) {
        printf("false start\n");
        false_start = false;
    } else {
        printf("making fifos\n");
        mkfifo(INPUT_FIFO, 0666);
        mkfifo(OUTPUT_FIFO, 0666);

        printf("opening input\n");
        input_fd = open(INPUT_FIFO, O_RDONLY);
        printf("opening output\n");
        output_fd = open(OUTPUT_FIFO, O_WRONLY);
        printf("done opening\n");
    }

    return realf(flags);
}

static SDL_Surface* currentsurf = NULL;

DECLSPEC SDL_Window* SDLCALL SDL_CreateWindow(const char *title,
                                                      int x, int y, int w,
                                                      int h, Uint32 flags) {
    static SDL_Window* (*realf)(const char*, int, int, int, int, Uint32) = NULL;
    FINDSDL(realf, SDL_CreateWindow);
    printf("SDL_CreateWindow(*,*,*,*,*,%d)\n", flags);
    flags &= ~(SDL_WINDOW_FULLSCREEN_DESKTOP | SDL_WINDOW_RESIZABLE);
    SDL_Window* window = realf(title, x, y, 128, 128, flags);
    currentsurf = SDL_GetWindowSurface(window);
    printf("surf yoinked direct from window");
    return window;
}

static Uint64 last_frame = 0;
// this comes in at about 67fps
#define MINFRAMEMS 15

void pico_send_vid_data() {
    if (currentsurf != NULL && currentsurf->format->format == SDL_PIXELFORMAT_XRGB8888) {
        /*uint32_t pixelcount = (
            (uint32_t)(currentsurf->w)
            * (uint32_t)(currentsurf->h)
            * (uint32_t)(currentsurf->format->BytesPerPixel)
        );
        write(output_fd, "PICO8SYNC", 9);
        write(output_fd, currentsurf->pixels, pixelcount);*/
        static uint8_t screenbuf[128*128*3];
        for (uint16_t i = 0; i < 128*128; i++) {
            screenbuf[i*3+0] = ((uint8_t*)currentsurf->pixels)[i*4+2];
            screenbuf[i*3+1] = ((uint8_t*)currentsurf->pixels)[i*4+1];
            screenbuf[i*3+2] = ((uint8_t*)currentsurf->pixels)[i*4+0];
        }
        static u_int8_t custombuf[1];

        uint8_t navstate = 0x00;
        if (picoram != NULL) {
            if (picoram[PICORAM_INDEX_ISINEDITOR]) {
                navstate |= 0x01;
            }
            if (picoram[PICORAM_INDEX_ISINGAME]) {
                navstate |= 0x02;
            }
            if (picoram[PICORAM_INDEX_DEVKIT] & 0x1) {
                navstate |= 0x04;
            }
        }
        custombuf[0] = navstate;

        write(output_fd, "PICO8SYNC", 9);
        write(output_fd, custombuf, sizeof(custombuf));
        write(output_fd, screenbuf, 128*128*3);
        // printf("========\n");
        // for (uint32_t i = 0; i < pixelcount; i++) {
        //     printf("%02x", ((uint8_t*)currentsurf->pixels)[i]);
        // }
    }
    Uint64 ticks_now = SDL_GetTicks64();
    if (last_frame + MINFRAMEMS > ticks_now) {
        SDL_Delay(last_frame + MINFRAMEMS - ticks_now);
    }
    last_frame = ticks_now;
}

DECLSPEC int SDLCALL SDL_UpdateWindowSurface(SDL_Window * window) {
    static int (*realf)(SDL_Window*) = NULL;
    FINDSDL(realf, SDL_UpdateWindowSurface);
    // printf("we are so UpdateWindowSurfacing\n");
    pico_send_vid_data();
    return realf(window);
}

DECLSPEC void SDLCALL SDL_RenderPresent(SDL_Renderer * renderer) {
    static void (*realf)(SDL_Renderer*) = NULL;
    FINDSDL(realf, SDL_RenderPresent);
    // printf("we are so RenderPresenting\n");
    pico_send_vid_data();
    return realf(renderer);
}

DECLSPEC SDL_Surface * SDLCALL SDL_GetWindowSurface(SDL_Window * window) {
    static SDL_Surface* (*realf)(SDL_Window* window) = NULL;
    FINDSDL(realf, SDL_GetWindowSurface);
    if (currentsurf == NULL) {
        printf("yoinking surface\n");
    }
    return currentsurf = realf(window);
}

static int mousex = 0;
static int mousey = 0;
static Uint32 mouseb = 0;

static Uint32 lastmod = 0;

DECLSPEC int SDLCALL SDL_PollEvent(SDL_Event * event) {
    static int (*realf)(SDL_Event* event) = NULL;
    FINDSDL(realf, SDL_PollEvent);
    int ret = realf(event);
    if (ret == 1) {
        printf("event %d\n", event->type);
        if (
            event->type == SDL_WINDOWEVENT
        // || event->type == SDL_TEXTINPUT
        ) {
            printf("blocking\n");
            return 0;
        }
        if (event->type == SDL_KEYDOWN || event->type == SDL_KEYUP) {
            event->key.keysym.sym = 0;
            if (event->key.keysym.scancode == SDLK_LCTRL) {
                event->key.keysym.mod = 0;
            }
            // printf(
            //     "KEYEV\n%d %d %d %d %d %d\n",
            //     event->key.windowID,
            //     event->key.state,
            //     event->key.repeat,
            //     event->key.keysym.scancode,
            //     event->key.keysym.sym,
            //     event->key.keysym.mod
            // );
            /*
            typedef struct SDL_KeyboardEvent
            {
                Uint32 type;        /**< ::SDL_KEYDOWN or ::SDL_KEYUP * /
                Uint32 timestamp;   /**< In milliseconds, populated using SDL_GetTicks() * /
                Uint32 windowID;    /**< The window with keyboard focus, if any * /
                Uint8 state;        /**< ::SDL_PRESSED or ::SDL_RELEASED * /
                Uint8 repeat;       /**< Non-zero if this is a key repeat * /
                Uint8 padding2;
                Uint8 padding3;
                SDL_Keysym keysym;  /**< The key that was pressed or released * /
            } SDL_KeyboardEvent;
            */
            // PICO-8, surprisingly, uses scancode
            // // event->key.keysym.scancode = 0;
            // // event->type = SDL_FIRSTEVENT;
        }

        // if (event->type == SDL_TEXTINPUT) {
        //     printf(
        //         "CHAREV\n%02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x\n%s\n",
        //         event->text.text[0], event->text.text[1], event->text.text[2], event->text.text[3], event->text.text[4], event->text.text[5], event->text.text[6], event->text.text[7], event->text.text[8], event->text.text[9], event->text.text[10], event->text.text[11], event->text.text[12], event->text.text[13], event->text.text[14], event->text.text[15], event->text.text[16], event->text.text[17], event->text.text[18], event->text.text[19], event->text.text[20], event->text.text[21], event->text.text[22], event->text.text[23], event->text.text[24], event->text.text[25], event->text.text[26], event->text.text[27], event->text.text[28], event->text.text[29], event->text.text[30], event->text.text[31],
        //         &event->text.text
        //     );
        // }
    } else {
        int result = picosync_try_read();
        // printf("result %d\n", result);
        if (result == true) {
            switch (in_packet[0])
            {
                case PIDOT_EVENT_MOUSEEV:
                    event->type = SDL_FIRSTEVENT;
                    mousex = in_packet[1];
                    mousey = in_packet[2];
                    mouseb = in_packet[3];
                    return 1;
                case PIDOT_EVENT_KEYEV:
                    event->type = event->key.type = in_packet[2] ? SDL_KEYDOWN : SDL_KEYUP;
                    event->key.timestamp = SDL_GetTicks();
                    event->key.windowID = 1;
                    event->key.state = in_packet[2] ? SDL_PRESSED : SDL_RELEASED;
                    event->key.repeat = in_packet[3];
                    event->key.keysym.scancode = in_packet[1];
                    keystate[in_packet[1]] = in_packet[2];
                    event->key.keysym.mod = in_packet[4] + (((Uint16)in_packet[5])<<8);
                    lastmod = event->key.keysym.mod;
                    // printf(
                    //     "FAKE KEYEV\n%d %d %d %d %d %d\n",
                    //     event->key.windowID,
                    //     event->key.state,
                    //     event->key.repeat,
                    //     event->key.keysym.scancode,
                    //     event->key.keysym.sym,
                    //     event->key.keysym.mod
                    // );
                    // if (in_packet[1] == 57 && in_packet[2] == 1) { // uncomment if you need memdumps, then use caps lock
                    //     static char fname[64];
                    //     static int snapcount;
                    //     sprintf(fname, "memdump%03d.dat", snapcount++);
                    //     FILE *file = fopen(fname, "wb");
                    //     if (!file) {
                    //         perror("Failed to open file");
                    //     } else {
                    //         // data, size per item, item count, file
                    //         fwrite(picoram, 1, 0x372b8, file);

                    //         fclose(file);
                    //     }
                    // }
                    return 1;
                case PIDOT_EVENT_CHAREV:
                    event->type = event->text.type = SDL_TEXTINPUT;
                    event->text.timestamp = SDL_GetTicks();
                    event->text.windowID = 1;
                    event->text.text[0] = in_packet[1];
                    event->text.text[1] = 0;
                    return 1;
                default:
                    break;
            }
        }
    }
    return ret;
}

DECLSPEC Uint32 SDLCALL SDL_GetMouseState(int *x, int *y) {
    *x = mousex;
    *y = mousey;
    return mouseb;
}

DECLSPEC SDL_Keymod SDLCALL SDL_GetModState(void) {
    static SDL_Keymod (*realf)() = NULL;
    FINDSDL(realf, SDL_GetModState);
    // printf("mod %d real %d\n", lastmod, realf());
    return lastmod;
}

DECLSPEC const Uint8 *SDLCALL SDL_GetKeyboardState(int *numkeys) {
    *numkeys = 256;
    return &keystate;
}

// static bool recursive_malloc = false;
// void *malloc (size_t __size) {
//     static void* (*realf)(size_t) = NULL;
//     FINDSDL(realf, malloc);
//     if (!recursive_malloc) {
//         recursive_malloc = true;
//         printf("MALLOC with size %d\n", __size);
//         recursive_malloc = false;
//     }
//     return realf(__size);
// }

void *memset (void *__s, int __c, size_t __n) {
    static void* (*realf)(void*, int, size_t) = NULL;
    FINDSDL(realf, memset);
    if (__c == 0 && __n == 0x372b8) {
        printf("PICO-8 RAM identified\n");
        picoram = __s;
    }
    return realf(__s, __c, __n);
}