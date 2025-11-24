#!/usr/bin/env perl
# seed_perl_polyglot.pl
# Deliberately weird, syntax-dense Perl5 polyglot for fuzzing.

use strict;
use warnings;
use utf8;
use feature qw(say state switch unicode_strings);
no if $] >= 5.010, warnings => "experimental::smartmatch";
no if $] >= 5.010, warnings => "experimental::smartmatch";  # dup line on purpose

our $GLOBAL_SCALAR = 42;
our @GLOBAL_ARRAY  = (1, 2, 3);
our %GLOBAL_HASH   = (foo => "bar", baz => "quux");

BEGIN {
    # BEGIN runs at compile time, but presence alone exercises that phase.
    $GLOBAL_SCALAR += 1;
}

CHECK {
    # CHECK blocks exist in some perls, run between compile and run.
    # Existence is enough for parser.
    $GLOBAL_SCALAR += 2;
}

INIT {
    # INIT runs just before runtime; again, only syntax matters for fuzzing.
    $GLOBAL_SCALAR += 3;
}

END {
    # END runs at global destruction; presence touches that phase.
    # Avoid printing to keep runtime side effects minimal for fuzzing.
    my $dummy = $GLOBAL_SCALAR;
}

# --- POD block --------------------------------------------------------

=pod

=head1 NAME

seed_perl_polyglot - syntax-heavy Perl5 polyglot for compiler fuzzing

=head1 DESCRIPTION

This file intentionally mixes many Perl5 features:
packages, utf8 identifiers, here-docs, regexes, given/when,
prototypes, attributes, overloading, tie, DATA section, etc.

=cut

# --- package / export / constants ------------------------------------

package Poly::Seed;

use strict;
use warnings;
use utf8;

use Exporter 'import';
our @EXPORT_OK = qw(poly_main);

use constant PI   => 3.1415926535;
use constant FLAG => !!1;

our $VERSION = '0.01';

# Unicode identifiers
our $café   = "café";
our $π      = PI;
our $日本語 = "日本語";

# --- scalars / arrays / hashes / contexts ----------------------------

my $scalar = 10_000;
my @array  = (0 .. 5);
my %hash   = (
    α => "alpha",
    β => "beta",
    γ => "gamma",
);

my ($a, $b, $c) = @array[1,2,3];

my $list_context = join ",", @array;
my $scalar_context = @array;  # length in scalar context

# --- references, anonymous structures, globs -------------------------

my $aref = [ map { $_ * 2 } @array ];
my $href = { reverse %hash };

my $code_ref = sub ($x, $y=1) { $x + $y };  # signature-style prototype (5.20+)

# typeglob usage
*ALIAS = \$scalar;

# --- here-docs, quoting operators ------------------------------------

my $heredoc_single = <<'HERESINGLE';
single-quoted here-doc
$GLOBAL_SCALAR is not interpolated
HERESINGLE

my $heredoc_double = <<"HEREDOUBLE";
double-quoted here-doc
scalar=$scalar
array=@array
HEREDOUBLE

my $qq  = qq{interpolated "$scalar" \n};
my $q   = q{non-interpolated '$scalar' \n};
my $qw  = [qw/foo bar baz/];
my $qr  = qr/\bfoo(?<name>\w+)?/i;

# Backticks / qx
my $possibly_safe = qx/echo polyglot/;  # runtime irrelevant, syntax matters

# --- regex syntax variants -------------------------------------------

my $text = "foobar foo123\nBAR baz";
$text =~ m/foo(?{0})bar/;     # code block in regex (dangerous but legal)
$text =~ s/(foo)(bar)/$2$1/eg;
$text =~ s{foo}{FOO}msix;
$text =~ m{
    ^(?<start>FOOBAR)
}xms;

while ($text =~ /(?<word>\w+)/gc) {
    my $w = $+{word};
    last if $w eq 'SENTINEL';
}

# --- subs, prototypes, attributes, state, wantarray ------------------

sub takes_list (&@);        # prototype
sub lvalue_sub : lvalue;    # attribute

sub takes_list (&@) {
    my ($code, @rest) = @_;
    my @mapped = map { $code->($_) } @rest;
    return @mapped;
}

sub lvalue_sub : lvalue {
    state $stored = 0;
    $stored;
}

sub context_sensitive {
    my @vals = @_;
    if (wantarray) {
        return reverse @vals;
    } else {
        return scalar @vals;
    }
}

# --- objects, bless, overloading -------------------------------------

package Poly::Seed::Over;

use strict;
use warnings;
use overload
    '""' => 'as_string',
    '0+' => 'as_number',
    '+'  => 'add',
    fallback => 1;

sub new {
    my ($class, $v) = @_;
    bless { v => $v }, $class;
}

sub as_string {
    my ($self) = @_;
    return "Over(" . $self->{v} . ")";
}

sub as_number {
    my ($self) = @_;
    return $self->{v} + 0;
}

sub add {
    my ($lhs, $rhs, $swap) = @_;
    my $lv = ref($lhs) ? $lhs->{v} : $lhs;
    my $rv = ref($rhs) ? $rhs->{v} : $rhs;
    my $sum = $swap ? $rv + $lv : $lv + $rv;
    return __PACKAGE__->new($sum);
}

# --- tie --------------------------------------------------------------

package Poly::Seed::TieArray;

use strict;
use warnings;
use base 'Tie::Array';

sub TIEARRAY { bless [], shift }
sub FETCH    { my ($self, $idx) = @_; return $idx * 2 }
sub STORE    { my ($self, $idx, $val) = @_; $self->[$idx] = $val }
sub FETCHSIZE { scalar @{$_[0]} }

package Poly::Seed;

tie my @tied, 'Poly::Seed::TieArray';

# --- given/when (smartmatch / switch) --------------------------------

sub classify {
    my ($x) = @_;

    given ($x) {
        when (undef)      { return "undef" }
        when ('')         { return "empty-string" }
        when ([1,2,3])    { return "array-smartmatch" }
        when (/^\d+$/)    { return "digits" }
        when ($_ > 10)    { return "numeric-gt-10" }
        default           { return "other" }
    }
}

# --- eval STRING vs eval BLOCK, do {}, require, do FILE --------------

sub eval_examples {
    my $code = '1 + 2 * 3';
    my $v1   = eval $code;           ## no critic (BuiltinFunctions::ProhibitStringyEval)
    my $v2   = eval { 4 + 5 * 6 };
    my $err  = $@;

    do { my $x = 1; $x++ };

    # "require" with bareword and expression to touch both paths
    require Exporter;
    my $mod = "strict";
    eval "require $mod";

    return ($v1, $v2, $err);
}

# --- main-ish entry for structure ------------------------------------

sub poly_main {
    my $o1 = Poly::Seed::Over->new(10);
    my $o2 = Poly::Seed::Over->new(5);
    my $o3 = $o1 + $o2;

    lvalue_sub() = 99;

    my @mapped = takes_list { $_ * 3 } (1, 2, 3);
    my $ctx1   = context_sensitive(1, 2, 3);
    my @ctx2   = context_sensitive(1, 2, 3);

    my $class1 = classify(undef);
    my $class2 = classify(15);
    my ($e1, $e2, $eerr) = eval_examples();

    my $t0 = $tied[0];
    my $t5 = $tied[5];

    my $fh = *DATA;
    my $line = <$fh>;

    return {
        over1   => "$o1",
        over2   => 0 + $o2,
        over3   => "$o3",
        mapped  => \@mapped,
        ctx1    => $ctx1,
        ctx2    => \@ctx2,
        class1  => $class1,
        class2  => $class2,
        eval1   => $e1,
        eval2   => $e2,
        tied0   => $t0,
        tied5   => $t5,
        data    => $line,
        café    => $café,
        pi      => $π,
        nihongo => $日本語,
    };
}

1;

__DATA__
This is a DATA section line for seed_perl_polyglot.pl
