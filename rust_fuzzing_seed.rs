// seed_rust_polyglot.rs
// Deliberately dense, syntax-heavy Rust source for compiler fuzzing.

#![allow(
    dead_code,
    unused_imports,
    unused_variables,
    unused_mut,
    unreachable_code,
    clippy::all
)]

use std::cmp::{Ord, Ordering};
use std::collections::{BTreeMap, HashMap};
use std::fmt::{self, Debug, Display};
use std::marker::PhantomData;
use std::mem;
use std::ops::{Add, Deref, Index};
use std::ptr;

// --- basic types, consts, const fn, const generics ------------------------

const fn const_add(a: u32, b: u32) -> u32 {
    a + b
}

const CONST_SUM: u32 = const_add(40, 2);

struct ArrayWrapper<T, const N: usize> {
    data: [T; N],
}

impl<T: Copy + Default, const N: usize> ArrayWrapper<T, N> {
    fn new_default() -> Self {
        Self { data: [T::default(); N] }
    }
}

// --- lifetimes, generics, traits, associated types/consts -----------------

trait AssocStuff<'a> {
    type Item;
    const ID: u32;

    fn make_item(&'a self) -> Self::Item;
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct Pair<A, B> {
    left: A,
    right: B,
}

impl<'a, T: 'a + Copy> AssocStuff<'a> for Pair<&'a T, i32> {
    type Item = &'a T;
    const ID: u32 = 7;

    fn make_item(&'a self) -> Self::Item {
        self.left
    }
}

impl<A: Add<Output = A> + Copy, B: Add<Output = B> + Copy> Add for Pair<A, B> {
    type Output = Self;

    fn add(self, rhs: Self) -> Self::Output {
        Pair {
            left: self.left + rhs.left,
            right: self.right + rhs.right,
        }
    }
}

// --- enums, repr, pattern matching, match guards --------------------------

#[repr(u8)]
#[derive(Debug, Clone, Copy)]
enum Tagged {
    A = 1,
    B = 2,
    C = 3,
}

#[derive(Debug)]
enum Tree<T> {
    Leaf(T),
    Node(Box<Tree<T>>, Box<Tree<T>>),
    Empty,
}

fn sum_tree(tree: &Tree<i32>) -> i32 {
    match tree {
        Tree::Leaf(v) => *v,
        Tree::Node(l, r) => sum_tree(l) + sum_tree(r),
        Tree::Empty => 0,
    }
}

fn classify(v: i32) -> &'static str {
    match v {
        x if x < 0 => "negative",
        0 => "zero",
        1 | 2 | 3 => "small",
        4..=10 => "medium",
        _ if v % 2 == 0 => "large-even",
        _ => "large-odd",
    }
}

// --- modules, visibility, use paths ---------------------------------------

mod nested {
    pub mod inner {
        #[derive(Debug)]
        pub struct Inner {
            pub value: i32,
        }

        pub fn make_inner(v: i32) -> Inner {
            Inner { value: v }
        }
    }

    pub use inner::Inner;
}

// --- traits + default methods + blanket impl ------------------------------

trait Describe {
    fn describe(&self) -> String {
        format!("Describe default: {:?}", self as *const Self)
    }
}

impl<T: Debug> Describe for T {
    fn describe(&self) -> String {
        format!("Debug({:?})", self)
    }
}

// --- newtype, Deref, Index, PhantomData -----------------------------------

struct Wrapper<T>(T);

impl<T> Deref for Wrapper<T> {
    type Target = T;
    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl<T> Debug for Wrapper<T>
where
    T: Debug,
{
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_tuple("Wrapper").field(&self.0).finish()
    }
}

struct PhantomHolder<T> {
    _marker: PhantomData<T>,
    id: u64,
}

// --- unions, unsafe, extern "C" ------------------------------------------

union IntOrFloat {
    i: i32,
    f: f32,
}

extern "C" {
    fn abs(i: i32) -> i32;
}

unsafe fn unsafe_stuff(ptr_i32: *mut i32) -> i32 {
    if ptr_i32.is_null() {
        return -1;
    }
    *ptr_i32 += 1;
    let val = *ptr_i32;
    let u = IntOrFloat { i: val };
    let abs_val = abs(val);
    let as_float = u.f;
    let _ = as_float; // suppress unused
    abs_val
}

// --- async/await, impl Future, pinning not needed for compile-only --------

use std::future::Future;

async fn async_add(a: i32, b: i32) -> i32 {
    a + b
}

fn call_async_add(a: i32, b: i32) -> impl Future<Output = i32> {
    async move { async_add(a, b).await }
}

// --- macros: declarative macro_rules, repetition, tt muncher --------------

macro_rules! make_pair {
    ($l:expr, $r:expr) => {
        Pair { left: $l, right: $r }
    };
}

macro_rules! vec_of_strings {
    ($($item:expr),* $(,)?) => {{
        let mut v = Vec::new();
        $(
            v.push($item.to_string());
        )*
        v
    }};
}

macro_rules! nested_matches {
    ($val:expr) => {{
        match $val {
            Some(x) => match x {
                0 => "zero",
                1..=9 => "small",
                _ => "big",
            },
            None => "none",
        }
    }};
}

// --- iterator combinators, closures, move captures ------------------------

fn iterator_play(xs: &[i32]) -> (Vec<i32>, Option<i32>) {
    let v: Vec<i32> = xs
        .iter()
        .enumerate()
        .map(|(i, x)| (i as i32) + x)
        .filter(|x| x % 2 == 0)
        .collect();

    let sum = xs.iter().copied().reduce(|a, b| a + b);

    (v, sum)
}

// --- Result / Option, ? operator, type aliases ----------------------------

type MyResult<T> = Result<T, String>;

fn parse_and_add(a: &str, b: &str) -> MyResult<i32> {
    let x: i32 = a.parse().map_err(|_| "parse a failed".to_string())?;
    let y: i32 = b.parse().map_err(|_| "parse b failed".to_string())?;
    Ok(x + y)
}

// --- nested generic function with lifetime + where clauses ----------------

fn choose<'a, T>(a: &'a T, b: &'a T) -> &'a T
where
    T: Ord + Debug,
{
    if a < b {
        a
    } else {
        b
    }
}

// --- const pattern usage ---------------------------------------------------

const TAG_A: Tagged = Tagged::A;

fn const_pattern_demo(t: Tagged) -> &'static str {
    match t {
        TAG_A => "tag-a",
        Tagged::B => "tag-b",
        _ => "tag-other",
    }
}

// --- small state machine via enum + impl ----------------------------------

#[derive(Debug)]
enum State {
    Start,
    Running(u32),
    Done,
}

impl State {
    fn step(self) -> State {
        match self {
            State::Start => State::Running(0),
            State::Running(n) if n < 2 => State::Running(n + 1),
            State::Running(_) => State::Done,
            State::Done => State::Done,
        }
    }
}

// --- main: not used by fuzz target, but structured for compilation --------

fn main() {
    // Basic values
    let _sum_const = CONST_SUM;
    let _arr: ArrayWrapper<u8, 4> = ArrayWrapper::new_default();

    let val = 10;
    let p = Pair {
        left: &val,
        right: 123,
    };
    let _item = p.make_item();
    let _id = <Pair<&i32, i32> as AssocStuff>::ID;

    let p1 = make_pair!(1, 2);
    let p2 = make_pair!(3, 4);
    let _p3 = p1 + p2;

    let tree = Tree::Node(
        Box::new(Tree::Leaf(1)),
        Box::new(Tree::Node(
            Box::new(Tree::Leaf(2)),
            Box::new(Tree::Leaf(3)),
        )),
    );
    let _sum = sum_tree(&tree);

    let _class_neg = classify(-1);
    let _class_big = classify(42);

    let inner = nested::inner::make_inner(7);
    let _desc = inner.describe();

    let w = Wrapper(inner);
    let _w_debug = format!("{:?}", w);
    let _w_value = w.value;

    let _phantom: PhantomHolder<String> = PhantomHolder {
        _marker: PhantomData,
        id: 123,
    };

    let _tag = const_pattern_demo(Tagged::C);

    let mut map: HashMap<String, i32> = HashMap::new();
    map.insert("a".into(), 1);
    map.insert("b".into(), 2);

    let bmap: BTreeMap<_, _> = map.iter().map(|(k, v)| (k.clone(), v + 1)).collect();
    let _bmap_debug = format!("{:?}", bmap);

    let xs = [1, 2, 3, 4];
    let (_even_sums, _maybe_sum) = iterator_play(&xs);

    let _nested_match_some = nested_matches!(Some(5));
    let _nested_match_none = nested_matches!(None::<i32>);

    let v_strings = vec_of_strings!["alpha", "beta", "gamma"];
    let _v_desc = v_strings.describe();

    let res_ok = parse_and_add("10", "20");
    let res_err = parse_and_add("foo", "20");
    let _res_debug = format!("{:?} {:?}", res_ok, res_err);

    let bigger = choose(&10, &20);
    let _bigger_val = *bigger;

    let mut s = State::Start;
    for _ in 0..5 {
        s = s.step();
    }

    let mut x = 5i32;
    let ptr_x: *mut i32 = &mut x;
    unsafe {
        let _abs = unsafe_stuff(ptr_x);
    }

    let _fut = call_async_add(1, 2);

    // End of main; runtime is irrelevant for fuzzing, structure matters.
}
