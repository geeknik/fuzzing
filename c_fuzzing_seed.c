/* seed_c_polyglot.c
 *
 * Deliberately dense, syntax-heavy C (C11-ish, gcc/clang-friendly) file
 * for fuzzing the C front-end / compiler.
 *
 * Exercises:
 *   - Preprocessor (macros, stringize, token-paste, conditionals)
 *   - Declarations, qualifiers, storage classes, VLAs, designated init
 *   - Structs, unions, enums, bitfields, anonymous struct/union (C11)
 *   - Function pointers, varargs, inline, _Noreturn, restrict
 *   - _Generic, _Static_assert, _Alignas, _Alignof, _Complex
 *   - Compound literals, initializers, flexible array members
 *   - Atomics, thread-local storage, attributes (for gcc/clang)
 */

#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#warning "This seed is written with C11 in mind; some features may be downgraded."
#endif

#define _GNU_SOURCE 1

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <complex.h>
#include <stdatomic.h>
#include <string.h>

/* --- Preprocessor tricks ------------------------------------------------ */

#define STR_IMPL(x) #x
#define STR(x) STR_IMPL(x)

#define CAT_IMPL(a,b) a##b
#define CAT(a,b) CAT_IMPL(a,b)

/* Variadic macro with __VA_ARGS__ */
#define LOG(kind, fmt, ...) \
    do { \
        fprintf(stderr, "[" kind "] " fmt "\n", ##__VA_ARGS__); \
    } while (0)

/* Conditional expression macro */
#if defined(__GNUC__)
#  define ATTR_UNUSED __attribute__((unused))
#else
#  define ATTR_UNUSED
#endif

_Static_assert(sizeof(int) >= 2, "int too small");
_Static_assert(offsetof(struct { char c; int x; }, x) > 0, "unexpected padding");

/* --- Typedefs, enums, bitfields ----------------------------------------- */

typedef enum {
    KIND_NONE = 0,
    KIND_ALPHA = 1,
    KIND_BETA  = 2,
    KIND_GAMMA = 3
} kind_t;

enum {
    ANON_ZERO,
    ANON_ONE,
    ANON_TWO
};

/* bitfields in nested struct */
struct Flags {
    unsigned a:1;
    unsigned b:2;
    unsigned c:3;
    unsigned :2;   /* unnamed padding */
    unsigned d:8;
};

/* --- Structs, unions, anonymous members, flexible arrays ---------------- */

struct Inner {
    int   x;
    float y;
};

union Value {
    int         i;
    float       f;
    double      d;
    const char *s;
};

struct Node {
    int id;
    kind_t kind;
    union {
        struct Inner inner;
        union Value  value;
    };
};

struct Flex {
    size_t len;
    int data[]; /* flexible array member */
};

/* anonymous struct/union combo (C11 or GNU extension) */
struct Combo {
    int tag;
    union {
        struct {
            int a, b;
        };
        struct {
            float r, g, b_f;
        } rgb;
    };
};

/* --- Function pointer types, callbacks ---------------------------------- */

typedef int (*binop_t)(int, int);
typedef void (*callback_t)(void *ctx, int code);

/* --- TLS, atomics, alignment -------------------------------------------- */

_Thread_local int tls_counter = 0;

_Alignas(16) static atomic_int g_atomic_counter = ATOMIC_VAR_INIT(0);

/* --- Generic macros using _Generic -------------------------------------- */

#define TYPE_NAME(x) _Generic((x), \
    int: "int", \
    float: "float", \
    double: "double", \
    default: "other" \
)

/* --- Inline and _Noreturn functions ------------------------------------- */

static inline int add_inline(int a, int b) {
    return a + b;
}

_Noreturn static void die(const char *msg) {
    LOG("FATAL", "%s", msg);
    abort();
}

/* --- Varargs demonstration ---------------------------------------------- */

static int sum_ints(int count, ...) {
    va_list ap;
    va_start(ap, count);
    int sum = 0;
    for (int i = 0; i < count; i++) {
        sum += va_arg(ap, int);
    }
    va_end(ap);
    return sum;
}

/* --- A couple of small operations for function pointers ----------------- */

static int op_add(int a, int b) { return a + b; }
static int op_sub(int a, int b) { return a - b; }
static int op_mul(int a, int b) { return a * b; }

static binop_t choose_op(kind_t k) {
    switch (k) {
        case KIND_ALPHA: return op_add;
        case KIND_BETA:  return op_sub;
        case KIND_GAMMA: return op_mul;
        default:         return NULL;
    }
}

/* --- Generic callback caller with restrict pointer ---------------------- */

static void call_callback(callback_t cb, void *restrict ctx) {
    if (cb) {
        cb(ctx, 123);
    }
}

/* --- Example callback --------------------------------------------------- */

static void example_cb(void *ctx, int code) {
    const char *name = (const char *)ctx;
    (void)name;
    (void)code;
    /* runtime not important; presence forces codegen */
}

/* --- Complex numbers, compound literals -------------------------------- */

static _Complex double complex_op(double a, double b) {
    _Complex double z = a + b * I;
    return z * conj(z);
}

/* --- VLAs + designated initializers ------------------------------------ */

static int vla_example(size_t n) {
    if (n == 0 || n > 64) {
        return -1;
    }
    int vla[(int)n]; /* VLA */
    for (size_t i = 0; i < n; i++) {
        vla[i] = (int)i;
    }
    int acc = 0;
    for (size_t i = 0; i < n; i++) {
        acc += vla[i];
    }
    return acc;
}

static struct Node node_init_example(void) {
    struct Node n = {
        .id   = 1,
        .kind = KIND_ALPHA,
        .inner = {
            .x = 10,
            .y = 2.5f
        }
    };
    return n;
}

/* --- Small state machine using enums and switch ------------------------- */

static kind_t next_kind(kind_t k) {
    switch (k) {
        case KIND_NONE:  return KIND_ALPHA;
        case KIND_ALPHA: return KIND_BETA;
        case KIND_BETA:  return KIND_GAMMA;
        case KIND_GAMMA: return KIND_NONE;
        default:         return KIND_NONE;
    }
}

/* --- Demonstrate atomics ------------------------------------------------ */

static void atomic_demo(void) {
    int old = atomic_fetch_add(&g_atomic_counter, 1);
    (void)old;
}

/* --- A mini interpreter-like dispatcher -------------------------------- */

static int dispatch_operation(kind_t kind, int a, int b) {
    binop_t op = choose_op(kind);
    if (!op) {
        return 0;
    }
    return op(a, b);
}

/* --- test of _Alignof, sizeof, etc. ------------------------------------ */

ATTR_UNUSED static void layout_info(void) {
    size_t s1 = sizeof(struct Node);
    size_t s2 = sizeof(struct Combo);
    size_t a1 = _Alignof(struct Node);
    size_t a2 = _Alignof(struct Combo);
    (void)s1; (void)s2; (void)a1; (void)a2;
}

/* --- main: compiler entry point for structure; runtime irrelevant ------- */

int main(void) {
    /* basic values */
    int base = add_inline(2, 3);

    /* generic macro dispatch */
    const char *tname_int    = TYPE_NAME(base);
    const char *tname_double = TYPE_NAME(3.14);
    (void)tname_int;
    (void)tname_double;

    /* union/struct usage */
    struct Node n = node_init_example();
    n.kind = next_kind(n.kind);
    if (n.kind == KIND_BETA) {
        n.value.i = 42;
    }

    /* combo struct access via anonymous members */
    struct Combo c = { .tag = 1, .a = 2, .b = 3 };
    c.rgb.r = 0.1f;
    c.rgb.g = 0.2f;
    c.rgb.b_f = 0.3f;

    /* varargs */
    int s = sum_ints(4, 1, 2, 3, 4);

    /* atomics */
    atomic_demo();

    /* complex */
    _Complex double z = complex_op(1.0, 2.0);
    (void)z;

    /* function pointer dispatch */
    int r1 = dispatch_operation(KIND_ALPHA, 5, 6);
    int r2 = dispatch_operation(KIND_BETA,  5, 6);
    int r3 = dispatch_operation(KIND_GAMMA, 5, 6);
    (void)r1; (void)r2; (void)r3;

    /* callbacks */
    call_callback(example_cb, "example");

    /* VLAs */
    int vla_sum = vla_example(5);
    (void)vla_sum;

    /* flexible array member allocation */
    size_t len = 4;
    struct Flex *f = malloc(sizeof(*f) + len * sizeof(int));
    if (!f) {
        /* do not call die() in case harness dislikes abort; just return */
        return EXIT_FAILURE;
    }
    f->len = len;
    for (size_t i = 0; i < len; i++) {
        f->data[i] = (int)(i * 2);
    }

    /* compound literal */
    struct Flags fl = (struct Flags){ .a = 1, .b = 2, .c = 3, .d = 0xFF };
    (void)fl;

    tls_counter++;
    free(f);

    /* No observable output; for fuzzing we only care that it compiles. */
    return (base + s + tls_counter) ? 0 : 0;
}
