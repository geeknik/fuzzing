//go:build !ignore
// +build !ignore

// seed_go_polyglot.go
// Deliberately dense, syntax-heavy Go 1.20+ source for compiler/front-end fuzzing.
//
// Exercises:
//   - build tags, package-level init, multiple files semantics (simulated)
//   - const blocks, iota, typed/untype consts
//   - type aliases, generics, constraints, methods on type params
//   - interfaces, embedding, anonymous structs, composite literals
//   - maps/slices/arrays/channels, goroutines, select, closures
//   - defer, panic/recover, type switches, tagged struct fields
//   - raw/interpreted strings, runes, byte slices, iota enums
//   - blank identifier usage to silence “unused”
//
// Runtime behavior is irrelevant; this is for exercising parse/type-check/compile.

package main

import (
	"context"
	"errors"
	"fmt"
	"math"
	"sync"
	"time"
)

// --- constants, iota, enums ------------------------------------------------

const (
	KindUnknown Kind = iota
	KindAlpha
	KindBeta
	KindGamma
)

const (
	_ = 1 << iota
	FlagRead
	FlagWrite
	FlagExec
)

// typed/untype const mix
const Pi = 3.1415926535
const SmallInt int = 42

// --- basic named types, type aliases --------------------------------------

type Kind int

func (k Kind) String() string {
	switch k {
	case KindAlpha:
		return "alpha"
	case KindBeta:
		return "beta"
	case KindGamma:
		return "gamma"
	default:
		return "unknown"
	}
}

type ID = string // alias

// --- generic constraints & helper types -----------------------------------

type Number interface {
	~int | ~int64 | ~float64 | ~float32
}

// generic pair type
type Pair[A, B any] struct {
	Left  A `json:"left"`
	Right B `json:"right"`
}

// generic map-reducer
func MapReduce[T any, R any](xs []T, mapFn func(T) R, reduceFn func(R, R) R, zero R) R {
	acc := zero
	for _, v := range xs {
		m := mapFn(v)
		acc = reduceFn(acc, m)
	}
	return acc
}

// generic clamp
func Clamp[T Number](v, lo, hi T) T {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

// --- interfaces, embedding, methods ---------------------------------------

type Describer interface {
	Describe() string
}

type Named interface {
	Name() string
}

type Entity interface {
	Describer
	Named
	Kind() Kind
}

type Base struct {
	ID   ID
	k    Kind
	meta map[string]string
}

func (b *Base) Name() string      { return b.ID }
func (b *Base) Kind() Kind        { return b.k }
func (b *Base) Describe() string  { return fmt.Sprintf("Base(%s,%s)", b.ID, b.k) }
func (b *Base) Meta() map[string]string {
	if b.meta == nil {
		b.meta = make(map[string]string)
	}
	return b.meta
}

type Advanced struct {
	*Base             // embedded pointer
	Score float64     `tag:"score"`
	data  []byte
}

func (a Advanced) Describe() string {
	return fmt.Sprintf("Advanced(%s,%.2f)", a.Name(), a.Score)
}

// method with type parameter receiver
func (p Pair[A, B]) Flip() Pair[B, A] {
	return Pair[B, A]{Left: p.Right, Right: p.Left}
}

// --- channels, goroutines, select, context --------------------------------

func fanIn[T any](ctx context.Context, chans ...<-chan T) <-chan T {
	out := make(chan T)
	var wg sync.WaitGroup
	wg.Add(len(chans))

	for _, ch := range chans {
		ch := ch
		go func() {
			defer wg.Done()
			for {
				select {
				case <-ctx.Done():
					return
				case v, ok := <-ch:
					if !ok {
						return
					}
					select {
					case out <- v:
					case <-ctx.Done():
						return
					}
				}
			}
		}()
	}

	go func() {
		wg.Wait()
		close(out)
	}()

	return out
}

// simple generator
func genInts(n int) <-chan int {
	ch := make(chan int)
	go func() {
		defer close(ch)
		for i := 0; i < n; i++ {
			ch <- i
		}
	}()
	return ch
}

// --- panic/recover, defer, type switches ----------------------------------

func withRecover(fn func()) (recovered interface{}) {
	defer func() {
		if r := recover(); r != nil {
			recovered = r
		}
	}()
	fn()
	return nil
}

func classifyAny(x any) string {
	switch v := x.(type) {
	case nil:
		return "nil"
	case int:
		return fmt.Sprintf("int(%d)", v)
	case string:
		return fmt.Sprintf("string(%q)", v)
	case Kind:
		return "kind:" + v.String()
	case fmt.Stringer:
		return "stringer:" + v.String()
	default:
		return fmt.Sprintf("other(%T)", v)
	}
}

// --- init function, package-level variables --------------------------------

var (
	globalOnce sync.Once
	globalMap  map[string]float64
)

func init() {
	globalOnce.Do(func() {
		globalMap = map[string]float64{
			"pi":   Pi,
			"e":    math.E,
			"sqrt": math.Sqrt2,
		}
	})
}

// --- closures, anonymous structs, composite literals ----------------------

func closurePlay(n int) (int, int) {
	sum := 0
	mul := 1
	add := func(x int) { sum += x }
	mult := func(x int) { mul *= x }

	for i := 1; i <= n; i++ {
		add(i)
		mult(i)
	}
	return sum, mul
}

func anonymousStructExample() any {
	x := struct {
		A int
		B string
		C []byte
	}{
		A: 1,
		B: "anon",
		C: []byte{1, 2, 3},
	}
	return x
}

// --- error handling helpers -----------------------------------------------

var (
	ErrInvalid = errors.New("invalid")
	ErrUnknown = errors.New("unknown")
)

type wrapError struct {
	msg string
	err error
}

func (w wrapError) Error() string {
	return w.msg + ": " + w.err.Error()
}

func maybeError(n int) error {
	if n < 0 {
		return wrapError{"negative", ErrInvalid}
	}
	if n > 1000 {
		return ErrUnknown
	}
	return nil
}

// --- rune/byte/string literal diversity -----------------------------------

var (
	rawString    = `raw
string with \n not escaped and "quotes"`
	interpString = "interp\tstring\nwith unicode: ☃"
	runes        = []rune("runes: αβγ")
	bytesSlice   = []byte{0x00, 0xFF, 'A', 'z'}
)

// --- generic function with constrained methods and maps -------------------

func invertMap[K comparable, V comparable](m map[K]V) map[V][]K {
	res := make(map[V][]K, len(m))
	for k, v := range m {
		res[v] = append(res[v], k)
	}
	return res
}

// --- main: structured but runtime output optional -------------------------

func main() {
	// basic entity graph
	base := &Base{ID: "entity-1", k: KindAlpha}
	base.Meta()["key"] = "value"

	adv := &Advanced{
		Base:  base,
		Score: Clamp(3.7, 0.0, 10.0),
		data:  []byte("payload"),
	}

	_ = adv.Describe()
	_ = classifyAny(KindGamma)
	_ = classifyAny(adv)

	// generics
	ints := []int{1, 2, 3, 4}
	sumSquares := MapReduce(
		ints,
		func(x int) int { return x * x },
		func(a, b int) int { return a + b },
		0,
	)
	_ = sumSquares

	p := Pair[int, string]{Left: 1, Right: "one"}
	flip := p.Flip()
	_ = flip

	// channels + fan-in
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Millisecond)
	defer cancel()

	c1 := genInts(3)
	c2 := genInts(2)
	merged := fanIn(ctx, c1, c2)
	for v := range merged {
		_ = v
	}

	// closures
	s, m := closurePlay(4)
	_ = s
	_ = m

	// panic/recover
	_ = withRecover(func() {
		panic("trigger")
	})

	// type switch
	_ = classifyAny("hello")
	_ = classifyAny(123)

	// map inversion
	m1 := map[string]int{"a": 1, "b": 2, "c": 1}
	im := invertMap(m1)
	_ = im

	// anonymous struct usage
	_ = anonymousStructExample()

	// rune/byte/string diversity
	_ = rawString
	_ = interpString
	_ = runes
	_ = bytesSlice

	// errors
	_ = maybeError(-1)
	_ = maybeError(2000)

	// global map access
	_ = globalMap["pi"]

	// Optionally print something; keep it gated for fuzz harnesses.
	if false {
		fmt.Println(adv.Describe(), sumSquares)
	}
}
