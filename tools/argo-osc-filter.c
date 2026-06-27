/*
 * argo-osc-filter
 *
 * Transparent PTY relay that rewrites iTerm2 OSC 1337 PNG inline images into
 * Kitty graphics protocol for Ghostty.
 *
 * Usage: argo-osc-filter <command> [args...]
 *
 * This helper follows the same architecture as Liney's Apache-2.0
 * liney-osc-filter: run the real command on an inner PTY, relay bytes both
 * ways, and translate only the shell->terminal image sequence that Ghostty
 * already knows how to render as Kitty graphics. Argo keeps non-converted OSC
 * terminators byte-compatible by preserving BEL vs ST.
 */

#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>
#include <util.h>

#define KITTY_CHUNK 4096
#define MAX_OSC_BYTES (64 * 1024 * 1024)

static struct termios g_saved_termios;
static int g_termios_saved = 0;
static volatile sig_atomic_t g_winch_pending = 0;

static void restore_termios(void) {
    if (g_termios_saved) {
        tcsetattr(STDIN_FILENO, TCSANOW, &g_saved_termios);
        g_termios_saved = 0;
    }
}

static void on_winch(int sig) {
    (void)sig;
    g_winch_pending = 1;
}

static int write_all(int fd, const unsigned char *buf, size_t len) {
    size_t off = 0;
    while (off < len) {
        ssize_t n = write(fd, buf + off, len - off);
        if (n < 0) {
            if (errno == EINTR) {
                continue;
            }
            return -1;
        }
        if (n == 0) {
            errno = EIO;
            return -1;
        }
        off += (size_t)n;
    }
    return 0;
}

static int emit_kitty_image(int out, const unsigned char *b64, size_t len) {
    static const char esc_g[] = "\x1b_G";
    static const char st[] = "\x1b\\";

    size_t off = 0;
    int first = 1;
    while (off < len) {
        size_t remaining = len - off;
        size_t chunk = remaining > KITTY_CHUNK ? KITTY_CHUNK : remaining;
        int more = (off + chunk < len) ? 1 : 0;

        char control[64];
        int control_len;
        if (first) {
            control_len = snprintf(control, sizeof(control), "a=T,f=100,m=%d;", more);
        } else {
            control_len = snprintf(control, sizeof(control), "m=%d;", more);
        }
        if (control_len < 0) {
            return -1;
        }

        if (write_all(out, (const unsigned char *)esc_g, sizeof(esc_g) - 1) < 0 ||
            write_all(out, (const unsigned char *)control, (size_t)control_len) < 0 ||
            write_all(out, b64 + off, chunk) < 0 ||
            write_all(out, (const unsigned char *)st, sizeof(st) - 1) < 0) {
            return -1;
        }

        off += chunk;
        first = 0;
    }
    return 0;
}

static int is_png_base64(const unsigned char *b64, size_t len) {
    static const char png_prefix[] = "iVBORw0KGgo";
    size_t prefix_len = sizeof(png_prefix) - 1;
    return len >= prefix_len && memcmp(b64, png_prefix, prefix_len) == 0;
}

static int try_translate_osc(int out, const unsigned char *body, size_t len) {
    static const char prefix[] = "1337;File=";
    size_t prefix_len = sizeof(prefix) - 1;

    if (len < prefix_len || memcmp(body, prefix, prefix_len) != 0) {
        return 0;
    }

    const unsigned char *separator = NULL;
    for (size_t i = len; i > prefix_len; i--) {
        if (body[i - 1] == ':') {
            separator = body + i - 1;
            break;
        }
    }
    if (separator == NULL) {
        return 0;
    }

    const unsigned char *payload = separator + 1;
    size_t payload_len = (size_t)((body + len) - payload);
    if (payload_len == 0 || !is_png_base64(payload, payload_len)) {
        return 0;
    }

    return emit_kitty_image(out, payload, payload_len) == 0 ? 1 : 0;
}

typedef enum {
    S_GROUND,
    S_ESC,
    S_OSC_SNIFF,
    S_OSC_IMAGE,
    S_OSC_PASS,
    S_OSC_PASS_ESC
} scan_state;

typedef struct {
    scan_state state;
    unsigned char *buf;
    size_t len;
    size_t cap;
    int img_esc;
    int overflow;
} osc_scanner;

static void scanner_init(osc_scanner *s) {
    memset(s, 0, sizeof(*s));
    s->state = S_GROUND;
}

static int scanner_reserve(osc_scanner *s, size_t extra) {
    if (s->len + extra <= s->cap) {
        return 0;
    }

    size_t cap = s->cap ? s->cap : 4096;
    while (cap < s->len + extra) {
        cap *= 2;
    }

    unsigned char *next = realloc(s->buf, cap);
    if (next == NULL) {
        return -1;
    }

    s->buf = next;
    s->cap = cap;
    return 0;
}

/* Returns 1 when the OSC buffer is over the cap and the caller should switch to
 * passthrough, 0 on success, and -1 on allocation failure. */
static int scanner_push(osc_scanner *s, unsigned char c) {
    if (s->len + 1 > MAX_OSC_BYTES) {
        s->overflow = 1;
        return 1;
    }
    if (scanner_reserve(s, 1) < 0) {
        return -1;
    }
    s->buf[s->len++] = c;
    return 0;
}

static int flush_buffer_verbatim(int out, osc_scanner *s) {
    static const unsigned char osc_intro[] = {0x1b, ']'};

    if (write_all(out, osc_intro, sizeof(osc_intro)) < 0) {
        return -1;
    }
    if (s->len > 0 && write_all(out, s->buf, s->len) < 0) {
        return -1;
    }
    s->len = 0;
    return 0;
}

static int finish_osc_body(
    int out,
    osc_scanner *s,
    const unsigned char *terminator,
    size_t terminator_len
) {
    int handled = 0;
    if (!s->overflow) {
        handled = try_translate_osc(out, s->buf, s->len);
    }

    if (!handled) {
        if (flush_buffer_verbatim(out, s) < 0 ||
            write_all(out, terminator, terminator_len) < 0) {
            return -1;
        }
    }

    s->len = 0;
    s->overflow = 0;
    s->img_esc = 0;
    return 0;
}

static int overflow_to_pass(int out, osc_scanner *s, unsigned char current) {
    if (flush_buffer_verbatim(out, s) < 0) {
        return -1;
    }
    if (write_all(out, &current, 1) < 0) {
        return -1;
    }
    s->overflow = 0;
    s->img_esc = 0;
    s->state = S_OSC_PASS;
    return 0;
}

static int push_image_byte(osc_scanner *s, int out, unsigned char c) {
    int push_result = scanner_push(s, c);
    if (push_result < 0) {
        return -1;
    }
    if (push_result > 0) {
        return overflow_to_pass(out, s, c);
    }
    return 0;
}

static int scanner_feed(osc_scanner *s, int out, const unsigned char *in, size_t n) {
    size_t i = 0;

    while (i < n) {
        unsigned char c = in[i];
        switch (s->state) {
        case S_GROUND: {
            size_t start = i;
            while (i < n && in[i] != 0x1b) {
                i++;
            }
            if (i > start && write_all(out, in + start, i - start) < 0) {
                return -1;
            }
            if (i < n) {
                s->state = S_ESC;
                i++;
            }
            break;
        }
        case S_ESC:
            if (c == ']') {
                s->state = S_OSC_SNIFF;
                s->len = 0;
                s->overflow = 0;
            } else {
                unsigned char esc = 0x1b;
                if (write_all(out, &esc, 1) < 0 ||
                    write_all(out, &c, 1) < 0) {
                    return -1;
                }
                s->state = S_GROUND;
            }
            i++;
            break;
        case S_OSC_SNIFF: {
            if (c == 0x07) {
                static const unsigned char bel[] = {0x07};
                if (finish_osc_body(out, s, bel, sizeof(bel)) < 0) {
                    return -1;
                }
                s->state = S_GROUND;
                i++;
                break;
            }

            int push_result = scanner_push(s, c);
            if (push_result < 0) {
                return -1;
            }
            if (push_result > 0) {
                if (overflow_to_pass(out, s, c) < 0) {
                    return -1;
                }
                i++;
                break;
            }
            i++;

            static const char prefix[] = "1337;File=";
            size_t prefix_len = sizeof(prefix) - 1;
            if (s->len >= prefix_len) {
                if (memcmp(s->buf, prefix, prefix_len) == 0) {
                    s->state = S_OSC_IMAGE;
                    s->img_esc = 0;
                } else {
                    if (flush_buffer_verbatim(out, s) < 0) {
                        return -1;
                    }
                    s->state = S_OSC_PASS;
                }
            }
            break;
        }
        case S_OSC_IMAGE:
            if (s->img_esc) {
                s->img_esc = 0;
                if (c == '\\') {
                    static const unsigned char st[] = {0x1b, '\\'};
                    if (finish_osc_body(out, s, st, sizeof(st)) < 0) {
                        return -1;
                    }
                    s->state = S_GROUND;
                    i++;
                    break;
                }
                if (push_image_byte(s, out, 0x1b) < 0) {
                    return -1;
                }
                if (s->state == S_OSC_PASS) {
                    if (write_all(out, &c, 1) < 0) {
                        return -1;
                    }
                    i++;
                    break;
                }
                if (push_image_byte(s, out, c) < 0) {
                    return -1;
                }
                i++;
                break;
            }

            if (c == 0x07) {
                static const unsigned char bel[] = {0x07};
                if (finish_osc_body(out, s, bel, sizeof(bel)) < 0) {
                    return -1;
                }
                s->state = S_GROUND;
                i++;
                break;
            }
            if (c == 0x1b) {
                s->img_esc = 1;
                i++;
                break;
            }
            if (push_image_byte(s, out, c) < 0) {
                return -1;
            }
            i++;
            break;
        case S_OSC_PASS:
            if (c == 0x07) {
                if (write_all(out, &c, 1) < 0) {
                    return -1;
                }
                s->state = S_GROUND;
            } else if (c == 0x1b) {
                s->state = S_OSC_PASS_ESC;
            } else {
                if (write_all(out, &c, 1) < 0) {
                    return -1;
                }
            }
            i++;
            break;
        case S_OSC_PASS_ESC: {
            unsigned char esc = 0x1b;
            if (write_all(out, &esc, 1) < 0 ||
                write_all(out, &c, 1) < 0) {
                return -1;
            }
            s->state = (c == '\\') ? S_GROUND : S_OSC_PASS;
            i++;
            break;
        }
        }
    }

    return 0;
}

static void sync_winsize(int master_fd) {
    struct winsize ws;
    if (ioctl(STDIN_FILENO, TIOCGWINSZ, &ws) == 0) {
        ioctl(master_fd, TIOCSWINSZ, &ws);
    }
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: argo-osc-filter <command> [args...]\n");
        return 2;
    }

    struct winsize ws;
    int have_ws = (ioctl(STDIN_FILENO, TIOCGWINSZ, &ws) == 0);

    struct termios tio;
    int have_tio = (tcgetattr(STDIN_FILENO, &tio) == 0);

    int master_fd = -1;
    pid_t pid = forkpty(
        &master_fd,
        NULL,
        have_tio ? &tio : NULL,
        have_ws ? &ws : NULL
    );
    if (pid < 0) {
        perror("forkpty");
        return 1;
    }

    if (pid == 0) {
        execvp(argv[1], &argv[1]);
        perror("execvp");
        _exit(127);
    }

    if (have_tio) {
        struct termios raw = tio;
        cfmakeraw(&raw);
        if (tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0) {
            g_saved_termios = tio;
            g_termios_saved = 1;
            atexit(restore_termios);
        }
    }

    signal(SIGWINCH, on_winch);
    signal(SIGPIPE, SIG_IGN);

    osc_scanner scanner;
    scanner_init(&scanner);

    unsigned char input_buf[65536];
    unsigned char output_buf[65536];
    int stdin_open = 1;
    int child_done = 0;

    for (;;) {
        if (g_winch_pending) {
            g_winch_pending = 0;
            sync_winsize(master_fd);
        }

        fd_set rfds;
        FD_ZERO(&rfds);
        if (stdin_open) {
            FD_SET(STDIN_FILENO, &rfds);
        }
        FD_SET(master_fd, &rfds);

        int maxfd = master_fd;
        if (stdin_open && STDIN_FILENO > maxfd) {
            maxfd = STDIN_FILENO;
        }

        int rv = select(maxfd + 1, &rfds, NULL, NULL, NULL);
        if (rv < 0) {
            if (errno == EINTR) {
                continue;
            }
            break;
        }

        if (stdin_open && FD_ISSET(STDIN_FILENO, &rfds)) {
            ssize_t n = read(STDIN_FILENO, input_buf, sizeof(input_buf));
            if (n > 0) {
                if (write_all(master_fd, input_buf, (size_t)n) < 0) {
                    break;
                }
            } else if (n == 0) {
                stdin_open = 0;
            } else if (errno != EINTR) {
                stdin_open = 0;
            }
        }

        if (FD_ISSET(master_fd, &rfds)) {
            ssize_t n = read(master_fd, output_buf, sizeof(output_buf));
            if (n > 0) {
                if (scanner_feed(&scanner, STDOUT_FILENO, output_buf, (size_t)n) < 0) {
                    break;
                }
            } else if (n == 0 || errno == EIO) {
                child_done = 1;
                break;
            } else if (errno != EINTR) {
                break;
            }
        }
    }

    restore_termios();
    free(scanner.buf);

    int status = 0;
    if (waitpid(pid, &status, child_done ? 0 : WNOHANG) == pid) {
        if (WIFEXITED(status)) {
            return WEXITSTATUS(status);
        }
        if (WIFSIGNALED(status)) {
            return 128 + WTERMSIG(status);
        }
    }

    if (!child_done) {
        kill(pid, SIGHUP);
        waitpid(pid, &status, 0);
    }
    return 0;
}
