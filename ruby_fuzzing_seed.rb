#!/usr/bin/env ruby
# seed_ruby_polyglot.rb
# Deliberately dense, syntax-heavy Ruby script for fuzzing the Ruby parser/VM.
# frozen_string_literal: true

# --- magic constants / encodings / BEGIN / END -----------------------------

# encoding: UTF-8

BEGIN {
  # Runs before everything else; existence exercises this phase.
  $seed_begin_ran = true
}

END {
  # Runs at exit; body irrelevant for fuzzing, presence matters.
  $seed_end_ran = true
}

FILE_NAME  = __FILE__
LINE_NO    = __LINE__
ENCODING_C = __ENCODING__

$global_var  = 42
@@class_var  = :not_used_but_declared rescue nil # might be nil in toplevel
$ω_unicode   = "ω"
π            = 3.14159
日本語       = "にほんご"

# --- literals: arrays, hashes, ranges, symbols, regexes, heredocs ----------

int_dec   = 10_000
int_hex   = 0xDEAD_BEEF
float_num = 1_234.5e-2
complex   = Complex(1, 2)

ary       = [1, 2, 3, *[4, 5]]
hash_old  = { :foo => 1, :bar => 2 }
hash_new  = { foo: 1, bar: 2, **{ baz: 3 } }

range_inc = 1..5
range_exc = 1...5

sym_plain   = :plain
sym_quoted  = :"with space"
sym_unicode = :π

rx_basic   = /foo\d+/i
rx_named   = /(?<word>\w+)\s+(?<num>\d+)/

words      = %w[alpha beta gamma]
symbols    = %i[one two three]
q_str      = %q{no interpolation #{1 + 2}}
Q_str      = %Q{yes interpolation #{1 + 2}}
cmd        = %x[echo ruby_polyglot] # backticks variant

heredoc_single = <<'EOS_SINGLE'
single-quoted heredoc
no interpolation #{1 + 2}
EOS_SINGLE

heredoc_double = <<"EOS_DOUBLE"
double-quoted heredoc
with interpolation #{1 + 2}
EOS_DOUBLE

# --- multiple assignment / splats / keyword args ---------------------------

a, b, *rest = 1, 2, 3, 4, 5

def kw_example(x, *args, y: 1, z: 2, **kw, &block)
  block&.call(x, y, kw)
  [x, args, y, z, kw]
end

kw_result = kw_example(10, 20, 30, y: 99, extra: :ok) do |x, y, kw|
  $last_block_args = [x, y, kw]
end

# --- modules, refinements, classes, singleton classes ----------------------

module StringRefinements
  refine String do
    def shout
      upcase + "!"
    end
  end
end

using StringRefinements

module PolySeed
  VERSION = "0.0.1"

  module Inner
    CONST_INNER = :inner

    def self.inner_value
      CONST_INNER
    end
  end

  class Base
    attr_reader :name
    @@instances = []

    def self.instances
      @@instances
    end

    def initialize(name)
      @name = name
      @@instances << self
    end

    def greet
      "hello #{name}"
    end

    private

    def private_secret
      :secret
    end
  end

  class Derived < Base
    attr_accessor :value

    def initialize(name, value = 0)
      super(name)
      @value = value
    end

    def greet
      "#{super} from Derived with #{value}"
    end

    def [](key)
      { name: name, value: value }[key]
    end
  end
end

obj = Object.new

class << obj
  attr_accessor :x

  def singleton_method_example(y)
    @x = y
    "singleton #{y}"
  end
end

obj.singleton_method_example(123)

# --- alias, undef, method_missing, respond_to_missing? ---------------------

class PolyMeta
  def foo(x)
    "foo #{x}"
  end

  alias old_foo foo

  def foo(x)
    "wrapped #{old_foo(x)}"
  end

  def bar; "bar"; end

  undef bar rescue nil

  def method_missing(name, *args, &block)
    if name.to_s.start_with?("dyn_")
      "dynamic: #{name}(#{args.inspect})"
    else
      super
    end
  end

  def respond_to_missing?(name, include_private = false)
    name.to_s.start_with?("dyn_") || super
  end
end

poly_meta = PolyMeta.new
poly_meta.foo(10)      # alias + wrapper
poly_meta.dyn_call(1)  # method_missing path

# --- blocks, lambdas, Procs, yield, Enumerator, Fiber -----
