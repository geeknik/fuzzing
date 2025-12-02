; seed_x86_64_nasm_polyglot.asm
; Deliberately dense, syntax-heavy x86-64 NASM source for assembler fuzzing.
;
; Exercises:
;   - sections, global/extern, labels, local labels
;   - EQU, %define/%xdefine, %assign, %if/%ifdef/%error
;   - %macro/%endmacro, %rep/%endrep, positional/default macro args
;   - db/dw/dd/dq/du/dup, align, relocs, RIP-relative addressing
;   - integer/float encodings, string literals and escapes
;   - control flow, condition codes, multiple instruction syntaxes
;   - SSE/AVX-ish mnemonics (on assemblers that support them)
;
; Intended target:
;   nasm -felf64 seed_x86_64_nasm_polyglot.asm -o seed.o
;
; Runtime behavior is irrelevant; this is for front-end / assembler fuzzing.

BITS 64

; ---------------------------------------------------------------------------
; Preprocessor toys
; ---------------------------------------------------------------------------

%define VERSION_MAJOR 1
%xdefine VERSION_MINOR 0
%assign BUILD_NO 42

%define STR(x) __STR(x)
%define __STR(x) x

%define CRLF  13, 10
%define TAB   9

; conditional assembly
%if VERSION_MAJOR = 1
    %define FEATURE_ALPHA 1
%else
    %define FEATURE_ALPHA 0
%endif

%ifdef UNKNOWN_SYMBOL
    %error "This branch should not be assembled normally"
%endif

; simple macro with defaults and variadics
%macro PUSHREGS 0-*
    %rep %0
        push qword %1
        %rotate 1
    %endrep
%endmacro

%macro POPREGS 0-*
    %rep %0
        pop qword %1
        %rotate 1
    %endrep
%endmacro

; macro with local labels
%macro ZERO_RANGE 2
    ; ZERO_RANGE base,count
    mov     rcx, %2
    lea     rdi, [%1]
  %%loop:
    test    rcx, rcx
    jz      %%done
    mov     byte [rdi], 0
    inc     rdi
    dec     rcx
    jmp     %%loop
  %%done:
%endmacro

; ---------------------------------------------------------------------------
; Externals + globals
; ---------------------------------------------------------------------------

global  _start

extern  printf          ; for link-time symbol resolution
extern  exit

; ---------------------------------------------------------------------------
; Data section
; ---------------------------------------------------------------------------

section .data align=16

version_string db "seed_x86_64_nasm_polyglot v", STR(VERSION_MAJOR+'0'), ".", STR(VERSION_MINOR+'0'), 0

fmt_num     db  "value=%ld", 0
fmt_str     db  "msg=%s", 0

hello_msg   db  "Hello, NASM polyglot!", 0
newline     db  CRLF, 0

; assorted numeric encodings
int8_vals   db  -128, -1, 0, 1, 127
int16_vals  dw  0x0001, 0x7FFF, 0x8000, 0xFFFF
int32_vals  dd  0x00000001, 0x7FFFFFFF, 0x80000000, 0xFFFFFFFF
int64_vals  dq  1, -1, 0x7FFFFFFFFFFFFFFF, 0x8000000000000000

; floating point
flt_vals    dd  0.0, 1.0, -1.0, 3.1415926
dbl_vals    dq  0.0, 1.0, -1.0, 2.718281828

; string with escapes and mixed bytes
esc_str     db  "line1", CRLF, "line2", 0
raw_bytes   db  0, 1, 2, 3, 4, 5, 255

; duplicated data structure
struct_size EQU 8
dup_buf     db  struct_size dup(0xAA)

; RIP-relative target
rip_target  dq  0x1234567890ABCDEF

; ---------------------------------------------------------------------------
; Read-only data
; ---------------------------------------------------------------------------

section .rodata align=16

ro_array dq 10, 20, 30, 40
ro_text  db "read-only text", 0

; ---------------------------------------------------------------------------
; BSS
; ---------------------------------------------------------------------------

section .bss

align 16
buf_vla     resb 128
buf_other   resq 16

; ---------------------------------------------------------------------------
; Text section
; ---------------------------------------------------------------------------

section .text

; simple leaf utility to test calling convention and local labels
; int64_t add3(int64_t a, int64_t b, int64_t c)
; System V AMD64: args in rdi, rsi, rdx; return in rax
add3:
    push    rbp
    mov     rbp, rsp
    mov     rax, rdi
    add     rax, rsi
    add     rax, rdx
    pop     rbp
    ret

; sample function with local labels and different instruction forms
sample_control_flow:
    PUSHREGS rbx, rbp
    mov     rbp, rsp

    mov     rax, 0
    mov     rcx, 10

.loop_top:
    add     rax, rcx
    dec     rcx
    jnz     .loop_top

    cmp     rax, 10
    jg      .gt_ten
    jl      .lt_ten
    jmp     .eq_ten

.gt_ten:
    mov     rbx, 1
    jmp     .done

.lt_ten:
    mov     rbx, -1
    jmp     .done

.eq_ten:
    xor     rbx, rbx

.done:
    POPREGS rbp, rbx
    ret

; ---------------------------------------------------------------------------
; Example with RIP-relative addressing, SSE instructions, etc.
; ---------------------------------------------------------------------------

use_rip_and_sse:
    ; load value via RIP-relative
    mov     rax, [rel rip_target]

    ; SSE move
    movaps  xmm0, xmm0
    movups  xmm1, [rel flt_vals]

    ; simple arithmetic
    add     rax, 5
    ret

; ---------------------------------------------------------------------------
; _start: process entry (Linux SysV ABI), but used only as structure
; ---------------------------------------------------------------------------

_start:
    ; demonstrate tls-like access (fake), stack adjustment, etc.
    PUSHREGS rbx, rbp, r12

    mov     rbp, rsp

    ; call add3 with some constants
    mov     rdi, 1
    mov     rsi, 2
    mov     rdx, 3
    call    add3           ; rax = 6

    ; use ZERO_RANGE macro on .bss buffer
    lea     rdi, [rel buf_vla]
    mov     rcx, 64
    ZERO_RANGE rdi, rcx

    ; demonstrate conditional moves and setcc
    mov     rbx, rax
    cmp     rbx, 5
    mov     rcx, 0
    setg    cl
    cmovg   rax, rbx

    ; simple RIP-relative data load
    lea     rdi, [rel hello_msg]
    lea     rsi, [rel fmt_str]
    ; (would call printf here in a real program)

    ; some random instructions to exercise decoder
    mov     r8,  0x123456789ABCDEF0
    mov     r9,  0x0FEDCBA987654321
    xor     r10, r10
    or      r8,  r9
    and     r9,  r8
    shl     r8,  1
    shr     r9,  2
    sar     r8,  3
    rol     r9,  4
    ror     r8,  5

    ; byte/word/dword operations
    mov     al,  0x7F
    inc     ax
    dec     eax
    not     al
    neg     eax

    ; flags-based jumps
    test    eax, eax
    jz      .label_zero
    jns     .label_nonneg
    js      .label_negative

.label_zero:
    nop
    jmp     .after_flags

.label_nonneg:
    nop
    jmp     .after_flags

.label_negative:
    nop

.after_flags:

    ; use a local numeric label with forward/backward refs
    mov     ecx, 3
1:
    dec     ecx
    jnz     1b          ; backward to label "1"
    jmp     2f          ; forward to label "2"
    nop
2:
    nop

    ; call sample_control_flow
    call    sample_control_flow

    ; Call use_rip_and_sse
    call    use_rip_and_sse

    ; done: exit(0) via Linux sys_exit
    mov     rdi, 0       ; exit code
    mov     rax, 60      ; sys_exit
    syscall

    POPREGS r12, rbp, rbx
    ; unreachable due to syscall, but keeps structure consistent
    ret

; ---------------------------------------------------------------------------
; End of file
; ---------------------------------------------------------------------------
