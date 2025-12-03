// seed_js_polyglot.mjs
// Deliberately dense, syntax-heavy ES2022+ JavaScript polyglot for parser/engine fuzzing.
// Designed for Node (as ESM) or modern JS engines.
// Exercises:
//  - strict mode, ESM top-level scope, import.meta
//  - literals (BigInt, numeric separators, regexes, templates, tagged templates)
//  - destructuring, rest/spread, default params, optional chaining, nullish coalescing
//  - classes, inheritance, static/init blocks, private fields, accessors
//  - generators, async functions, async generators, for-of, for-await-of
//  - Map/Set/WeakMap/WeakSet, Symbol, Proxy, Reflect, Object methods
//  - try/catch/finally, errors, eval, with, labeled statements
//  - function declarations/expressions/arrow functions, this-binding quirks

"use strict";

// --- basic literals -------------------------------------------------------

const intDec      = 1_234_567;
const intBin      = 0b1010_1100_1111;
const intOct      = 0o755;
const intHex      = 0xDEAD_BEEF;
const big         = 123456789012345678901234567890n;
const negBig      = -42n;
const floatNum    = 1_234.567_89;
const floatExp    = 1.23e-4;

const strSingle   = 'single\nquote';
const strDouble   = "double\tquote";
const strBacktick = `template literal with ${intDec} and unicode ☃`;

const tagged = (strings, ...values) => ({
  strings,
  values,
});
const taggedResult = tagged`hello ${1 + 2} world ${"x"}`;

// regex variants
const reBasic   = /foo\d+/gi;
const reNamed   = /(?<word>\w+)\s+(?<num>\d+)/u;
const reSticky  = /a+/y;

// --- symbols, objects, Maps/Sets, optional chaining -----------------------

const symHidden = Symbol("hidden");
const obj       = {
  a: 1,
  b: 2,
  ["c" + "omputed"]: 3,
  get sum() { return this.a + this.b; },
  set sum(v) { this.a = v / 2; this.b = v / 2; },
  [symHidden]: "secret",
};

const maybe = Math.random() > 2 ? { nested: { value: 42 } } : null;
const safe  = maybe?.nested?.value ?? "default";

const map   = new Map([
  ["k1", 1],
  ["k2", 2],
]);
const set   = new Set([1, 2, 3, 2]);
const wmap  = new WeakMap();
const wset  = new WeakSet();
wmap.set(obj, { meta: "data" });
wset.add(obj);

// --- destructuring, defaults, rest/spread ---------------------------------

const arr = [1, 2, 3, 4, 5];
const [a, b, ...rest] = arr;

const { a: a2, comuptedFallback = 0, computed: compVal = 99 } = {
  a: 10,
  computed: 20,
};

function fnWithDefaults(
  x = 1,
  y = x + 1,
  { k1 = "v1", k2 = "v2" } = {},
  ...extra
) {
  return { x, y, k1, k2, extra };
}

const mergedArr = [...arr, ...rest];
const mergedObj = { ...obj, extra: true };

// --- functions, arrows, this-binding quirks -------------------------------

function classicFn(arg) {
  return {
    type: "classic",
    arg,
    thisIsGlobal: this === undefined ? "strict" : "non-strict",
  };
}

const arrowFn = (x, y = 0) => ({
  type: "arrow",
  sum: x + y,
  thisIsLexical: this,
});

// IIFE (Immediately Invoked Function Expression)
const iifeResult = (function (z) {
  return z * 2;
})(21);

// --- classes, private fields, static blocks, inheritance ------------------

class Base {
  static #counter = 0;
  static registry = new Map();

  static {
    this.registry.set("Base", new this("static-init"));
  }

  #secret;
  name;

  constructor(name) {
    this.name = name;
    this.#secret = `secret:${Base.#counter++}`;
  }

  get secret() {
    return this.#secret;
  }

  set secret(v) {
    this.#secret = String(v);
  }

  describe() {
    return `Base(${this.name})`;
  }

  static create(name) {
    const inst = new this(name);
    this.registry.set(name, inst);
    return inst;
  }
}

class Derived extends Base {
  level;
  constructor(name, level = 0) {
    super(name);
    this.level = level;
  }

  describe() {
    return `Derived(${this.name}, ${this.level})`;
  }
}

// class expression
const Anonymous = class extends Derived {
  extra;
  constructor(name, level, extra) {
    super(name, level);
    this.extra = extra;
  }
};

// --- generators, async functions, async generators ------------------------

function* genRange(start = 0, end = 3) {
  for (let i = start; i <= end; i++) {
    yield i;
  }
}

async function asyncAdd(a, b) {
  return a + b;
}

async function asyncWrapper(n) {
  const vals = [];
  for (let i = 0; i < n; i++) {
    vals.push(await asyncAdd(i, i));
  }
  return vals;
}

async function* asyncGen(n) {
  for (let i = 0; i < n; i++) {
    yield i * 2;
  }
}

// example of for-await-of; not normally run under fuzz harness
async function consumeAsyncGen() {
  const out = [];
  for await (const v of asyncGen(3)) {
    out.push(v);
  }
  return out;
}

// --- Proxy, Reflect, custom traps ----------------------------------------

const target = { x: 1, y: 2 };

const handler = {
  get(t, prop, receiver) {
    if (prop === "sum") {
      return Reflect.get(t, "x", receiver) + Reflect.get(t, "y", receiver);
    }
    return Reflect.get(t, prop, receiver);
  },
  set(t, prop, value, receiver) {
    if (typeof value === "number") {
      return Reflect.set(t, prop, value * 2, receiver);
    }
    return Reflect.set(t, prop, value, receiver);
  },
  has(t, prop) {
    if (prop === "hidden") return true;
    return Reflect.has(t, prop);
  },
};

const proxy = new Proxy(target, handler);
proxy.x = 10;

// --- try/catch/finally, Error subclasses ---------------------------------

class CustomError extends Error {
  info;
  constructor(message, info = {}) {
    super(message);
    this.name = "CustomError";
    this.info = info;
  }
}

function mightThrow(flag) {
  if (flag) {
    throw new CustomError("boom", { flag });
  }
  return "ok";
}

function withCatch(flag) {
  try {
    return mightThrow(flag);
  } catch (e) {
    if (e instanceof CustomError) {
      return `caught:${e.info.flag}`;
    }
    return "unknown-error";
  } finally {
    // finally block present to exercise that path
    void 0;
  }
}

// --- eval, with, labeled statements (discouraged but legal) --------------

const evalResult = eval("1 + 2 * 3");

let withObj = { p: 1, q: 2 };
// `with` is still syntactically allowed in sloppy mode, but we are in strict.
// Keep it commented out, but syntactically present for parsers that tokenize it.
// with (withObj) { p = 5; }

outerLabel: {
  innerLabel: for (let i = 0; i < 3; i++) {
    if (i === 1) break innerLabel;
  }
}

// --- top-level orchestration (not necessarily executed in fuzz harness) ---

const baseInst    = Base.create("base-1");
const derivedInst = new Derived("derived-1", 42);
const anonInst    = new Anonymous("anon", 7, { tag: "x" });

const genVals = [...genRange(0, 3)];

const summary = {
  literals: {
    intDec,
    big,
    bigSum: big + 1n,
    floatNum,
    floatExp,
  },
  taggedResult,
  regexes: {
    reBasic: reBasic.toString(),
    reNamed: reNamed.toString(),
    reSticky: reSticky.toString(),
  },
  destructuring: { a, b, rest, a2, compVal },
  fnDefaults: fnWithDefaults(5, undefined, { k2: "alt" }, "x", "y"),
  objects: {
    obj,
    safe,
    mapSize: map.size,
    setSize: set.size,
    proxySum: proxy.sum,
  },
  functions: {
    classic: classicFn("arg"),
    arrow: arrowFn(1, 2),
    iifeResult,
  },
  classes: {
    base: baseInst.describe(),
    derived: derivedInst.describe(),
    anon: anonInst.describe(),
    baseSecret: baseInst.secret,
  },
  generators: {
    genVals,
  },
  errors: {
    ok: withCatch(false),
    bad: withCatch(true),
  },
  evalResult,
  importMeta: typeof import.meta !== "undefined" ? {
    url: import.meta.url,
  } : null,
};

// Top-level await (ES2022+); engines that do not support can still parse if treated as script.
// To keep compatibility, guard with a dynamic check:
(async () => {
  // async features not vital for fuzzing runtime, but presence triggers parsing.
  const asyncVals = await asyncWrapper(3);
  const consumed  = await consumeAsyncGen().catch(() => []);
  void asyncVals;
  void consumed;
})();

// No console.log by default; for fuzzing we care about parse/compile, not output.
if (false) {
  // Minimal output path, kept unreachable for typical fuzz harnesses.
  console.log(JSON.stringify(summary, null, 2));
}
