#!/usr/bin/env php
<?php
/**
 * seed_php_polyglot.php
 * Deliberately dense, syntax-heavy PHP 8.1+ script for parser / compiler fuzzing.
 *
 * Exercises:
 *  - declare(strict_types), namespaces, use, group use
 *  - attributes, enums, traits, interfaces, anonymous classes
 *  - union / intersection types, nullable, generics-ish annotations
 *  - closures, arrow functions, variadics, references
 *  - match(), named arguments, unpack, generators, yield from
 *  - heredoc/nowdoc, magic constants, error control, @, try/catch/finally
 *  - static, late static binding, magic methods, ArrayAccess, IteratorAggregate
 */

declare(strict_types=1);

namespace PolySeed\Root {
    use ArrayAccess;
    use IteratorAggregate;
    use Traversable;
    use stdClass;
    use PolySeed\Root\Sub\{InnerClass as RenamedInner, InnerTrait};

    #[\Attribute(\Attribute::TARGET_CLASS | \Attribute::TARGET_METHOD)]
    class DemoAttribute {
        public function __construct(
            public string $name,
            public int $level = 0,
        ) {}
    }

    enum Status: string {
        case Pending = 'pending';
        case Active  = 'active';
        case Done    = 'done';

        public function isFinal(): bool {
            return $this === self::Done;
        }
    }

    interface Identifiable {
        public function getId(): string;
    }

    interface Repository extends Identifiable {
        /** @return list<object> */
        public function findAll(): array;
    }

    trait LoggingTrait {
        protected function log(string $msg): void {
            // runtime irrelevant; presence exercises trait + visibility
            $line = __LINE__;
            $file = __FILE__;
            $ctx  = sprintf('[%s:%d] %s', $file, $line, $msg);
            // suppress warnings via @, exercises error control operator
            @file_put_contents('php://temp', $ctx . PHP_EOL, FILE_APPEND);
        }
    }

    #[DemoAttribute('MainRepo', level: 3)]
    class InMemoryRepository implements Repository, ArrayAccess, IteratorAggregate {
        use LoggingTrait;
        use InnerTrait;

        private string $id;
        /** @var array<string, object> */
        private array $items = [];

        public function __construct(?string $id = null) {
            $this->id = $id ?? 'repo-' . uniqid('', true);
        }

        public function getId(): string {
            return $this->id;
        }

        public function add(string $key, object $value): void {
            $this->items[$key] = $value;
            $this->log("added:$key");
        }

        public function findAll(): array {
            return array_values($this->items);
        }

        // ArrayAccess
        public function offsetExists(mixed $offset): bool {
            return array_key_exists((string)$offset, $this->items);
        }

        public function offsetGet(mixed $offset): mixed {
            return $this->items[(string)$offset] ?? null;
        }

        public function offsetSet(mixed $offset, mixed $value): void {
            if (!\is_object($value)) {
                throw new \InvalidArgumentException('value must be object');
            }
            $key = $offset === null ? (string)count($this->items) : (string)$offset;
            $this->items[$key] = $value;
        }

        public function offsetUnset(mixed $offset): void {
            unset($this->items[(string)$offset]);
        }

        // IteratorAggregate
        public function getIterator(): Traversable {
            return new \ArrayIterator($this->items);
        }

        // Magic methods
        public function __toString(): string {
            return 'InMemoryRepository(' . $this->id . ')';
        }

        public function __invoke(mixed ...$args): int {
            return count($args);
        }

        public function __clone() {
            $this->id .= '-clone';
        }
    }

    namespace Sub {
        trait InnerTrait {
            protected function innerMark(): string {
                return 'inner:' . static::class;
            }
        }

        class InnerClass {
            public function foo(): string {
                return __METHOD__;
            }
        }
    }
}

namespace PolySeed\Root\Util {
    use PolySeed\Root\Status;

    // Simple generic-ish container with union & nullable types
    class Box {
        public function __construct(
            private int|string|null $value,
        ) {}

        public function get(): int|string|null {
            return $this->value;
        }

        public function map(callable $fn): static {
            $this->value = $fn($this->value);
            return $this;
        }

        public function statusFromValue(): Status {
            return match (true) {
                $this->value === null          => Status::Pending,
                \is_string($this->value)       => Status::Active,
                \is_int($this->value) && $this->value > 0 => Status::Done,
                default                        => Status::Pending,
            };
        }
    }

    // Generator + yield from
    function genRange(int $start, int $end): \Generator {
        for ($i = $start; $i <= $end; $i++) {
            yield $i => $i * $i;
        }
    }

    function genWrapper(int $n): \Generator {
        if ($n <= 0) {
            return;
        }
        yield from genRange(1, $n);
    }

    // Arrow function, variadics, unpack
    $arrowSum = fn (int ...$xs): int => array_sum($xs);

    function apply(callable $f, array $args): mixed {
        return $f(...$args);
    }

    // Heredoc / nowdoc
    $heredoc = <<<TXT
heredoc with interpolation: status classes
Current enum name: {Status::class}
TXT;

    $nowdoc = <<<'TXT'
nowdoc without interpolation: ${nope}
TXT;
}

namespace {
    use PolySeed\Root\InMemoryRepository;
    use PolySeed\Root\Sub\InnerClass;
    use PolySeed\Root\Util\Box;
    use PolySeed\Root\Util as Util;

    // Reference variables
    $x = 10;
    $y =& $x;
    $y += 5;

    // Anonymous class exercising implements/extends
    $anon = new class('anon-1') extends InMemoryRepository {
        public function __construct(string $id) {
            parent::__construct($id);
        }
    };

    $repo = new InMemoryRepository();
    $repo->add('a', (object)['k' => 1]);
    $repo['b'] = new stdClass();

    $all  = $repo->findAll();
    $iter = [];
    foreach ($repo as $k => $v) {
        $iter[$k] = $v;
    }

    // Generators
    $genValues = [];
    foreach (Util\genWrapper(5) as $k => $v) {
        $genValues[$k] = $v;
    }

    // Box + match
    $boxInt    = new Box(5);
    $boxString = new Box('hi');
    $boxNull   = new Box(null);

    $statuses = [
        $boxInt->statusFromValue(),
        $boxString->statusFromValue(),
        $boxNull->statusFromValue(),
    ];

    // Closures capturing vars
    $captured = function () use (&$x, $statuses): array {
        $x++;
        return [$x, array_map(static fn($s) => $s->value, $statuses)];
    };

    $captureResult = $captured();

    // try / catch / finally + multi-catch
    try {
        if (rand(0, 1) === 1) {
            throw new \RuntimeException('rt');
        } else {
            throw new \LogicException('lg');
        }
    } catch (\RuntimeException|\LogicException $e) {
        $errClass = $e::class;
    } finally {
        $finallySeen = true;
    }

    // Calling __invoke via variable function call
    $invokeCount = $repo(1, 2, 3);

    // Anonymous function with attribute & named args (PHP 8+)
    #[PolySeed\Root\DemoAttribute('fn', level: 1)]
    $named = function (int $a, int $b, int $c = 0): int {
        return $a + $b + $c;
    };
    $namedResult = $named(a: 1, b: 2, c: 3);

    // Use InnerClass aliased via namespace import
    $inner = new InnerClass();
    $innerFoo = $inner->foo();

    // Data structure snapshot to keep the compiler generating types/code
    $snapshot = [
        'file'         => __FILE__,
        'line'         => __LINE__,
        'dir'          => __DIR__,
        'x'            => $x,
        'y'            => $y,
        'repo'         => (string)$repo,
        'anon'         => (string)$anon,
        'all'          => $all,
        'iter'         => $iter,
        'gen'          => $genValues,
        'statuses'     => array_map(static fn($s) => $s->value, $statuses),
        'capture'      => $captureResult,
        'errClass'     => $errClass ?? null,
        'finallySeen'  => $finallySeen ?? false,
        'invokeCount'  => $invokeCount ?? null,
        'namedResult'  => $namedResult,
        'innerFoo'     => $innerFoo,
        'heredocLen'   => strlen(Util::$heredoc ?? ''),
        'nowdocLen'    => strlen(Util::$nowdoc ?? ''),
    ];

    // No output; for fuzzing we care only that PHP parses / compiles this.
    if (false) {
        var_dump($snapshot);
    }
}
