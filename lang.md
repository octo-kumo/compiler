BIG TODO: write a language spec

My language is C-like (so i use braces), with some mix of JS/TS-like features and some other random stuff from random languages.

No import/export system, single file only (for now).

Functions defined in global scope are exposed globally as labels.

Functions are supported as first-class citizens, and can be passed around as values.

```
{
    const add = def(a, b) {
        (a + b);
    };
    add(10, 20);
    const minus = def(a, b) {
        (a - b);
    };
    minus(30, add(10, minus(add((2000 * 2), (2 * (1 * (5 - (2 - (2 - 4)))))), 1)));
    print(""yooo"");
    3.141593;
}
```
