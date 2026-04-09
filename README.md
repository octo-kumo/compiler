# what is this?

Just some attempt at a AST parser for a simple programming language that takes inspirations from random places.

(plus a VM, and a typechecker.)

The code base is probably a big mess of spaghetti code, but I had a fun time writing it (no refactoring was ever done so it was just written in one go).

## how to use?

```bash
make compiler
./compiler examples/pi.y
```

This runs the a example program to calculate pi, it also prints out the AST, the reconstructed code from the AST, the typecheck result, and the final result of the program.

## language definition

```js
// single-line comment
/* multi-line
   comment */


// ─── types ────────────────────────────────────────────────────────────────────

// primitives
let a: long   = 42;
let b: float  = 3.14;
let c: bool   = true;
let d: str    = "hello";

// array type
let e: [long] = [1, 2, 3];

// map type
let f: {name: str, age: long} = {name: "alice", age: 30};

// function type
let g: (long, long) -> long = def(x: long, y: long) { x + y };

// ─── literals ─────────────────────────────────────────────────────────────────

let int_lit   = 100;
let neg_int   = -7;
let float_lit = 2.718;
let bare_dot  = 5.;            // valid, treated as 5.0
let str_esc   = "tab:\there\nnewline \"quoted\" \x41";
let arr_lit   = [10, 20, 30];
let map_lit   = {x: 1, y: 2};
let x = "1";
let y = "2";
let map_short = {x, y};        // shorthand: same as {x: x, y: y}


// ─── declarations & assignment ────────────────────────────────────────────────

let  mutable = 0;
const frozen = 99;             // const and let are identical right now

mutable = mutable + 1;         // assignment (left side must be a variable)


// ─── operators ────────────────────────────────────────────────────────────────

let arith  = (1 + 2) * 3 - 4 / 2;
let logic  = true == false;
let cmp    = 10 > 5;


// ─── indexing & slicing ───────────────────────────────────────────────────────

let first  = arr_lit[0];       // normal index
let slice1 = arr_lit[1:3];     // start:end
let slice2 = arr_lit[1:];      // start to end  (end defaults to -1)
let slice3 = arr_lit[:2];      // beginning to end (start defaults to 0)


// ─── if / else ────────────────────────────────────────────────────────────────

let result = if (cmp) {
    "big"
} else {
    "small"
};


// ─── named function ───────────────────────────────────────────────────────────

// return type is optional, typechecker will infer it
def add(x: long, y: long) -> long {
    x + y
};

// no return type annotation
def greet(name: str) {
    "hello, " + name
};


// ─── anonymous functions ──────────────────────────────────────────────────────

let square = def(n: long) -> long { n * n };
// as an argument
let transform = def(arr: [long], func: long->long) {/*TODO*/ 1};
let mapped = transform(arr_lit, def(v: long) { v * 2 });


// ─── function calls ───────────────────────────────────────────────────────────

let sum  = add(1, 2);
let hi   = greet("world");

// call on a parenthesized expression
let val  = (def(x: long) { x + 1 })(41);


// ─── recursion via self ───────────────────────────────────────────────────────

def factorial(n: long) -> long {
    if (n == 0) {
        1
    } else {
        n * self(n - 1)   // self = recursive call to factorial
    }
};


// ─── function types as parameters ────────────────────────────────────────────

def apply(f: (long) -> long, x: long) -> long {
    f(x)
};

def compose(
    f: long -> long,
    g: long -> long
) -> (long -> long) {
    def(x: long) { f(g(x)) }
};


// ─── blocks ───────────────────────────────────────────────────────────────────

// semicolon-separated expressions, value is the last one
let computed = {
    let tmp = 10;
    tmp = tmp * 2;
    tmp + 1          // 21
};


// ─── complex map & array types ────────────────────────────────────────────────

let matrix: [[long]]            = [[1, 2], [3, 4]];
let lookup: {key: [long]}       = {key: [1, 2, 3]};
let nested_fn: ([long]) -> long = def(xs: [long]) { xs[0] };
```

## how it works?

Each "parser" is a function that takes an input string and returns a `parser_result_t` struct, which contains the result and the remaining string, plus a boolean indicating success or failure.

```c
typedef struct {
    int is_some;
    char *remaining;
    void *value;
} parser_result_t;
typedef parser_result_t (*parser_t)(const char *input);

typedef struct {
    int is_some;
    char *remaining;
    Expr *value;
} ast_parser_result_t;
typedef ast_parser_result_t (*ast_parser_t)(const char *input);
```

The base AST logic works with these primitives:

### `parse_satisfy`

Just a simple parser that checks if the first character of the input satisfies a given predicate.

This can be used to build other parsers.

```c
parser_result_t parse_satisfy(const char *input, int (*predicate)(char)) {
    if (!input || input[0] == '\0') { return none(input); }
    if (predicate(input[0])) { return some((uintptr_t)(input[0]), input + 1); }
    return none(input);
}
```

```c
#define MAKE_TAKE_PARSER(name, pred)                                           \
    parser_result_t parse_take_##name(const char *input) {                     \
        return parse_satisfy(input, pred);                                     \
    }

#define MAKE_MAP_PARSER(name, pred, mapper)                                    \
    parser_result_t parse_##name(const char *input) {                          \
        return parse_map(parse_satisfy(input, pred),                           \
                         (void *(*)(void *))mapper);                           \
    }

MAKE_TAKE_PARSER(space, is_space);
MAKE_MAP_PARSER(digit, is_digit, char_to_int);
MAKE_MAP_PARSER(number_sign, is_number_sign, char_to_sign);
MAKE_TAKE_PARSER(alpha, is_alpha);
```

### `parse_some` and `parse_many`

This is used almost everywhere in the code base, it takes in some parser and applies it to the input continuously until it fails, and returns a list of the results.

Difference between the two is that `parse_some` requires at least one successful parse, while `parse_many` can succeed with zero parses, they depend on each other.

This is basically a direct translation from the OCaml code in the lecture.

```c
parser_result_t parse_some(parser_t p, const char *input) {
    parser_result_t res = p(input);
    if (!res.is_some) { return none(input); }
    parser_result_t w = parse_many(p, res.remaining);
    list_t *combined = (list_t *)malloc(sizeof(list_t));
    combined->value = res.value;
    combined->next = (list_t *)w.value;
    return some(combined, w.remaining);
}

parser_result_t parse_many(parser_t p, const char *input) {
    parser_result_t res = parse_some(p, input);
    if (res.is_some) { return res; }
    return of_null(input);
}
```

That is more or less the core of the parser.

My idea between `parser` and `ast_parser` is that the former returns back primitives and tokens while the latter returns back AST nodes.

### AST definition

The AST is defined in `ast.h`, it is a recursive struct with union to represent different types of expressions.

```c
typedef struct Expr {
    ExprKind kind;
    union {
        long elong;
        double efloat;
        char *evar;
        bool ebool;
        EStr estr;
        EFunc efunc;
        EIf if_node;
        EOp op_node;
        EAssignment assignment_node;
        EDeclaration declaration_node;
        ECall call_node;
        EBlock block_node;
        EArray array_node;
        EArrayIdx array_idx_node;
        EArrayIdxRange array_idx_range_node;
        EMap map_node;
    } as;
} Expr;
```

### AST parser

This follows the same pattern as the base parsers, but it returns back `Expr` nodes instead of primitives.

I have functions that will parse any expression from some set, and they are used recursively in individual specific parsers to parse sub-expressions.

```c
#define __EXPR_BLOCK_PARSERS ast_parse_brace_block

#define __EXPR_INLINE_PARSERS                                                  \
    ast_parse_function, ast_parse_map, ast_parse_array, ast_parse_binary_op,   \
        ast_parse_function_call, ast_parse_paren_expr, ast_parse_if,           \
        ast_parse_declaration, ast_parse_number, ast_parse_string,             \
        ast_parse_array_idx, ast_parse_variable

const ast_parser_t EXPR_BLOCK_PARSERS[] = {__EXPR_BLOCK_PARSERS, NULL};
const ast_parser_t EXPR_INLINE_PARSERS[] = {__EXPR_INLINE_PARSERS, NULL};
const ast_parser_t EXPR_PARSERS[] = {__EXPR_INLINE_PARSERS,
                                     __EXPR_BLOCK_PARSERS, NULL};
const ast_parser_t EXPR_ALLOWED_BIN_OPS[] = {
    ast_parse_paren_expr, ast_parse_function_call,
    ast_parse_map,        ast_parse_array,

    ast_parse_number,     ast_parse_string,
    ast_parse_variable,   NULL};

ast_parser_result_t ast__parse_expr(const char *input) {
    return ast__parse_first(EXPR_PARSERS, input);
}

ast_parser_result_t ast__parse_inline_expr(const char *input) {
    return ast__parse_first(EXPR_INLINE_PARSERS, input);
}

ast_parser_result_t ast__parse_inside_binary_op(const char *input) {
    return ast__parse_first(EXPR_ALLOWED_BIN_OPS, input);
}
```

### how ast parsers work?

For example, take the array indexing parser:

```c
ast_parser_result_t ast_parse_array_idx(const char *input) {
    const char *original_input = input;
    ast_parser_result_t ast_arr = ast_parse_var_or_paren_expr(input);
    if (!ast_arr.is_some) { return anone(original_input); }
    input = ast_arr.remaining;
    EXPECT_SYMBOL('[', {
        ast_free(ast_arr.value);
        return anone(original_input);
    });
    ast_parser_result_t ast_idx = ast__parse_expr(input);
    input = ast_idx.remaining;
    parser_result_t mid_res = parse_symbol(input, ':');
    input = mid_res.remaining;
    ast_parser_result_t ast_end_idx =
        mid_res.is_some ? ast__parse_expr(input) : anone(input);
    input = ast_end_idx.remaining;
    EXPECT_SYMBOL(']', {
        ast_free(ast_arr.value);
        if (ast_idx.is_some) { ast_free(ast_idx.value); }
        if (ast_end_idx.is_some) { ast_free(ast_end_idx.value); }
        return anone(original_input);
    });

    if (mid_res.is_some) {
        // Handle slice
        Expr *slice_node = (Expr *)malloc(sizeof(Expr));
        slice_node->kind = EXPR_EARRAY_IDX_RANGE;
        slice_node->as.array_idx_range_node.array = ast_arr.value;
        // start defaults to 0
        slice_node->as.array_idx_range_node.start =
            ast_idx.is_some ? ast_idx.value : ast_of_long(0);
        // end defaults to -1, which means the end of the array
        slice_node->as.array_idx_range_node.end =
            ast_end_idx.is_some ? ast_end_idx.value : ast_of_long(-1);
        return asome(slice_node, input);
    } else if (ast_idx.is_some) {
        // Handle normal index
        Expr *idx_node = (Expr *)malloc(sizeof(Expr));
        idx_node->kind = EXPR_EARRAY_IDX;
        idx_node->as.array_idx_node.array = ast_arr.value;
        idx_node->as.array_idx_node.idx = ast_idx.value;
        if (ast_end_idx.is_some) { ast_free(ast_end_idx.value); }
        return asome(idx_node, input);
    } else {
        if (ast_idx.is_some) { ast_free(ast_idx.value); }
        if (ast_end_idx.is_some) { ast_free(ast_end_idx.value); }
        return anone(original_input);
    }
}
```

You can see the recursive nature of the parser here, it calls `ast__parse_expr` to parse the index and end index, which can be any expression.

Though I must admit the code is really bad coz I am freeing stuff on every failure case, which makes it really hard to read and maintain, but it works for now.

### the VM

The VM is in `vm.c`, it just walks through the AST and executes the code, nothing special.

It has a scoped variable map that has reference to parent scope, this isn't ideal for function closures but it will work for normal program flow.

```c
struct VMVariableScope;
typedef struct VMVariableScope {
    struct VMVariableScope *parent;
    map_t variables; // Map of variable name to Variable
} VMVariableScope;
VMValue *vm_scope_get(VMVariableScope *scope, const char *name);
void vm_scope_set(VMVariableScope *scope, const char *name, VMValue *value);
```

### the type checker

The type checker is really similar to the VM, it just walks through the AST and "evaluates" the type instead of the value of the expression, and it also has a scoped type variable map for type inference.

## limitations

- missing a lot of features for arrays and maps
- not memory safe
- no edge case handling in the parser, it assume valid code as input
- not very useful as a real programming language
- I can't think of a way to compile this into ASM.
- Math don't work as you may expect.

```js
print("3 + 4 * 5 = " + (3 + 4 * 5));
print("4 * 5 + 3 = " + (4 * 5 + 3));
/*
[print] 3 + 4 * 5 = 23
[print] 4 * 5 + 3 = 32
*/
```
