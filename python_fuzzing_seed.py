#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# polyglot_seed.py
# This file is deliberately weird: it tries to touch many CPython parse/compile paths.

from __future__ import annotations

# --- literals and basic syntax ---------------------------------------------

# Numeric literals
int_dec      = 10_000_000
int_bin      = 0b1010_0101_1111_0000
int_oct      = 0o755
int_hex      = 0xDEAD_BEEF
float_basic  = 1_234.567_89
float_exp    = 1.0e-10
complex_num  = 3+4j

# Strings of all flavors
single_quoted   = 'single\nquote'
double_quoted   = "double\tquote"
triple_single   = '''triple 'single' with "quotes" and newlines
line2
line3'''
triple_double   = """triple "double" with 'quotes' and escapes \u2603"""
raw_str         = r"raw\path\with\slashes\n\t"
raw_bytes       = rb"raw-bytes-\x41\x42"
bytes_str       = b"bytes-literal-\x00\xFF"

name = "polyglot"
value = 42
f_string_basic  = f"{name=}, value={value:04d}"
f_string_nested = f"nested {value!r:>10} + { (lambda x: x**2)(value) = }"

# Make sure unicode identifiers/strings and comments are present
café = "café"
π = 3.14159
日本語 = "漢字とひらがなとカタカナ"

# line continuation variants
continued = (
    1 + 2 +
    3 + 4 \
    + 5
)

# --- comments & type comments ----------------------------------------------

a = 1  # type: int
b = []  # type: list[int]

# --- functions, annotations, and signatures --------------------------------

def decorator_factory(prefix: str):
    def deco(fn):
        fn._decorated_by = prefix
        return fn
    return deco

@decorator_factory("sync")  # decorator with closure
def func_positional_only(a: int, b: str, /, c: float = 1.0, *args: int,
                         d: bool = True, **kwargs: str) -> dict[str, object]:
    """Function with positional-only, varargs, kwargs and annotations."""
    x: "int | None" = a if d else None
    y = (lambda z: z + 1)(int(c))
    # walrus operator in a comprehension
    squares = [ (w := i*i) for i in range(5) if w % 2 == 0 ]
    # dict and set comps
    mapping = {k: len(k) for k in ("a", "bb", "ccc")}
    s = {i for i in range(10) if i % 3}
    return {"x": x, "y": y, "squares": squares, "mapping": mapping, "set": s}

@decorator_factory("async")
async def async_func(a: int, b: int) -> list[int]:
    """Exercise async/await/async for/async with."""
    import asyncio

    async def inner(seq):
        return [i async for i in _async_gen(seq)]

    # comprehension with await inside
    await asyncio.sleep(0)
    res = await inner([a, b])

    class AsyncCM:
        async def __aenter__(self):
            return "cm"
        async def __aexit__(self, exc_type, exc, tb):
            return False

    async with AsyncCM() as _cm:
        # just to force code object generation
        res2 = [i async for i in _async_gen(res)]

    return res + res2


async def _async_gen(seq):
    for item in seq:
        yield item


def generator_func(n: int):
    """Generator with try/except/finally and yield in finally."""
    try:
        for i in range(n):
            if i == 2:
                raise ValueError("boom")
            yield i
    except ValueError as e:
        yield f"caught:{e}"
    finally:
        yield "finally-done"

# --- global / nonlocal / nested scopes -------------------------------------

X = "global-X"

def outer():
    x = "outer-x"
    y = "outer-y"

    def inner():
        nonlocal x
        global X
        x = "mutated-outer-x"
        X = "mutated-global-X"
        return x, X

    return inner(), (x, y)

# --- classes, metaclasses, __slots__, annotations --------------------------

class Meta(type):
    def __new__(mcls, name, bases, ns, **kw):
        ns.setdefault("__doc__", f"Meta-created {name}")
        return super().__new__(mcls, name, bases, ns)

class Base(metaclass=Meta):
    __slots__ = ("x", "y")
    base_attr: int = 123

    def __init__(self, x, y):
        self.x = x
        self.y = y

    def method(self, z: int | None = None) -> int:
        return (self.x or 0) + (self.y or 0) + (z or 0)

class Derived(Base):
    d_attr: str = "derived"

    @property
    def prop(self) -> str:
        return f"{self.x!r}:{self.y!r}:{self.d_attr}"

    @prop.setter
    def prop(self, v: str):
        self.d_attr = v

# --- context managers, with-stmt variations --------------------------------

class CM:
    def __enter__(self):
        return "cm-val"
    def __exit__(self, exc_type, exc, tb):
        return False

def with_stuff():
    with CM() as v, CM() as w:
        return v, w

# --- try/except/else/finally nesting ---------------------------------------

def errors():
    try:
        x = 1/0
    except ZeroDivisionError as e:
        msg = f"{e=}"
    else:
        msg = "no-error"
    finally:
        msg += "|finally"
    return msg

# --- match/case (requires Python 3.10+) ------------------------------------
# If your target version is <3.10, delete this block.

def pattern_matching(obj):
    match obj:
        case {"kind": "point", "x": x, "y": y}:
            return ("point", x, y)
        case [first, *_rest]:
            return ("list", first)
        case int() as iv if iv > 10:
            return ("big-int", iv)
        case _:
            return ("other", obj)

# --- lambdas, generator expressions, closures ------------------------------

def closures_and_lambdas():
    funcs = []
    for i in range(3):
        funcs.append(lambda j, i=i: i + j)

    gen_expr = (i*i for i in range(5) if i % 2)
    return [f(10) for f in funcs], list(gen_expr)

# --- weird-ish combinations -----------------------------------------------

def nested_comprehensions():
    return [
        (i, j, k)
        for i in range(3)
        for j in range(3)
        for k in range(3)
        if (i + j + k) % 2 == 0
    ]

def funky_annotations(a: "list[tuple[int, str]]") -> "dict[int, str]":
    return {x: y for x, y in a}

# --- main guard (never executed under py_compile, but adds structure) ------

if __name__ == "__main__":
    # Just create references to exercise name resolution in the compiler.
    _ = func_positional_only(1, "two", 3.0, 4, 5, d=False, k="v")
    _ = [v for v in generator_func(5)]
    _ = outer()
    _ = Derived(1, 2).prop
    _ = with_stuff()
    _ = errors()
    _ = pattern_matching({"kind": "point", "x": 1, "y": 2})
    _ = closures_and_lambdas()
    _ = nested_comprehensions()
    _ = funky_annotations([(1, "a"), (2, "b")])
    _ = café, π, 日本語
    _ = f_string_basic, f_string_nested
    # printing avoided; runtime doesn’t matter for py_compile
