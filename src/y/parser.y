def tclamp(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> long {
    let n = len(toks);
    let q = p;
    if (q >= n) { q = n - 1; 0; } else { 0; };
    q
};

def tt(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> str {
    let tok = toks[tclamp(toks, p)];
    tok.t
};
def tv(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> str {
    let tok = toks[tclamp(toks, p)];
    tok.v
};
def tline(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> long {
    let tok = toks[tclamp(toks, p)];
    tok.line
};
def tcol(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> long {
    let tok = toks[tclamp(toks, p)];
    tok.col
};

def is_kw(toks: [{ t: str, v: str, line: long, col: long }], p: long, w: str) -> bool {
    let tok = toks[tclamp(toks, p)];
    if (tok.t == "kw") {
        if (tok.v == w) { true } else { false }
    } else { false }
};
def is_punct(toks: [{ t: str, v: str, line: long, col: long }], p: long, w: str) -> bool {
    let tok = toks[tclamp(toks, p)];
    if (tok.t == "punct") {
        if (tok.v == w) { true } else { false }
    } else { false }
};
def is_op(toks: [{ t: str, v: str, line: long, col: long }], p: long, w: str) -> bool {
    let tok = toks[tclamp(toks, p)];
    if (tok.t == "op") {
        if (tok.v == w) { true } else { false }
    } else { false }
};

def res(node, p: long) -> { node: {k: str}, pos: long } {
    { node: node, pos: p }
};

def sep_by(toks: [{ t: str, v: str, line: long, col: long }], p: long, close: str, one: str) -> { node: [{k: str}], pos: long } {
    let xs: [{k: str}] = [];
    let pos = p;
    let go = true;
    if (is_punct(toks, pos, close)) { go = false; 0; } else { 0; };
    while (go) {
        let r = { node: { k: "null" }, pos: pos };
        if (one == "expr") {
            r = parse_expr(toks, pos);
            0
        } else { 0 };
        let rnode = r.node;
        let rpos = r.pos;
        xs = push(xs, rnode);
        pos = rpos;
        if (is_punct(toks, pos, ",")) {
            pos = pos + 1;
            if (is_punct(toks, pos, close)) { go = false; 0; } else { 0; };
            0
        } else {
            if (is_punct(toks, pos, close)) { 0; } else {
                xs = push(xs, { k: "err", msg: "unexpected '" + tv(toks, pos) + "' (expected ',' or '" + close + "')", line: tline(toks, pos), col: tcol(toks, pos) });
                0;
            };
            go = false;
            0
        };
    };
    { node: xs, pos: pos }
};


def op_prec(op: str) -> long {
    if (op == "||") { 1 }
    else if (op == "&&") { 2 }
    else if (op == "==") { 3 }
    else if (op == "!=") { 3 }
    else if (op == "<") { 4 }
    else if (op == ">") { 4 }
    else if (op == "<=") { 4 }
    else if (op == ">=") { 4 }
    else if (op == "::") { 5 }
    else if (op == "+") { 6 }
    else if (op == "-") { 6 }
    else if (op == "*") { 7 }
    else if (op == "/") { 7 }
    else if (op == "%") { 7 }
    else { 0 }
};


def parse_primary(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    let t = tt(toks, p);
    let v = tv(toks, p);
    let ln = tline(toks, p);
    let cl = tcol(toks, p);
    if (t == "num") {
        res({ k: "num", v: v, line: ln, col: cl }, p + 1)
    } else if (t == "str") {
        res({ k: "str", v: v, line: ln, col: cl }, p + 1)
    } else if (t == "id") {
        res({ k: "id", v: v, line: ln, col: cl }, p + 1)
    } else if (is_kw(toks, p, "true")) {
        res({ k: "bool", v: "true", line: ln, col: cl }, p + 1)
    } else if (is_kw(toks, p, "false")) {
        res({ k: "bool", v: "false", line: ln, col: cl }, p + 1)
    } else if (is_kw(toks, p, "null")) {
        res({ k: "null", line: ln, col: cl }, p + 1)
    } else if (is_punct(toks, p, "(")) {
        let inner = parse_expr(toks, p + 1);
        res(inner.node, inner.pos + 1)    } else if (is_punct(toks, p, "[")) {
        parse_array(toks, p)
    } else if (is_punct(toks, p, "{")) {
        if (brace_is_map(toks, p)) { parse_map(toks, p) } else { parse_block(toks, p) }
    } else if (is_kw(toks, p, "def")) {
        parse_func(toks, p)
    } else if (is_kw(toks, p, "if")) {
        parse_if(toks, p)
    } else if (is_kw(toks, p, "while")) {
        parse_while(toks, p)
    } else if (is_kw(toks, p, "for")) {
        parse_for_or_range(toks, p)
    } else if (is_kw(toks, p, "foreach")) {
        parse_foreach(toks, p)
    } else {
        res({ k: "null" }, p + 1)
    }
};


def parse_postfix(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    let base = parse_primary(toks, p);
    let node = base.node;
    let pos = base.pos;
    let go = true;
    while (go) {
        if (is_punct(toks, pos, "(")) {
            let a = parse_args(toks, pos + 1);
            node = { k: "call", callee: node, args: a.node, line: tline(toks, pos), col: tcol(toks, pos) };
            pos = a.pos + 1;        } else if (is_punct(toks, pos, "[")) {
            let bln = tline(toks, pos);
            let bcl = tcol(toks, pos);
            if (is_punct(toks, pos + 1, ":")) {
                if (is_punct(toks, pos + 2, "]")) {
                    node = { k: "slice", arr: node, lo: { k: "null" }, hi: { k: "null" }, line: bln, col: bcl };
                    pos = pos + 3;                } else {
                    let second = parse_expr(toks, pos + 2);
                    node = { k: "slice", arr: node, lo: { k: "null" }, hi: second.node, line: bln, col: bcl };
                    pos = second.pos + 1;                };
            } else {
                let first = parse_expr(toks, pos + 1);
                if (is_punct(toks, first.pos, ":")) {
                    if (is_punct(toks, first.pos + 1, "]")) {
                        node = { k: "slice", arr: node, lo: first.node, hi: { k: "null" }, line: bln, col: bcl };
                        pos = first.pos + 2;                    } else {
                        let second = parse_expr(toks, first.pos + 1);
                        node = { k: "slice", arr: node, lo: first.node, hi: second.node, line: bln, col: bcl };
                        pos = second.pos + 1;                    };
                } else {
                    node = { k: "index", arr: node, idx: first.node, line: bln, col: bcl };
                    pos = first.pos + 1;                };
            };
        } else if (is_op(toks, pos, ".")) {
            let name = tv(toks, pos + 1);
            node = { k: "dot", obj: node, key: name, line: tline(toks, pos), col: tcol(toks, pos) };
            pos = pos + 2;
        } else {
            go = false;
            0
        };
    };
    res(node, pos)
};

def parse_args(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: [{k: str}], pos: long } {
    sep_by(toks, p, ")", "expr")
};


def parse_binary(toks: [{ t: str, v: str, line: long, col: long }], p: long, min_prec: long) -> { node: {k: str}, pos: long } {
    let left_r = parse_unary(toks, p);
    let left = left_r.node;
    let pos = left_r.pos;
    let go = true;
    while (go) {
        let op = tv(toks, pos);
        let prec = 0;
        if (tt(toks, pos) == "op") { prec = op_prec(op); 0; } else { 0 };
        if (prec == 0) {
            go = false;
            0
        } else if (prec < min_prec) {
            go = false;
            0
        } else {
            let right_r = parse_binary(toks, pos + 1, prec + 1);
            left = { k: "bin", op: op, l: left, r: right_r.node, line: tline(toks, pos), col: tcol(toks, pos) };
            pos = right_r.pos;
            0
        };
    };
    res(left, pos)
};

def parse_unary(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    if (is_op(toks, p, "-")) {
        let inner = parse_unary(toks, p + 1);
        res({ k: "un", op: tv(toks, p), e: inner.node, line: tline(toks, p), col: tcol(toks, p) }, inner.pos)
    } else if (is_op(toks, p, "!")) {
        let inner = parse_unary(toks, p + 1);
        res({ k: "un", op: tv(toks, p), e: inner.node, line: tline(toks, p), col: tcol(toks, p) }, inner.pos)
    } else if (is_op(toks, p, "&")) {
        let inner = parse_unary(toks, p + 1);
        res({ k: "addr", e: inner.node, line: tline(toks, p), col: tcol(toks, p) }, inner.pos)
    } else if (is_op(toks, p, "*")) {
        let inner = parse_unary(toks, p + 1);
        res({ k: "deref", e: inner.node, line: tline(toks, p), col: tcol(toks, p) }, inner.pos)
    } else {
        parse_postfix(toks, p)
    }
};

def parse_expr(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    parse_binary(toks, p, 1)
};


def parse_array(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    let ln = tline(toks, p);
    let cl = tcol(toks, p);
    if (is_punct(toks, p + 1, "]")) {
        res({ k: "array", elems: [], line: ln, col: cl }, p + 2)
    } else {
        let first = parse_expr(toks, p + 1);
        let pos = first.pos;
        if (is_punct(toks, pos, ";")) {
            let n = -1;
            pos = pos + 1;
            if (tt(toks, pos) == "num") {
                n = tonum(tv(toks, pos));
                pos = pos + 1;
                0
            } else { 0 };
            res({ k: "arrrep", v: first.node, n: n, line: ln, col: cl }, pos + 1)        } else {
            let elems = [first.node];
            let go = true;
            if (is_punct(toks, pos, ",")) { 0; } else { go = false; 0; };
            while (go) {
                pos = pos + 1;                if (is_punct(toks, pos, "]")) {
                    go = false;
                    0
                } else {
                    let e = parse_expr(toks, pos);
                    elems = push(elems, e.node);
                    pos = e.pos;
                    go = is_punct(toks, pos, ",");
                    0
                };
            };
            if (is_punct(toks, pos, "]")) { 0; } else {
                elems = push(elems, { k: "err", msg: "unexpected '" + tv(toks, pos) + "' (expected ',' or ']')", line: tline(toks, pos), col: tcol(toks, pos) });
                0;
            };
            res({ k: "array", elems: elems, line: ln, col: cl }, pos + 1)        }
    }
};

def brace_is_map(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> bool {
    if (is_punct(toks, p + 1, "}")) {
        true
    } else {
        let k = tt(toks, p + 1);
        if (k == "id") {
            is_punct(toks, p + 2, ":")
        } else if (k == "str") {
            is_punct(toks, p + 2, ":")
        } else if (k == "kw") {
            is_punct(toks, p + 2, ":")
        } else if (k == "num") {
            is_punct(toks, p + 2, ":")
        } else {
            false
        }
    }
};

def parse_map(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    let ln = tline(toks, p);
    let cl = tcol(toks, p);
    let keys = [];
    let vals = [];
    let pos = p + 1;
    if (is_punct(toks, pos, "}")) {
        res({ k: "map", keys: keys, vals: vals, line: ln, col: cl }, pos + 1)
    } else {
        let go = true;
        while (go) {
            if (is_punct(toks, pos, "}")) {
                go = false;
                0
            } else {
                let key = tv(toks, pos);
                pos = pos + 2;                let e = parse_expr(toks, pos);
                keys = push(keys, key);
                vals = push(vals, e.node);
                pos = e.pos;
                if (is_punct(toks, pos, ",")) { pos = pos + 1; 0; } else { go = false; 0; };
                0
            };
        };
        res({ k: "map", keys: keys, vals: vals, line: ln, col: cl }, pos + 1)    }
};


def parse_type_node(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    if (is_op(toks, p, "*")) {
        let inner = parse_type_node(toks, p + 1);
        let pin = { k: "tptr", to: inner.node };
        parse_type_tail(toks, inner.pos, pin)
    } else if (is_punct(toks, p, "[")) {
        parse_type_array(toks, p)
    } else if (is_punct(toks, p, "(")) {
        parse_type_params(toks, p)
    } else if (is_punct(toks, p, "{")) {
        parse_type_record(toks, p)
    } else {
        parse_type_atom2(toks, p)
    }
};

def parse_type_array(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    let inner = parse_type_node(toks, p + 1);
    if (is_punct(toks, inner.pos, ";")) {
        let n = -1;
        let np = inner.pos + 1;
        if (tt(toks, np) == "num") {
            n = tonum(tv(toks, np));
            np = np + 1;
            0
        } else { 0 };
        parse_type_tail(toks, np + 1, { k: "tarrfix", of: inner.node, n: n })    } else {
        parse_type_tail(toks, inner.pos + 1, { k: "tarr", of: inner.node })    }
};

def parse_type_params(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    let ts = [];
    let pos = p + 1;    if (!is_punct(toks, pos, ")")) {
        let go = true;
        while (go) {
            if (is_punct(toks, pos, ")")) {
                go = false;
                0
            } else {
                let t = parse_type_node(toks, pos);
                ts = push(ts, t.node);
                pos = t.pos;
                if (is_punct(toks, pos, ",")) { pos = pos + 1; 0; } else { go = false; 0; };
                0
            };
        };
        0
    } else { 0 };
    parse_type_tparams(toks, pos + 1, ts)};

def parse_type_record(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    let fields = [];
    let pos = p + 1;    if (!is_punct(toks, pos, "}")) {
        let go = true;
        while (go) {
            if (is_punct(toks, pos, "}")) {
                go = false;
                0
            } else {
                let fname = tv(toks, pos);
                let ft = parse_type_node(toks, pos + 2);                fields = push(fields, { name: fname, typ: ft.node });
                pos = ft.pos;
                if (is_punct(toks, pos, ",")) { pos = pos + 1; 0; } else { go = false; 0; };
                0
            };
        };
        0
    } else { 0 };
    parse_type_tail(toks, pos + 1, { k: "trec", fields: fields })};

def parse_type_atom2(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    let nm = tv(toks, p);
    if (nm == "long") { parse_type_tail(toks, p + 1, { k: "tlong" }) }
    else if (nm == "int") { parse_type_tail(toks, p + 1, { k: "tlong" }) }
    else if (nm == "byte") { parse_type_tail(toks, p + 1, { k: "tbyte" }) }
    else if (nm == "bool") { parse_type_tail(toks, p + 1, { k: "tbool" }) }
    else if (nm == "str") { parse_type_tail(toks, p + 1, { k: "tstr" }) }
    else if (nm == "float") { parse_type_tail(toks, p + 1, { k: "tfloat" }) }
    else if (nm == "null") { parse_type_tail(toks, p + 1, { k: "tnull" }) }
    else { parse_type_tail(toks, p + 1, { k: "tname", name: nm }) }
};

def parse_type_tail(toks: [{ t: str, v: str, line: long, col: long }], apos: long, anode) -> { node: {k: str}, pos: long } {
    if (is_op(toks, apos, "?")) {
        parse_type_arrow(toks, apos + 1, { k: "topt", of: anode })
    } else {
        parse_type_arrow(toks, apos, anode)
    }
};

def parse_type_arrow(toks: [{ t: str, v: str, line: long, col: long }], apos: long, anode) -> { node: {k: str}, pos: long } {
    parse_type_plain(toks, apos, anode)
};

def parse_type_plain(toks: [{ t: str, v: str, line: long, col: long }], apos: long, anode) -> { node: {k: str}, pos: long } {
    if (is_op(toks, apos, "->")) {
        let rhs = parse_type_node(toks, apos + 1);
        res({ k: "tfunc", args: [anode], ret: rhs.node }, rhs.pos)
    } else {
        res(anode, apos)
    }
};

def parse_type_tparams(toks: [{ t: str, v: str, line: long, col: long }], apos: long, tlist: [{k: str}]) -> { node: {k: str}, pos: long } {
    let ts0 = tlist;
    if (is_op(toks, apos, "->")) {
        let rhs = parse_type_node(toks, apos + 1);
        res({ k: "tfunc", args: ts0, ret: rhs.node }, rhs.pos)
    } else if (len(ts0) == 1) {
        res(ts0[0], apos)
    } else {
        res({ k: "tparams", ts: ts0 }, apos)
    }
};

def parse_type_atom(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> long {
    let r = parse_type_node(toks, p);
    r.pos
};

def parse_type(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> long {
    let pos = parse_type_atom(toks, p);
    if (is_op(toks, pos, "->")) {
        pos = parse_type(toks, pos + 1);
        0
    } else { 0 };
    pos
};


def parse_func(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    let ln = tline(toks, p);
    let cl = tcol(toks, p);
    let pos = p + 1;    let fname = "";
    if (!is_punct(toks, pos, "(")) {
        fname = tv(toks, pos);
        pos = pos + 1;
        0
    } else { 0 };
    pos = pos + 1;    let names = [];
    let ptypes = [];
    if (!is_punct(toks, pos, ")")) {
        let go = true;
        while (go) {
            let nm = tv(toks, pos);
            names = push(names, nm);
            pos = pos + 1;            let pt = { k: "tnone" };
            if (is_punct(toks, pos, ":")) {
                let tr = parse_type_node(toks, pos + 1);
                pt = tr.node;
                pos = tr.pos;
                0
            } else { 0 };
            ptypes = push(ptypes, pt);
            if (is_punct(toks, pos, ",")) {
                pos = pos + 1;
                0
            } else {
                go = false;
                0
            };
            0
        };
        0
    } else { 0 };
    pos = pos + 1;    let ret = { k: "tnone" };
    if (is_op(toks, pos, "->")) {
        let rr = parse_type_node(toks, pos + 1);
        ret = rr.node;
        pos = rr.pos;
        0
    } else { 0 };
    let body = parse_block(toks, pos);
    let func = { k: "func", params: names, ptypes: ptypes, ret: ret, body: body.node, line: ln, col: cl };
    if (fname == "") {
        res(func, body.pos)
    } else {
        res({ k: "decl", kind: "def", name: fname, v: func, line: ln, col: cl }, body.pos)
    }
};


def parse_block(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    let ln = tline(toks, p);
    let cl = tcol(toks, p);
    let pos = p + 1;    let stmts: [{k: str}] = [];
    let go = true;
    while (go) {
        if (is_punct(toks, pos, "}")) {
            go = false;
            0
        } else if (tt(toks, pos) == "eof") {
            go = false;
            0
        } else {
            let s = parse_stmt(toks, pos);
            stmts = push(stmts, s.node);
            pos = s.pos;
            if (is_punct(toks, pos, ";")) { pos = pos + 1; 0; } else { 0 };
            0
        };
    };
    res({ k: "block", stmts: stmts, line: ln, col: cl }, pos + 1)};


def parse_stmt(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    if (is_kw(toks, p, "let")) { parse_decl(toks, p) }
    else if (is_kw(toks, p, "const")) { parse_decl(toks, p) }
    else if (is_kw(toks, p, "return")) {
        let e = parse_expr(toks, p + 1);
        res({ k: "ret", e: e.node, line: tline(toks, p), col: tcol(toks, p) }, e.pos)
    } else {
        let e = parse_expr(toks, p);
        if (is_op(toks, e.pos, "=")) {
            parse_stmt_assign(toks, p, e.node, e.pos)
        } else {
            e
        }
    }
};

def parse_stmt_assign(toks: [{ t: str, v: str, line: long, col: long }], p: long, tgt: {k: str}, epos: long) -> { node: {k: str}, pos: long } {
    if (tgt.k == "index") {
        parse_stmt_idxassign(toks, p, tgt, epos)
    } else {
        parse_stmt_rest(toks, p, tgt, epos)
    }
};

def parse_stmt_idxassign(toks: [{ t: str, v: str, line: long, col: long }], p: long, tgt: {k: str}, epos: long) -> { node: {k: str}, pos: long } {
    parse_stmt_idxassign_go(toks, p, tgt, epos)
};

def parse_stmt_idxassign_go(toks: [{ t: str, v: str, line: long, col: long }], p: long, itgt, epos: long) -> { node: {k: str}, pos: long } {
    let rhs = parse_expr(toks, epos + 1);
    res({ k: "idxassign", arr: itgt.arr, idx: itgt.idx, v: rhs.node, line: tline(toks, p), col: tcol(toks, p) }, rhs.pos)
};



def parse_stmt_rest(toks: [{ t: str, v: str, line: long, col: long }], p: long, tgt: {k: str}, epos: long) -> { node: {k: str}, pos: long } {
    if (tgt.k == "dot") {
        parse_stmt_dotassign(toks, p, tgt, epos)
    } else {
        parse_stmt_simple(toks, p, tgt, epos)
    }
};

def parse_stmt_dotassign(toks: [{ t: str, v: str, line: long, col: long }], p: long, tgt: {k: str}, epos: long) -> { node: {k: str}, pos: long } {
    parse_stmt_dotassign_go(toks, p, tgt, epos)
};

def parse_stmt_dotassign_go(toks: [{ t: str, v: str, line: long, col: long }], p: long, dtgt, epos: long) -> { node: {k: str}, pos: long } {
    let rhs = parse_expr(toks, epos + 1);
    res({ k: "dotassign", obj: dtgt.obj, key: dtgt.key, v: rhs.node, line: tline(toks, p), col: tcol(toks, p) }, rhs.pos)
};



def parse_stmt_simple(toks: [{ t: str, v: str, line: long, col: long }], p: long, tgt: {k: str}, epos: long) -> { node: {k: str}, pos: long } {
    if (tgt.k == "deref") {
        parse_stmt_store(toks, p, tgt, epos)
    } else {
        parse_stmt_plainassign(toks, p, tgt, epos)
    }
};

def parse_stmt_store(toks: [{ t: str, v: str, line: long, col: long }], p: long, stgt, epos: long) -> { node: {k: str}, pos: long } {
    let rhs = parse_expr(toks, epos + 1);
    res({ k: "store", p: stgt.e, v: rhs.node, line: tline(toks, p), col: tcol(toks, p) }, rhs.pos)
};

def parse_stmt_plainassign(toks: [{ t: str, v: str, line: long, col: long }], p: long, atgt, epos: long) -> { node: {k: str}, pos: long } {
    let rhs = parse_expr(toks, epos + 1);
    res({ k: "assign", name: atgt.v, v: rhs.node, line: tline(toks, p), col: tcol(toks, p) }, rhs.pos)
};

def parse_decl(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    let kind = tv(toks, p);
    let name = tv(toks, p + 1);
    let ln = tline(toks, p);
    let cl = tcol(toks, p);
    let pos = p + 2;
    let typ = { k: "tnone" };
    if (is_punct(toks, pos, ":")) {
        let tr = parse_type_node(toks, pos + 1);
        typ = tr.node;
        pos = tr.pos;
        0
    } else { 0 };
    pos = pos + 1;
    let e = parse_expr(toks, pos);
    res({ k: "decl", kind: kind, name: name, typ: typ, v: e.node, line: ln, col: cl }, e.pos)
};


def parse_if(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    let ln = tline(toks, p);
    let cl = tcol(toks, p);
    let cond = parse_expr(toks, p + 1);
    let then_b = parse_block(toks, cond.pos);
    let pos = then_b.pos;
    let else_b = { k: "null" };
    let has_else = false;
    if (is_kw(toks, pos, "else")) {
        if (is_kw(toks, pos + 1, "if")) {
            let ei = parse_if(toks, pos + 1);
            else_b = ei.node;
            pos = ei.pos;
            0
        } else {
            let eb = parse_block(toks, pos + 1);
            else_b = eb.node;
            pos = eb.pos;
            0
        };
        has_else = true;
        0
    } else { 0 };
    res({ k: "if", cond: cond.node, then: then_b.node, els: else_b, has_else: has_else, line: ln, col: cl }, pos)
};

def parse_while(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    let cond = parse_expr(toks, p + 1);
    let body = parse_block(toks, cond.pos);
    res({ k: "while", cond: cond.node, body: body.node, line: tline(toks, p), col: tcol(toks, p) }, body.pos)
};

def parse_foreach(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    let name = tv(toks, p + 2);
    let it = parse_expr(toks, p + 4);    let body = parse_block(toks, it.pos + 1);    res({ k: "foreach", name: name, iter: it.node, body: body.node, line: tline(toks, p), col: tcol(toks, p) }, body.pos)
};

def parse_for_or_range(toks: [{ t: str, v: str, line: long, col: long }], p: long) -> { node: {k: str}, pos: long } {
    let ln = tline(toks, p);
    let cl = tcol(toks, p);
    if (is_kw(toks, p + 2, "in")) {
        let name = tv(toks, p + 1);
        let lo = parse_expr(toks, p + 3);
        let hi = parse_expr(toks, lo.pos + 1);
        let body = parse_block(toks, hi.pos);
        res({ k: "forrange", name: name, lo: lo.node, hi: hi.node, body: body.node, line: ln, col: cl }, body.pos)
    } else {
        let pos = p + 2;        let init = { k: "null" };
        if (!is_punct(toks, pos, ";")) {
            let ir = parse_stmt(toks, pos);
            init = ir.node;
            pos = ir.pos;
            0
        } else { 0 };
        pos = pos + 1;        let cond = parse_expr(toks, pos);
        pos = cond.pos + 1;        let step = { k: "null" };
        if (!is_punct(toks, pos, ")")) {
            let sr = parse_stmt(toks, pos);
            step = sr.node;
            pos = sr.pos;
            0
        } else { 0 };
        pos = pos + 1;        let body = parse_block(toks, pos);
        res({ k: "for", init: init, cond: cond.node, step: step, body: body.node, line: ln, col: cl }, body.pos)
    }
};


def parse_program(toks: [{ t: str, v: str, line: long, col: long }]) -> {k: str} {
    let stmts: [{k: str}] = [];
    let pos = 0;
    while (tt(toks, pos) != "eof") {
        let before = pos;
        let s = parse_stmt(toks, pos);
        stmts = push(stmts, s.node);
        pos = s.pos;
        if (is_punct(toks, pos, ";")) { pos = pos + 1; 0; } else { 0 };
        if (pos == before) {
            pos = pos + 1;
            0
        } else { 0 };
        0
    };
    { k: "block", stmts: stmts, line: 1, col: 1 }
};

export { parse_program };
