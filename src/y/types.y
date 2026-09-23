def err_at(msg: str, line: long, col: long) -> { msg: str, line: long, col: long } {
    { msg: msg, line: line, col: col }
};


def t_unk() -> {k: str} { { k: "tunk" } };
def t_null() -> {k: str} { { k: "tnull" } };

def teq(a, b) -> bool {
    let ak: str = a.k;
    let bk: str = b.k;
    if (ak == "tunk") { true }
    else if (bk == "tunk") { true }
    else if (ak != bk) { false }
    else if (ak == "tnone") { true }
    else if (bk == "tnone") { true }
    else if (ak == "tname") { true }
    else if (bk == "tname") { true }
    else if (ak == "tparams") { true }
    else if (bk == "tparams") { true }
    else if (ak == "tptr") { teq(a.to, b.to) }
    else if (ak == "tarr") { teq(a.of, b.of) }
    else if (ak == "tarrfix") {
        if (a.n == b.n) { teq(a.of, b.of) } else { false }
    } else if (a.k == "topt") { teq(a.of, b.of) }
    else if (a.k == "trec") {
        let af = a.fields;
        let bf = b.fields;
        if (len(af) != len(bf)) {
            if (single_k(af)) { true }
            else if (single_k(bf)) { true }
            else { false }
        } else {
            let ok = true;
            let i = 0;
            while (ok) {
                if (i < len(af)) {
                    let fa = af[i];
                    let fb = bf[i];
                    let an: str = fa.name;
                    let bn: str = fb.name;
                    if (an != bn) {
                        ok = false;
                    } else {
                        ok = teq(fa.typ, fb.typ);
                    };
                    i = i + 1;
                    0
                } else { ok = false; 0 };
                0
            };
            teq_fields(af, bf, 0)
        }
    } else if (ak == "tfunc") {
        if (len(a.args) != len(b.args)) { false } else {
            let ok = teq(a.ret, b.ret);
            let aa = a.args;
            let bb = b.args;
            let i = 0;
            while (ok) {
                if (i < len(aa)) {
                    ok = teq(aa[i], bb[i]);
                    i = i + 1;
                    0
                } else { ok = false; 0 };
                0
            };
            teq_list(aa, bb, 0)
        }
    } else { true }
};

def teq_fields(af, bf, i: long) -> bool {
    if (i >= len(af)) { true }
    else {
        let fa = af[i];
        let fb = bf[i];
        let an: str = fa.name;
        let bn: str = fb.name;
        if (an != bn) { false }
        else if (teq(fa.typ, fb.typ)) { teq_fields(af, bf, i + 1) }
        else { false }
    }
};

def teq_list(aa, bb, i: long) -> bool {
    if (i >= len(aa)) { true }
    else if (teq(aa[i], bb[i])) { teq_list(aa, bb, i + 1) }
    else { false }
};

def unk_shape() -> { k: str, fields: [{ name: str, typ: { k: str } }] } {
    { k: "trec", fields: [{ name: "k", typ: { k: "tstr" } }] }
};

def single_k(fs) -> bool {
    if (len(fs) != 1) { false }
    else { fs[0].name == "k" }
};

def trec_field_type(rec, key: str) -> { k: str } {
    let found = { k: "tnone" };
    if (rec.k == "trec") {
        let fs = rec.fields;
        let i = 0;
        while (i < len(fs)) {
            let f = fs[i];
            if (f.name == key) {
                found = f.typ;
                0
            } else { 0; };
            i = i + 1;
        };
    };
    found
};

def tstr_go(t) -> str {
    if (t.k == "tlong") { "long" }
    else if (t.k == "tbyte") { "byte" }
    else if (t.k == "tfloat") { "float" }
    else if (t.k == "tbool") { "bool" }
    else if (t.k == "tstr") { "str" }
    else if (t.k == "tnull") { "null" }
    else if (t.k == "tvoid") { "void" }
    else if (t.k == "tunk") { "<error>" }
    else if (t.k == "tnone") { "<missing annotation>" }
    else if (t.k == "tname") { t.name }
    else if (t.k == "tptr") { "*" + tstr_go(t.to) }
    else if (t.k == "tarr") { "[" + tstr_go(t.of) + "]" }
    else if (t.k == "tarrfix") { "[" + tstr_go(t.of) + "; " + tostring(t.n) + "]" }
    else if (t.k == "topt") { tstr_go(t.of) + "?" }
    else if (t.k == "trec") {
        let parts = [];
        let fs = t.fields;
        let i = 0;
        while (i < len(fs)) {
            let f = fs[i];
            parts = push(parts, f.name + ": " + tstr_go(f.typ));
            i = i + 1;
        };
        "{ " + join(parts, ", ") + " }"
    }
    else if (t.k == "tfunc") {
        let parts = [];
        let ta = t.args;
        let i = 0;
        while (i < len(ta)) {
            parts = push(parts, tstr_go(ta[i]));
            i = i + 1;
        };
        "(" + join(parts, ", ") + ") -> " + tstr_go(t.ret)
    } else { "<" + t.k + ">" }
};

def tstr(t) -> str { tstr_go(t) };

def num_is_float(s: str) -> bool {
    let radix = false;
    if (len(s) > 2) {
        let p = substr(s, 0, 2);
        if (p == "0x") { radix = true; 0; } else { 0; };
        if (p == "0X") { radix = true; 0; } else { 0; };
        if (p == "0b") { radix = true; 0; } else { 0; };
        if (p == "0B") { radix = true; 0; } else { 0; };
        0
    } else { 0; };
    if (radix) { false } else {
        let f = false;
        if (index_of(s, ".") >= 0) { f = true; 0; } else { 0; };
        if (index_of(s, "e") >= 0) { f = true; 0; } else { 0; };
        if (index_of(s, "E") >= 0) { f = true; 0; } else { 0; };
        f
    }
};

def tdisp(t) -> str {
    if (t.k == "trec") {
        let parts = [];
        let fs = t.fields;
        let i = 0;
        while (i < len(fs)) {
            let f = fs[i];
            parts = push(parts, f.name + ": " + tdisp(f.typ));
            i = i + 1;
        };
        "{" + join(parts, ", ") + "}"
    } else if (t.k == "tfunc") {
        let parts = [];
        let ta = t.args;
        let i = 0;
        while (i < len(ta)) {
            parts = push(parts, tdisp(ta[i]));
            i = i + 1;
        };
        "(" + join(parts, ", ") + ")->" + tdisp(t.ret)
    } else if (t.k == "tarr") {
        "[" + tdisp(t.of) + "]"
    } else if (t.k == "tarrfix") {
        "[" + tdisp(t.of) + "; " + tostring(t.n) + "]"
    } else if (t.k == "tptr") {
        "*" + tdisp(t.to)
    } else if (t.k == "topt") {
        tdisp(t.of) + "?"
    } else {
        tstr_go(t)
    }
};

def is_value_type(t) -> bool {
    if (t.k == "tlong") { true }
    else if (t.k == "tbyte") { true }
    else if (t.k == "tfloat") { true }
    else if (t.k == "tbool") { true }
    else if (t.k == "tstr") { true }
    else if (t.k == "tnull") { true }
    else if (t.k == "tptr") { true }
    else if (t.k == "tunk") { true }
    else if (t.k == "tnone") { true }
    else if (t.k == "tname") { true }
    else if (t.k == "tparams") { true }
    else if (t.k == "tfunc") { true }
    else if (t.k == "tarr") { true }
    else if (t.k == "tarrfix") { true }
    else if (t.k == "topt") { true }
    else { t.k == "trec" }
};

def tdisp_fnval(t) -> str {
    let parts = [];
    let ta = t.args;
    let i = 0;
    while (i < len(ta)) {
        parts = push(parts, tdisp(ta[i]));
        i = i + 1;
    };
    "(" + join(parts, ", ") + ")->(" + tdisp(t.ret) + ")"
};


def lookup(bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], name: str) -> { typ: { k: str }, kind: str, fdepth: long } {
    let i = 0;
    let found_typ = { k: "tnone" };
    let found_kind = "";
    let found_fd = 0;
    while (i < len(bindings)) {
        let e = bindings[i];
        if (e.name == name) {
            found_typ = e.typ;
            found_kind = e.kind;
            found_fd = e.fdepth;
            0
        } else { 0 };
        i = i + 1;
        0
    };
    { typ: found_typ, kind: found_kind, fdepth: found_fd }
};

def st_bind(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, name: str, typ, kind: str) -> { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } {
    let bindings = push(st.bindings, { name: name, typ: typ, kind: kind, fdepth: st.fdepth });
    { bindings: bindings, errors: st.errors, ret: st.ret, self: st.self, fdepth: st.fdepth }
};


def st_errors(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, errs: [{ msg: str, line: long, col: long }]) -> { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } { { bindings: st.bindings, errors: errs, ret: st.ret, self: st.self, fdepth: st.fdepth } };
def st_self(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, selfv) -> { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } { { bindings: st.bindings, errors: st.errors, ret: st.ret, self: selfv, fdepth: st.fdepth } };
def st_ret(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, ret) -> { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } { { bindings: st.bindings, errors: st.errors, ret: ret, self: st.self, fdepth: st.fdepth } };

def fail(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, msg: str, line: long, col: long) -> { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } {
    st_errors(st, push(st.errors, err_at(msg, line, col)))
};

def disp(name: str) -> str {
    let i = index_of(name, "$");
    if (i < 0) { name } else { substr(name, 0, i) }
};

def check_visible(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, got, name: str, line: long, col: long) -> { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } {
    let unused = name;
    let unused2 = line;
    let unused3 = col;
    let unused4 = got;
    st
};

def expect_type(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, got, want, what: str, line: long, col: long) -> { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } {
    if (tcompat(got, want)) { st } else {
        fail(st, what + ": expected " + tstr(want) + ", got " + tstr(got), line, col)
    }
};

def typeof_arith(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, op: str, lt, rt, line: long, col: long) -> { typ: { k: str }, st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } } {
    if (op == "+") {
        if (lt.k == "tstr") {
            if (rt.k == "tstr") { { typ: { k: "tstr" }, st: st } }
            else if (rt.k == "tunk") { { typ: { k: "tstr" }, st: st } }
            else if (rt.k == "tlong") { { typ: { k: "tstr" }, st: st } }
            else if (rt.k == "tbyte") { { typ: { k: "tstr" }, st: st } }
            else if (rt.k == "tfloat") { { typ: { k: "tstr" }, st: st } }
            else if (rt.k == "tbool") { { typ: { k: "tstr" }, st: st } }
            else { typeof_arith_long(st, op, lt, rt, line, col) }
        } else if (lt.k == "tunk") {
            if (rt.k == "tstr") { { typ: { k: "tstr" }, st: st } }
            else { typeof_arith_long(st, op, lt, rt, line, col) }
        } else if (lt.k == "tlong") {
            if (rt.k == "tstr") { { typ: { k: "tstr" }, st: st } }
            else { typeof_arith_long(st, op, lt, rt, line, col) }
        } else if (lt.k == "tbyte") {
            if (rt.k == "tstr") { { typ: { k: "tstr" }, st: st } }
            else { typeof_arith_long(st, op, lt, rt, line, col) }
        } else if (lt.k == "tfloat") {
            if (rt.k == "tstr") { { typ: { k: "tstr" }, st: st } }
            else { typeof_arith_long(st, op, lt, rt, line, col) }
        } else if (lt.k == "tbool") {
            if (rt.k == "tstr") { { typ: { k: "tstr" }, st: st } }
            else { typeof_arith_long(st, op, lt, rt, line, col) }
        } else { typeof_arith_long(st, op, lt, rt, line, col) }
    } else { typeof_arith_long(st, op, lt, rt, line, col) }
};

def typeof_arith_long(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, op: str, lt, rt, line: long, col: long) -> { typ: { k: str }, st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } } {
    if (lt.k == "tfloat" || rt.k == "tfloat") {
        st = expect_type(st, lt, { k: "tfloat" }, "'" + op + "' left operand", line, col);
        st = expect_type(st, rt, { k: "tfloat" }, "'" + op + "' right operand", line, col);
        { typ: { k: "tfloat" }, st: st }
    } else {
        st = expect_type(st, lt, { k: "tlong" }, "'" + op + "' left operand", line, col);
        st = expect_type(st, rt, { k: "tlong" }, "'" + op + "' right operand", line, col);
        { typ: { k: "tlong" }, st: st }
    }
};

def typeof_cmp(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, op: str, lt, rt, line: long, col: long) -> { typ: { k: str }, st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } } {
    if (lt.k == "tstr") {
        st = expect_type(st, rt, { k: "tstr" }, "'" + op + "' right operand", line, col);
        { typ: { k: "tbool" }, st: st }
    } else if (lt.k == "tfloat" || rt.k == "tfloat") {
        st = expect_type(st, lt, { k: "tfloat" }, "'" + op + "' left operand", line, col);
        st = expect_type(st, rt, { k: "tfloat" }, "'" + op + "' right operand", line, col);
        { typ: { k: "tbool" }, st: st }
    } else {
        st = expect_type(st, lt, { k: "tlong" }, "'" + op + "' left operand", line, col);
        st = expect_type(st, rt, { k: "tlong" }, "'" + op + "' right operand", line, col);
        { typ: { k: "tbool" }, st: st }
    }
};

def is_num_kind(t) -> bool {
    if (t.k == "tlong") { true }
    else if (t.k == "tbyte") { true }
    else if (t.k == "tfloat") { true }
    else { false }
};

def num_eq_ok(lt, rt) -> bool {
    if (is_num_kind(lt)) { is_num_kind(rt) } else { false }
};

def typeof_eq(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, op: str, lt, rt, line: long, col: long) -> { typ: { k: str }, st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } } {
    if (teq(lt, rt)) { { typ: { k: "tbool" }, st: st } }
    else if (num_eq_ok(lt, rt)) {
        { typ: { k: "tbool" }, st: st }
    }
    else if (lt.k == "tstr") {
        if (rt.k == "tstr") { { typ: { k: "tbool" }, st: st } }
        else if (rt.k == "tunk") { { typ: { k: "tbool" }, st: st } }
        else if (rt.k == "tnull") { { typ: { k: "tbool" }, st: st } }
        else {
            st = fail(st, "'" + op + "' compares " + tstr(lt) + " with " + tstr(rt), line, col);
            { typ: { k: "tbool" }, st: st }
        }
    } else if (lt.k == "tunk") {
        { typ: { k: "tbool" }, st: st }
    } else if (lt.k == "tnull") {
        if (rt.k == "tstr") { { typ: { k: "tbool" }, st: st } }
        else {
            st = fail(st, "'" + op + "' compares " + tstr(lt) + " with " + tstr(rt), line, col);
            { typ: { k: "tbool" }, st: st }
        }
    } else if (lt.k == "topt") {
        if (rt.k == "tnull") { { typ: { k: "tbool" }, st: st } }
        else if (rt.k == "tunk") { { typ: { k: "tbool" }, st: st } }
        else if (teq(lt, rt)) { { typ: { k: "tbool" }, st: st } }
        else {
            st = fail(st, "'" + op + "' compares " + tstr(lt) + " with " + tstr(rt), line, col);
            { typ: { k: "tbool" }, st: st }
        }
    } else if (rt.k == "topt") {
        if (lt.k == "tnull") { { typ: { k: "tbool" }, st: st } }
        else if (lt.k == "tunk") { { typ: { k: "tbool" }, st: st } }
        else {
            st = fail(st, "'" + op + "' compares " + tstr(lt) + " with " + tstr(rt), line, col);
            { typ: { k: "tbool" }, st: st }
        }
    } else {
        st = fail(st, "'" + op + "' compares " + tstr(lt) + " with " + tstr(rt), line, col);
        { typ: { k: "tbool" }, st: st }
    }
};

def typeof_logic(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, op: str, lt, rt, line: long, col: long) -> { typ: { k: str }, st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } } {
    { typ: { k: "tbool" }, st: st }
};

def tcompat(got, want) -> bool {
    if (teq(got, want)) { true }
    else if (got.k == "tnone") { true }
    else if (want.k == "tnone") { true }
    else if (got.k == "tname") { true }
    else if (want.k == "tname") { true }
    else if (got.k == "tparams") { true }
    else if (want.k == "tparams") { true }
    else if (got.k == "trec") {
        if (want.k == "trec") { trec_compat(got, want) } else { false }
    } else if (want.k == "trec") {
        if (got.k == "tstr") { false } else { true }
    }
    else if (got.k == "tstr") {
        if (want.k == "tptr") { true } else { false }
    } else if (got.k == "tlong") {
        if (want.k == "tfloat") { true }
        else if (want.k == "tbyte") { true }
        else { false }
    } else if (got.k == "tbyte") {
        if (want.k == "tlong") { true }
        else if (want.k == "tfloat") { true }
        else { false }
    } else { false }
};

def arr_lit_adopts(got, want) -> bool {
    if (got.k == "tarr") { arr_lit_adopts_go(got, want) }
    else if (got.k == "tarrfix") { arr_lit_adopts_go(got, want) }
    else { false }
};

def arr_lit_adopts_go(got, want) -> bool {
    if (want.k == "tarr") { tcompat(got.of, want.of) }
    else if (want.k == "tarrfix") {
        if (got.k == "tarrfix") {
            if (got.n == want.n) { tcompat(got.of, want.of) } else { false }
        } else { tcompat(got.of, want.of) }
    }
    else { false }
};

def trec_compat(got, want) -> bool {
    let wfs = want.fields;
    let gfs = got.fields;
    trec_compat_go(gfs, wfs, 0)
};

def trec_compat_go(gfs, wfs, i: long) -> bool {
    if (i >= len(wfs)) { true }
    else {
        let wf = wfs[i];
        if (trec_has(gfs, wf.name, wf.typ)) { trec_compat_go(gfs, wfs, i + 1) }
        else { false }
    }
};

def trec_has(gfs, name: str, typ) -> bool {
    let i = 0;
    let found = false;
    while (i < len(gfs)) {
        let gf = gfs[i];
        if (gf.name == name) {
            if (tcompat(gf.typ, typ)) { found = true; 0; } else { 0; };
            0
        } else { 0 };
        i = i + 1;
    };
    found
};

def typeof_expr(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, node) -> { typ: { k: str }, st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } } {
    let k = node.k;
    if (k == "num") {
        if (num_is_float(node.v)) {
            { typ: { k: "tfloat" }, st: st }
        } else {
            { typ: { k: "tlong" }, st: st }
        }
    } else if (k == "str") {
        { typ: { k: "tstr" }, st: st }
    } else if (k == "err") {
        st = fail(st, node.msg, node.line, node.col);
        { typ: t_unk(), st: st }
    } else if (k == "bool") {
        { typ: { k: "tbool" }, st: st }
    } else if (k == "null") {
        { typ: { k: "topt", of: t_unk() }, st: st }
    } else if (k == "id") {
        if (node.v == "self") {
            if (st.self.k == "tnone") {
                st = fail(st, "'self' outside of a function", node.line, node.col);
                { typ: t_unk(), st: st }
            } else {
                { typ: st.self, st: st }
            }
        } else {
            let got = lookup(st.bindings, node.v);
            if (got.kind == "") {
                if (node.v == "none") {
                    { typ: { k: "topt", of: t_unk() }, st: st }
                } else {
                    st = fail(st, "undefined variable '" + node.v + "'", node.line, node.col);
                    { typ: t_unk(), st: st }
                }
            } else {
                st = check_visible(st, got, node.v, node.line, node.col);
                { typ: got.typ, st: st }
            }
        }
    } else if (k == "un") {
        let r = typeof_expr(st, node.e);
        st = r.st;
        if (node.op == "-") {
            if (r.typ.k == "tfloat") {
                { typ: { k: "tfloat" }, st: st }
            } else {
                st = expect_type(st, r.typ, { k: "tlong" }, "unary '-'", node.line, node.col);
                { typ: { k: "tlong" }, st: st }
            }
        } else {
            st = expect_type(st, r.typ, { k: "tbool" }, "unary '!'", node.line, node.col);
            { typ: { k: "tbool" }, st: st }
        }
    } else if (k == "addr") {
        if (node.e.k == "id") {
            if (node.e.v != "self") {
                let got = lookup(st.bindings, node.e.v);
                if (got.kind == "") {
                    st = fail(st, "undefined variable '" + node.e.v + "'", node.line, node.col);
                    { typ: t_unk(), st: st }
            } else if (got.kind == "func" || got.kind == "intrinsic") {
                st = fail(st, "cannot take the address of function '" + node.e.v + "'", node.line, node.col);
                { typ: t_unk(), st: st }
            } else if (got.typ.k == "tarr") {
                st = fail(st, "cannot take the address of a whole heap array (use &" + disp(node.e.v) + "[i] for elements)", node.line, node.col);
                { typ: t_unk(), st: st }
            } else if (got.typ.k == "tarrfix") {
                st = check_visible(st, got, node.e.v, node.line, node.col);
                { typ: { k: "tptr", to: got.typ.of }, st: st }
            } else {
                st = check_visible(st, got, node.e.v, node.line, node.col);
                { typ: { k: "tptr", to: got.typ }, st: st }
            }
            } else {
                st = fail(st, "'&' needs a plain variable (only locals/params have addresses)", node.line, node.col);
                { typ: t_unk(), st: st }
            }
        } else if (node.e.k == "index") {
            let ix = node.e.idx;
            let arr = node.e.arr;
            if (arr.k == "id") {
                let got = lookup(st.bindings, arr.v);
                if (got.kind == "") {
                    st = fail(st, "undefined variable '" + arr.v + "'", node.line, node.col);
                    { typ: t_unk(), st: st }
                } else if (got.typ.k == "tarrfix" || got.typ.k == "tarr") {
                    st = check_visible(st, got, arr.v, node.line, node.col);
                    let r = typeof_expr(st, ix);
                    st = r.st;
                    st = expect_type(st, r.typ, { k: "tlong" }, "array index", node.line, node.col);
                    { typ: { k: "tptr", to: got.typ.of }, st: st }
                } else {
                    st = fail(st, "cannot index " + tstr(got.typ) + " (only arrays)", node.line, node.col);
                    { typ: t_unk(), st: st }
                }
            } else {
                st = fail(st, "'&' needs a plain variable element (&a[i])", node.line, node.col);
                { typ: t_unk(), st: st }
            }
        } else {
            st = fail(st, "'&' needs a plain variable (only locals/params have addresses)", node.line, node.col);
            { typ: t_unk(), st: st }
        }
    } else if (k == "deref") {
        let r = typeof_expr(st, node.e);
        st = r.st;
        if (r.typ.k == "tptr") {
            { typ: r.typ.to, st: st }
        } else if (r.typ.k == "tunk") {
            { typ: t_unk(), st: st }
        } else {
            st = fail(st, "cannot dereference " + tstr(r.typ) + " (need *T)", node.line, node.col);
            { typ: t_unk(), st: st }
        }
    } else if (k == "bin") {
        let l = typeof_expr(st, node.l);
        let r = typeof_expr(l.st, node.r);
        st = r.st;
        let op = node.op;
        if (op == "+") { typeof_arith(st, op, l.typ, r.typ, node.line, node.col) }
        else if (op == "-") { typeof_arith(st, op, l.typ, r.typ, node.line, node.col) }
        else if (op == "*") { typeof_arith(st, op, l.typ, r.typ, node.line, node.col) }
        else if (op == "/") { typeof_arith(st, op, l.typ, r.typ, node.line, node.col) }
        else if (op == "%") { typeof_arith(st, op, l.typ, r.typ, node.line, node.col) }
        else if (op == "<") { typeof_cmp(st, op, l.typ, r.typ, node.line, node.col) }
        else if (op == ">") { typeof_cmp(st, op, l.typ, r.typ, node.line, node.col) }
        else if (op == "<=") { typeof_cmp(st, op, l.typ, r.typ, node.line, node.col) }
        else if (op == ">=") { typeof_cmp(st, op, l.typ, r.typ, node.line, node.col) }
        else if (op == "==") { typeof_eq(st, op, l.typ, r.typ, node.line, node.col) }
        else if (op == "!=") { typeof_eq(st, op, l.typ, r.typ, node.line, node.col) }
        else if (op == "&&") { typeof_logic(st, op, l.typ, r.typ, node.line, node.col) }
        else if (op == "||") { typeof_logic(st, op, l.typ, r.typ, node.line, node.col) }
        else {
            st = fail(st, "operator '" + op + "' is unsupported in native mode", node.line, node.col);
            { typ: t_unk(), st: st }
        }
    } else if (k == "call") {
        typeof_call(st, node)
    } else if (k == "if") {
        let c = typeof_expr(st, node.cond);
        st = expect_type(c.st, c.typ, { k: "tbool" }, "'if' condition", node.line, node.col);
        let t = typeof_expr(st, node.then);
        st = t.st;
        if (node.has_else) {
            let e = typeof_expr(st, node.els);
            st = e.st;
            if (!teq(t.typ, e.typ)) {
                let tk: str = t.typ.k;
                let ek: str = e.typ.k;
                if (tk == "tvoid" || tk == "tnull" || ek == "tvoid" || ek == "tnull") {
                    0
                } else {
                    st = fail(st, "'if' branches disagree: " + tstr(t.typ) + " vs " + tstr(e.typ), node.line, node.col);
                    0
                };
                0
            } else { 0; };
            { typ: t.typ, st: st }
        } else {
            { typ: { k: "tvoid" }, st: st }
        }
    } else if (k == "while") {
        let c = typeof_expr(st, node.cond);
        st = expect_type(c.st, c.typ, { k: "tbool" }, "'while' condition", node.line, node.col);
        let b = typeof_block(st, node.body);
        { typ: { k: "tvoid" }, st: b.st }
    } else if (k == "for") {
        let fi = typeof_expr(st, node.init);
        st = fi.st;
        let fc = typeof_expr(st, node.cond);
        st = expect_type(fc.st, fc.typ, { k: "tbool" }, "'for' condition", node.line, node.col);
        let fb = typeof_block(st, node.body);
        st = fb.st;
        let fs = typeof_expr(st, node.step);
        { typ: { k: "tvoid" }, st: fs.st }
    } else if (k == "foreach") {
        let fe = typeof_expr(st, node.iter);
        st = fe.st;
        let elt = t_unk();
        if (fe.typ.k == "tarr") { elt = fe.typ.of; 0; }
        else if (fe.typ.k == "tarrfix") { elt = fe.typ.of; 0; }
        else if (fe.typ.k == "tunk") { 0; }
        else {
            st = fail(st, "'foreach' needs an array, got " + tstr(fe.typ), node.line, node.col);
            0
        };
        st = st_bind(st, node.name, elt, "local");
        let fbb = typeof_block(st, node.body);
        { typ: { k: "tvoid" }, st: fbb.st }
    } else if (k == "forrange") {
        let rl = typeof_expr(st, node.lo);
        st = expect_type(rl.st, rl.typ, { k: "tlong" }, "'for' range start", node.line, node.col);
        let rh = typeof_expr(st, node.hi);
        st = expect_type(rh.st, rh.typ, { k: "tlong" }, "'for' range end", node.line, node.col);
        st = st_bind(st, node.name, { k: "tlong" }, "local");
        let rb = typeof_block(st, node.body);
        { typ: { k: "tvoid" }, st: rb.st }
    } else if (k == "block") {
        typeof_block(st, node)
    } else if (k == "decl") {
        typeof_decl(st, node)
    } else if (k == "assign") {
        let r = typeof_expr(st, node.v);
        st = r.st;
        let got = lookup(st.bindings, node.name);
        if (got.kind == "") {
            st = fail(st, "undefined variable '" + disp(node.name) + "'", node.line, node.col);
            { typ: t_unk(), st: st }
        } else if (got.kind == "func" || got.kind == "intrinsic") {
            st = fail(st, "cannot assign to function '" + disp(node.name) + "'", node.line, node.col);
            { typ: t_unk(), st: st }
        } else if (got.typ.k == "tarrfix") {
            st = check_visible(st, got, node.name, node.line, node.col);
            st = expect_type(st, r.typ, got.typ, "assignment to '" + disp(node.name) + "'", node.line, node.col);
            { typ: got.typ, st: st }
        } else {
            st = check_visible(st, got, node.name, node.line, node.col);
            st = expect_type(st, r.typ, got.typ, "assignment to '" + disp(node.name) + "'", node.line, node.col);
            { typ: got.typ, st: st }
        }
    } else if (k == "store") {
        let p = typeof_expr(st, node.p);
        let v = typeof_expr(p.st, node.v);
        st = v.st;
        if (p.typ.k == "tptr") {
            st = expect_type(st, v.typ, p.typ.to, "store through pointer", node.line, node.col);
            { typ: p.typ.to, st: st }
        } else if (p.typ.k == "tunk" || v.typ.k == "tunk") {
            { typ: t_unk(), st: st }
        } else {
            st = fail(st, "store target must be *T, got " + tstr(p.typ), node.line, node.col);
            { typ: t_unk(), st: st }
        }
    } else if (k == "ret") {
        if (st.ret.k == "tnone") {
            st = fail(st, "'return' outside of a function", node.line, node.col);
            { typ: t_unk(), st: st }
        } else {
            let r = typeof_expr(st, node.e);
            st = expect_type(r.st, r.typ, st.ret, "'return'", node.line, node.col);
            { typ: st.ret, st: st }
        }
    } else if (k == "map") {
        let mkeys = node.keys;
        let mvals = node.vals;
        if (len(mkeys) == 0) {
            st = fail(st, "cannot infer record type: annotate the map", node.line, node.col);
            { typ: t_unk(), st: st }
        } else {
            let fields = [];
            let i = 0;
            let ok = true;
            while (i < len(mkeys)) {
                let mvv = mvals[i];
                let mkey = mkeys[i];
                let r = typeof_expr(st, mvv);
                st = r.st;
                if (r.typ.k == "tnone") {
                    ok = false;
                    0
                } else if (r.typ.k == "tname") {
                    ok = false;
                    0
                } else if (!is_value_type(r.typ)) {
                    st = fail(st, "record field '" + mkey + "' has unsupported type " + tstr(r.typ), node.line, node.col);
                    ok = false;
                    0
                } else { 0; };
                fields = push(fields, { name: mkey, typ: r.typ });
                i = i + 1;
            };
            if (ok) {
                { typ: { k: "trec", fields: fields }, st: st }
            } else {
                { typ: t_unk(), st: st }
            }
        }
    } else if (k == "dot") {
        let dobj = node.obj;
        let dkey = node.key;
        let r = typeof_expr(st, dobj);
        st = r.st;
        if (r.typ.k == "trec") {
            let found = false;
            let ftyp = t_unk();
            let fs = r.typ.fields;
            let j = 0;
            while (j < len(fs)) {
                let f = fs[j];
                let fn: str = f.name;
                if (fn == dkey) {
                    found = true;
                    ftyp = f.typ;
                    0
                } else { 0 };
                j = j + 1;
                0
            };
            if (found) {
                { typ: ftyp, st: st }
            } else if (teq(r.typ, unk_shape())) {
                { typ: t_unk(), st: st }
            } else {
                st = fail(st, "record has no field '" + dkey + "'", node.line, node.col);
                { typ: t_unk(), st: st }
            }
        } else if (r.typ.k == "tunk") {
            { typ: t_unk(), st: st }
        } else if (r.typ.k == "tnone") {
            { typ: t_unk(), st: st }
        } else if (r.typ.k == "tname") {
            { typ: t_unk(), st: st }
        } else if (r.typ.k == "tparams") {
            { typ: t_unk(), st: st }
        } else if (r.typ.k == "tnull") {
            { typ: t_unk(), st: st }
        } else {
            st = fail(st, "cannot read field '" + node.key + "' of " + tstr(r.typ) + " (need a record)", node.line, node.col);
            { typ: t_unk(), st: st }
        }
    } else if (k == "func") {
        let ra = typeof_def(st, "", node, node.line, node.col);
        { typ: ra.typ, st: ra.st }
    } else if (k == "arrrep") {
        let r = typeof_expr(st, node.v);
        st = r.st;
        if (!is_value_type(r.typ)) {
            st = fail(st, "array element type " + tstr(r.typ) + " is unsupported in native mode", node.line, node.col);
            { typ: t_unk(), st: st }
        } else if (node.n < 0) {
            st = fail(st, "array size must be a non-negative integer literal ([v; n])", node.line, node.col);
            { typ: t_unk(), st: st }
        } else {
            { typ: { k: "tarrfix", of: r.typ, n: node.n }, st: st }
        }
    } else if (k == "index") {
        if (node.arr.k == "id") {
            let got = lookup(st.bindings, node.arr.v);
            if (got.kind == "") {
                st = fail(st, "undefined variable '" + node.arr.v + "'", node.line, node.col);
                { typ: t_unk(), st: st }
            } else if (got.typ.k == "tarrfix" || got.typ.k == "tarr") {
                st = check_visible(st, got, node.arr.v, node.line, node.col);
                let r = typeof_expr(st, node.idx);
                st = r.st;
                st = expect_type(st, r.typ, { k: "tlong" }, "array index", node.line, node.col);
                { typ: got.typ.of, st: st }
            } else if (got.typ.k == "tunk" || got.typ.k == "tnone" || got.typ.k == "tname") {
                let r = typeof_expr(st, node.idx);
                st = r.st;
                { typ: t_unk(), st: st }
            } else {
                st = fail(st, "cannot index " + tstr(got.typ) + " (only arrays)", node.line, node.col);
                { typ: t_unk(), st: st }
            }
        } else {
            st = fail(st, "only plain variables can be indexed in native mode", node.line, node.col);
            { typ: t_unk(), st: st }
        }
    } else if (k == "slice") {
        let sr = typeof_expr(st, node.arr);
        st = sr.st;
        let slo = node.lo;
        let shi = node.hi;
        if (slo.k == "null") { 0; } else {
            let rl = typeof_expr(st, slo);
            st = expect_type(rl.st, rl.typ, { k: "tlong" }, "slice start", node.line, node.col);
            0
        };
        if (shi.k == "null") { 0; } else {
            let rh = typeof_expr(st, shi);
            st = expect_type(rh.st, rh.typ, { k: "tlong" }, "slice end", node.line, node.col);
            0
        };
        if (sr.typ.k == "tarr") {
            { typ: { k: "tarr", of: sr.typ.of }, st: st }
        } else if (sr.typ.k == "tarrfix") {
            { typ: { k: "tarr", of: sr.typ.of }, st: st }
        } else if (sr.typ.k == "tunk") {
            { typ: t_unk(), st: st }
        } else {
            st = fail(st, "cannot slice " + tstr(sr.typ) + " (only arrays)", node.line, node.col);
            { typ: t_unk(), st: st }
        }
    } else if (k == "dotassign") {
        if (node.obj.k == "id") {
            let got = lookup(st.bindings, node.obj.v);
            if (got.kind == "") {
                st = fail(st, "undefined variable '" + node.obj.v + "'", node.line, node.col);
                { typ: t_unk(), st: st }
            } else if (got.typ.k == "trec") {
                let ft = trec_field_type(got.typ, node.key);
                if (ft.k == "tnone") {
                    st = fail(st, "record has no field '" + node.key + "'", node.line, node.col);
                    { typ: t_unk(), st: st }
                } else {
                    let v = typeof_expr(st, node.v);
                    st = v.st;
                    st = expect_type(st, v.typ, ft, "record field '" + node.key + "'", node.line, node.col);
                    { typ: ft, st: st }
                }
            } else {
                st = fail(st, "cannot field-assign " + tstr(got.typ) + " (only records)", node.line, node.col);
                { typ: t_unk(), st: st }
            }
        } else {
            st = fail(st, "only plain variables can be dot-assigned in native mode", node.line, node.col);
            { typ: t_unk(), st: st }
        }
    } else if (k == "idxassign") {
        if (node.arr.k == "id") {
            let got = lookup(st.bindings, node.arr.v);
            if (got.kind == "") {
                st = fail(st, "undefined variable '" + node.arr.v + "'", node.line, node.col);
                { typ: t_unk(), st: st }
            } else if (got.typ.k == "tarrfix" || got.typ.k == "tarr") {
                st = check_visible(st, got, node.arr.v, node.line, node.col);
                let ix = typeof_expr(st, node.idx);
                st = ix.st;
                st = expect_type(st, ix.typ, { k: "tlong" }, "array index", node.line, node.col);
                let v = typeof_expr(st, node.v);
                st = v.st;
                st = expect_type(st, v.typ, got.typ.of, "array element", node.line, node.col);
                { typ: got.typ.of, st: st }
            } else {
                st = fail(st, "cannot index " + tstr(got.typ) + " (only arrays)", node.line, node.col);
                { typ: t_unk(), st: st }
            }
        } else {
            st = fail(st, "only plain variables can be indexed in native mode", node.line, node.col);
            { typ: t_unk(), st: st }
        }
    } else if (k == "array") {
        let elems = node.elems;
        if (len(elems) == 0) {
            { typ: { k: "tarr", of: t_unk() }, st: st }
        } else {
            let e0 = elems[0];
            let r0 = typeof_expr(st, e0);
            st = r0.st;
            if (r0.typ.k == "tnone") {
                { typ: { k: "tarr", of: t_unk() }, st: st }
            } else if (r0.typ.k == "tname") {
                { typ: { k: "tarr", of: t_unk() }, st: st }
            } else if (r0.typ.k == "tarr") {
                { typ: { k: "tarr", of: t_unk() }, st: st }
            } else if (r0.typ.k == "tnull") {
                { typ: { k: "tarr", of: t_unk() }, st: st }
            } else if (!is_value_type(r0.typ)) {
                st = fail(st, "array element type " + tstr(r0.typ) + " is unsupported in native mode", node.line, node.col);
                { typ: t_unk(), st: st }
            } else {
                let i = 1;
                let elt = r0.typ;
                while (i < len(elems)) {
                    let r = typeof_expr(st, elems[i]);
                    st = r.st;
                    if (elt.k == "tunk") {
                        if (r.typ.k == "tlong") { elt = r.typ; 0; } else { 0; };
                        if (r.typ.k == "tbool") { elt = r.typ; 0; } else { 0; };
                        if (r.typ.k == "tstr") { elt = r.typ; 0; } else { 0; };
                        0
                    } else {
                        st = expect_type(st, r.typ, elt, "array element", node.line, node.col);
                        0
                    };
                    i = i + 1;
                };
                { typ: { k: "tarr", of: elt }, st: st }
            }
        }
    } else {
        st = fail(st, "'" + k + "' is unsupported in native mode (heap planned: maps, loops, strings ops)", node.line, node.col);
        { typ: t_unk(), st: st }
    }
};

def typeof_call(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, node) -> { typ: { k: str }, st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } } {
    let cargs = node.args;
    if (node.callee.k != "id") {
        let cf = typeof_expr(st, node.callee);
        st = cf.st;
        if (cf.typ.k == "tfunc") {
            let cft = cf.typ;
            let cfargs = cft.args;
            if (len(cargs) != len(cfargs)) {
                st = fail(st, "call takes " + tostring(len(cfargs)) + " args, got " + tostring(len(cargs)), node.line, node.col);
                { typ: cft.ret, st: st }
            } else {
                let ci = 0;
                while (ci < len(cargs)) {
                    let ra = typeof_expr(st, cargs[ci]);
                    st = ra.st;
                    st = expect_type(st, ra.typ, cfargs[ci], "call arg " + tostring(ci), node.line, node.col);
                    ci = ci + 1;
                };
                { typ: cft.ret, st: st }
            }
        } else {
            st = fail(st, "cannot call " + tstr(cf.typ) + " (not a function)", node.line, node.col);
            let i = 0;
            while (i < len(node.args)) {
                let r = typeof_expr(st, cargs[i]);
                st = r.st;
                i = i + 1;
            };
            { typ: t_unk(), st: st }
        }
    } else {
        let name = node.callee.v;
        if (name == "print") {
            if (len(node.args) != 1) {
                st = fail(st, "print takes exactly 1 argument", node.line, node.col);
                { typ: { k: "tvoid" }, st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                if (r.typ.k == "tlong" || r.typ.k == "tbyte" || r.typ.k == "tbool" || r.typ.k == "tstr" || r.typ.k == "tfloat" || r.typ.k == "tunk" || r.typ.k == "trec" || r.typ.k == "tfunc") {
                    { typ: { k: "tvoid" }, st: st }
                } else {
                    st = fail(st, "print supports long/bool/float/str/record/function, got " + tstr(r.typ), node.line, node.col);
                    { typ: { k: "tvoid" }, st: st }
                }
            }
        } else if (name == "len") {
            if (len(cargs) != 1) {
                st = fail(st, "len takes exactly 1 argument", node.line, node.col);
                { typ: { k: "tlong" }, st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                if (r.typ.k == "tarrfix" || r.typ.k == "tarr" || r.typ.k == "tstr") {
                    { typ: { k: "tlong" }, st: st }
                } else if (r.typ.k == "tunk" || r.typ.k == "tnone" || r.typ.k == "tname") {
                    { typ: { k: "tlong" }, st: st }
                } else {
                    st = fail(st, "len supports arrays and strings, got " + tstr(r.typ), node.line, node.col);
                    { typ: { k: "tlong" }, st: st }
                }
            }
        } else if (name == "some") {
            if (len(cargs) != 1) {
                st = fail(st, "some takes exactly 1 argument", node.line, node.col);
                { typ: t_unk(), st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                if (!is_value_type(r.typ)) {
                    st = fail(st, "cannot put " + tstr(r.typ) + " in an option", node.line, node.col);
                    { typ: t_unk(), st: st }
                } else {
                    { typ: { k: "topt", of: r.typ }, st: st }
                }
            }
        } else if (name == "is_some") {
            if (len(cargs) != 1) {
                st = fail(st, "is_some takes exactly 1 argument", node.line, node.col);
                { typ: { k: "tbool" }, st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                if (r.typ.k == "topt" || r.typ.k == "tunk") {
                    { typ: { k: "tbool" }, st: st }
                } else {
                    st = fail(st, "is_some needs an option, got " + tstr(r.typ), node.line, node.col);
                    { typ: { k: "tbool" }, st: st }
                }
            }
        } else if (name == "unwrap") {
            if (len(cargs) != 1) {
                st = fail(st, "unwrap takes exactly 1 argument", node.line, node.col);
                { typ: t_unk(), st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                if (r.typ.k == "topt") {
                    { typ: r.typ.of, st: st }
                } else if (r.typ.k == "tunk") {
                    { typ: t_unk(), st: st }
                } else if (r.typ.k == "tnull") {
                    { typ: t_unk(), st: st }
                } else if (r.typ.k == "tnone") {
                    { typ: t_unk(), st: st }
                } else if (r.typ.k == "tname") {
                    { typ: t_unk(), st: st }
                } else if (r.typ.k == "tparams") {
                    { typ: t_unk(), st: st }
                } else {
                    st = fail(st, "unwrap needs an option, got " + tstr(r.typ), node.line, node.col);
                    { typ: t_unk(), st: st }
                }
            }
        } else if (name == "push") {            if (len(cargs) != 2) {
                st = fail(st, "push takes exactly 2 arguments (array, value)", node.line, node.col);
                { typ: t_unk(), st: st }
            } else {
                let r0 = typeof_expr(st, cargs[0]);
                st = r0.st;
                if (r0.typ.k == "tarrfix") {
                    st = fail(st, "cannot push to fixed array " + tstr(r0.typ) + " (its length is part of its type; use [T] instead)", node.line, node.col);
                    let r1f = typeof_expr(st, cargs[1]);
                    st = r1f.st;
                    { typ: t_unk(), st: st }
                } else if (r0.typ.k != "tarr") {
                    st = fail(st, "push needs a heap array, got " + tstr(r0.typ), node.line, node.col);
                    { typ: t_unk(), st: st }
                } else if (r0.typ.of.k == "tunk") {
                    let r1b = typeof_expr(st, cargs[1]);
                    st = r1b.st;
                    { typ: t_unk(), st: st }
                } else {
                    let r1c = typeof_expr(st, cargs[1]);
                    st = r1c.st;
                    st = expect_type(st, r1c.typ, r0.typ.of, "push value", node.line, node.col);
                    { typ: r0.typ, st: st }
                }
            }
        } else if (name == "substr") {
            if (len(cargs) != 3) {
                st = fail(st, "substr takes exactly 3 arguments (string, start, count)", node.line, node.col);
                { typ: t_unk(), st: st }
            } else {
                let r0 = typeof_expr(st, cargs[0]);
                st = r0.st;
                let r1 = typeof_expr(st, cargs[1]);
                st = r1.st;
                let r2 = typeof_expr(st, cargs[2]);
                st = r2.st;
                st = expect_type(st, r0.typ, { k: "tstr" }, "substr string", node.line, node.col);
                st = expect_type(st, r1.typ, { k: "tlong" }, "substr start", node.line, node.col);
                st = expect_type(st, r2.typ, { k: "tlong" }, "substr count", node.line, node.col);
                { typ: { k: "tstr" }, st: st }
            }
        } else if (name == "trim") {
            if (len(cargs) != 1) {
                st = fail(st, "trim takes exactly 1 argument", node.line, node.col);
                { typ: t_unk(), st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                st = expect_type(st, r.typ, { k: "tstr" }, "trim string", node.line, node.col);
                { typ: { k: "tstr" }, st: st }
            }
        } else if (name == "ord") {
            if (len(cargs) != 1) {
                st = fail(st, "ord takes exactly 1 argument", node.line, node.col);
                { typ: t_unk(), st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                st = expect_type(st, r.typ, { k: "tstr" }, "ord string", node.line, node.col);
                { typ: { k: "tlong" }, st: st }
            }
        } else if (name == "chr") {
            if (len(cargs) != 1) {
                st = fail(st, "chr takes exactly 1 argument", node.line, node.col);
                { typ: t_unk(), st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                st = expect_type(st, r.typ, { k: "tlong" }, "chr code", node.line, node.col);
                { typ: { k: "tstr" }, st: st }
            }
        } else if (name == "tonum") {
            if (len(cargs) != 1) {
                st = fail(st, "tonum takes exactly 1 argument", node.line, node.col);
                { typ: t_unk(), st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                st = expect_type(st, r.typ, { k: "tstr" }, "tonum string", node.line, node.col);
                { typ: { k: "tlong" }, st: st }
            }
        } else if (name == "tostring") {
            if (len(cargs) != 1) {
                st = fail(st, "tostring takes exactly 1 argument", node.line, node.col);
                { typ: t_unk(), st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                if (r.typ.k == "tlong" || r.typ.k == "tbyte" || r.typ.k == "tbool" || r.typ.k == "tstr" || r.typ.k == "tfloat" || r.typ.k == "tunk" || r.typ.k == "tarr" || r.typ.k == "tarrfix") {
                    { typ: { k: "tstr" }, st: st }
                } else {
                    st = fail(st, "tostring supports long/bool/float/str/array, got " + tstr(r.typ), node.line, node.col);
                    { typ: t_unk(), st: st }
                }
            }
        } else if (name == "typeof") {
            if (len(cargs) != 1) {
                st = fail(st, "typeof takes exactly 1 argument", node.line, node.col);
                { typ: t_unk(), st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                { typ: { k: "tstr" }, st: st }
            }
        } else if (name == "index_of" || name == "last_index_of") {
            if (len(cargs) != 2) {
                st = fail(st, name + " takes exactly 2 arguments (string, sub)", node.line, node.col);
                { typ: t_unk(), st: st }
            } else {
                let r0 = typeof_expr(st, cargs[0]);
                st = r0.st;
                let r1 = typeof_expr(st, cargs[1]);
                st = r1.st;
                st = expect_type(st, r0.typ, { k: "tstr" }, name + " string", node.line, node.col);
                st = expect_type(st, r1.typ, { k: "tstr" }, name + " sub", node.line, node.col);
                { typ: { k: "tlong" }, st: st }
            }
        } else if (name == "join") {
            if (len(cargs) != 2) {
                st = fail(st, "join takes exactly 2 arguments (array, delimiter)", node.line, node.col);
                { typ: t_unk(), st: st }
            } else {
                let r0 = typeof_expr(st, cargs[0]);
                st = r0.st;
                let r1 = typeof_expr(st, cargs[1]);
                st = r1.st;
                if (r0.typ.k != "tarr" && r0.typ.k != "tunk") {
                    st = fail(st, "join needs an array, got " + tstr(r0.typ), node.line, node.col);
                    0
                } else { 0; };
                st = expect_type(st, r1.typ, { k: "tstr" }, "join delimiter", node.line, node.col);
                { typ: { k: "tstr" }, st: st }
            }
        } else if (name == "split") {
            if (len(cargs) != 2) {
                st = fail(st, "split takes exactly 2 arguments (string, delimiter)", node.line, node.col);
                { typ: t_unk(), st: st }
            } else {
                let r0 = typeof_expr(st, cargs[0]);
                st = r0.st;
                let r1 = typeof_expr(st, cargs[1]);
                st = r1.st;
                st = expect_type(st, r0.typ, { k: "tstr" }, "split string", node.line, node.col);
                st = expect_type(st, r1.typ, { k: "tstr" }, "split delimiter", node.line, node.col);
                { typ: { k: "tarr", of: { k: "tstr" } }, st: st }
            }
        } else if (name == "range") {
            if (len(cargs) != 1) {
                st = fail(st, "range takes exactly 1 argument", node.line, node.col);
                { typ: { k: "tarr", of: { k: "tlong" } }, st: st }
            } else {
                let rr = typeof_expr(st, cargs[0]);
                st = expect_type(rr.st, rr.typ, { k: "tlong" }, "range count", node.line, node.col);
                { typ: { k: "tarr", of: { k: "tlong" } }, st: st }
            }
        } else if (name == "eputs") {
            if (len(cargs) != 1) {
                st = fail(st, "eputs takes exactly 1 argument", node.line, node.col);
                { typ: { k: "tvoid" }, st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                if (r.typ.k == "tlong" || r.typ.k == "tbool" || r.typ.k == "tstr" || r.typ.k == "tfloat" || r.typ.k == "tunk") {
                    { typ: { k: "tvoid" }, st: st }
                } else {
                    st = fail(st, "eputs supports long/bool/str, got " + tstr(r.typ), node.line, node.col);
                    { typ: { k: "tvoid" }, st: st }
                }
            }
        } else if (name == "clock_us") {
            if (len(cargs) != 0) {
                st = fail(st, "clock_us takes no arguments", node.line, node.col);
                { typ: { k: "tlong" }, st: st }
            } else {
                { typ: { k: "tlong" }, st: st }
            }
        } else if (name == "heap_used") {
            if (len(cargs) != 0) {
                st = fail(st, "heap_used takes no arguments", node.line, node.col);
                { typ: { k: "tlong" }, st: st }
            } else {
                { typ: { k: "tlong" }, st: st }
            }
        } else if (name == "sleep") {
            if (len(cargs) != 1) {
                st = fail(st, "sleep takes exactly 1 argument (milliseconds)", node.line, node.col);
                { typ: { k: "tnull" }, st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                st = expect_type(st, r.typ, { k: "tlong" }, "sleep duration", node.line, node.col);
                { typ: { k: "tnull" }, st: st }
            }
        } else if (name == "puts") {
            if (len(cargs) != 1) {
                st = fail(st, "puts takes exactly 1 argument", node.line, node.col);
                { typ: { k: "tvoid" }, st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                if (r.typ.k == "tlong" || r.typ.k == "tbool" || r.typ.k == "tstr" || r.typ.k == "tfloat" || r.typ.k == "tunk") {
                    { typ: { k: "tvoid" }, st: st }
                } else {
                    st = fail(st, "puts supports long/bool/str, got " + tstr(r.typ), node.line, node.col);
                    { typ: { k: "tvoid" }, st: st }
                }
            }
        } else if (name == "exit") {
            if (len(cargs) != 1) {
                st = fail(st, "exit takes exactly 1 argument", node.line, node.col);
                { typ: { k: "tvoid" }, st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                st = expect_type(st, r.typ, { k: "tlong" }, "exit code", node.line, node.col);
                { typ: { k: "tvoid" }, st: st }
            }
        } else if (name == "argv") {
            if (len(cargs) != 0) {
                st = fail(st, "argv takes no arguments", node.line, node.col);
                { typ: { k: "tarr", of: { k: "tstr" } }, st: st }
            } else {
                { typ: { k: "tarr", of: { k: "tstr" } }, st: st }
            }
        } else if (name == "read_file") {
            if (len(cargs) != 1) {
                st = fail(st, "read_file takes exactly 1 argument (path)", node.line, node.col);
                { typ: t_unk(), st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                st = expect_type(st, r.typ, { k: "tstr" }, "read_file path", node.line, node.col);
                { typ: { k: "topt", of: { k: "tstr" } }, st: st }
            }
        } else if (name == "bytes") {
            if (len(cargs) != 1) {
                st = fail(st, "bytes takes exactly 1 argument (string)", node.line, node.col);
                { typ: { k: "tarr", of: { k: "tbyte" } }, st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                st = expect_type(st, r.typ, { k: "tstr" }, "bytes argument", node.line, node.col);
                { typ: { k: "tarr", of: { k: "tbyte" } }, st: st }
            }
        } else if (name == "from_bytes") {
            if (len(cargs) != 1) {
                st = fail(st, "from_bytes takes exactly 1 argument (byte array)", node.line, node.col);
                { typ: { k: "tstr" }, st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                st = expect_type(st, r.typ, { k: "tarr", of: { k: "tbyte" } }, "from_bytes argument", node.line, node.col);
                { typ: { k: "tstr" }, st: st }
            }
        } else if (name == "write_file") {
            if (len(cargs) != 2) {
                st = fail(st, "write_file takes exactly 2 arguments (path, content)", node.line, node.col);
                { typ: t_unk(), st: st }
            } else {
                let r0 = typeof_expr(st, cargs[0]);
                st = r0.st;
                let r1 = typeof_expr(st, cargs[1]);
                st = r1.st;
                st = expect_type(st, r0.typ, { k: "tstr" }, "write_file path", node.line, node.col);
                st = expect_type(st, r1.typ, { k: "tstr" }, "write_file content", node.line, node.col);
                { typ: { k: "tbool" }, st: st }
            }
        } else if (name == "write_bytes") {
            if (len(cargs) != 3) {
                st = fail(st, "write_bytes takes exactly 3 arguments (path, bytes, mode)", node.line, node.col);
                { typ: t_unk(), st: st }
            } else {
                let w0 = typeof_expr(st, cargs[0]);
                st = w0.st;
                let w1 = typeof_expr(st, cargs[1]);
                st = w1.st;
                let w2 = typeof_expr(st, cargs[2]);
                st = w2.st;
                st = expect_type(st, w0.typ, { k: "tstr" }, "write_bytes path", node.line, node.col);
                if (w1.typ.k != "tarr" && w1.typ.k != "tunk") {
                    st = fail(st, "write_bytes needs a byte array, got " + tstr(w1.typ), node.line, node.col);
                    0
                } else { 0; };
                st = expect_type(st, w2.typ, { k: "tlong" }, "write_bytes mode", node.line, node.col);
                { typ: { k: "tbool" }, st: st }
            }
        } else if (name == "ptr_addr") {
            if (len(cargs) != 1) {
                st = fail(st, "ptr_addr takes exactly 1 argument (pointer)", node.line, node.col);
                { typ: { k: "tlong" }, st: st }
            } else {
                let r = typeof_expr(st, cargs[0]);
                st = r.st;
                if (r.typ.k == "tptr" || r.typ.k == "tstr" || r.typ.k == "tunk") {
                    { typ: { k: "tlong" }, st: st }
                } else {
                    st = fail(st, "ptr_addr needs a pointer, got " + tstr(r.typ), node.line, node.col);
                    { typ: { k: "tlong" }, st: st }
                }
            }
        } else if (name == "syscall") {            if (len(node.args) < 1 || len(node.args) > 7) {
                st = fail(st, "syscall needs 1-7 arguments (number + up to 6 args)", node.line, node.col);
                { typ: { k: "tlong" }, st: st }
            } else {
                let i = 0;
                while (i < len(node.args)) {
                    let r = typeof_expr(st, cargs[i]);
                    st = r.st;
                    if (r.typ.k != "tlong" && r.typ.k != "tbool" && r.typ.k != "tstr" && r.typ.k != "tptr" && r.typ.k != "tunk") {
                        st = fail(st, "syscall arg " + tostring(i) + " must be long/bool/str/*T, got " + tstr(r.typ), node.line, node.col);
                        0
                    } else { 0; };
                    i = i + 1;
                };
                { typ: { k: "tlong" }, st: st }
            }
        } else {
            let fterr = "";
            let ft = t_unk();
            if (name == "self") {
                if (st.self.k == "tnone" || st.self.k == "tunk") {
                    fterr = "'self' outside of a function";
                    0
                } else {
                    ft = st.self;
                    0
                };
            } else {
                let got = lookup(st.bindings, name);
                if (got.kind == "") {
                    fterr = "undefined function '" + disp(name) + "'";
                    0
                } else if (got.typ.k == "tfunc") {
                    ft = got.typ;
                    0
                } else {
                    fterr = "'" + disp(name) + "' is not a function";
                    0
                };
            };
            if (fterr != "") {
                st = fail(st, fterr, node.line, node.col);
                { typ: t_unk(), st: st }
            } else if (ft.k != "tfunc") {
                let i = 0;
                while (i < len(cargs)) {
                    let r = typeof_expr(st, cargs[i]);
                    st = r.st;
                    i = i + 1;
                };
                { typ: t_unk(), st: st }
            } else {
                let cargs_ft = ft.args;
                if (len(cargs) != len(cargs_ft)) {
                    st = fail(st, "'" + disp(name) + "' takes " + tostring(len(cargs_ft)) + " args, got " + tostring(len(cargs)), node.line, node.col);
                    { typ: ft.ret, st: st }
                } else {
                    let i = 0;
                    while (i < len(cargs)) {
                        let r = typeof_expr(st, cargs[i]);
                        st = r.st;
                        st = expect_type(st, r.typ, cargs_ft[i], "'" + disp(name) + "' arg " + tostring(i), node.line, node.col);
                        i = i + 1;
                    };
                    { typ: ft.ret, st: st }
                }
            }
        }
    }
};

def typeof_block(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, node) -> { typ: { k: str }, st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } } {
    let last = { k: "tvoid" };
    let bstmts = node.stmts;
    let i = 0;
    while (i < len(bstmts)) {
        let r = typeof_expr(st, bstmts[i]);
        st = r.st;
        last = r.typ;
        i = i + 1;
    };
    { typ: last, st: st }
};


def typeof_decl(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, node) -> { typ: { k: str }, st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } } {
    if (node.kind == "def") {
        typeof_def(st, node.name, node.v, node.line, node.col)
    } else {
        if (node.v.k == "func") {
            let fr = typeof_def(st, node.name, node.v, node.line, node.col);
            st = fr.st;
            if (node.typ.k != "tnone") {
                st = expect_type(st, fr.typ, node.typ, "let '" + disp(node.name) + "'", node.line, node.col);
                0
            } else { 0; };
            st = st_bind(st, node.name, fr.typ, "func");
            { typ: fr.typ, st: st }
        } else if (node.v.k == "arrrep") {
            let r = typeof_expr(st, node.v);
            st = r.st;
            if (r.typ.k == "tunk") {
                st = st_bind(st, node.name, t_unk(), "local");
                { typ: t_unk(), st: st }
            } else {
                let at = r.typ;
                if (node.typ.k != "tnone") {
                    if (arr_lit_adopts(r.typ, node.typ)) {
                        0
                    } else {
                        st = expect_type(st, r.typ, node.typ, "let '" + disp(node.name) + "'", node.line, node.col);
                        0
                    };
                    at = node.typ;
                    0
                } else { 0; };
                st = st_bind(st, node.name, at, "local");
                { typ: at, st: st }
            }
        } else {
            let r = typeof_expr(st, node.v);
            st = r.st;
            let t = r.typ;
            let vk = node.v.k;
            if (node.typ.k != "tnone") {
                if (!is_value_type(node.typ)) {
                    st = fail(st, "annotation '" + tstr(node.typ) + "' is not a native value type", node.line, node.col);
                    0
                } else if (vk == "array") {
                    if (arr_lit_adopts(r.typ, node.typ)) { 0; } else {
                        st = expect_type(st, r.typ, node.typ, "let '" + disp(node.name) + "'", node.line, node.col);
                        0;
                    };
                    t = node.typ;
                    0
                } else {
                    st = expect_type(st, r.typ, node.typ, "let '" + disp(node.name) + "'", node.line, node.col);
                    t = node.typ;
                    0
                };
                0
            } else { 0; };
            if (t.k == "tnone") {
                t = t_unk();
                0
            } else if (t.k == "tname") {
                t = t_unk();
                0
            } else if (t.k == "tvoid") {
                st = fail(st, "cannot bind a void value to '" + disp(node.name) + "'", node.line, node.col);
                t = t_unk();
                0
            } else if (!is_value_type(t)) {
                st = fail(st, "'" + tstr(t) + "' is unsupported in native mode (heap planned)", node.line, node.col);
                t = t_unk();
                0
            } else { 0; };
            st = st_bind(st, node.name, t, "local");
            { typ: t, st: st }
        }
    }
};

def typeof_def(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, name: str, func, line: long, col: long) -> { typ: { k: str }, st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } } {
    if (len(func.params) != len(func.ptypes)) {
        st = fail(st, "internal: params/ptypes length mismatch", line, col);
        { typ: t_unk(), st: st }
    } else {
        let args = [];
        let fparams = func.params;
        let fptypes = func.ptypes;
        let i = 0;
        let ok = true;
        while (i < len(fparams)) {
            let pt = fptypes[i];
            if (pt.k == "tnone") {
                pt = t_unk();
                0
            } else if (!is_value_type(pt) && pt.k != "tfunc") {
                st = fail(st, "parameter '" + disp(fparams[i]) + "' has unpassable type " + tstr(pt) + " (arrays cannot cross function boundaries — pass &a plus a length)", line, col);
                ok = false;
                0
            } else { 0; };
            args = push(args, pt);
            i = i + 1;
        };
        let ret = func.ret;
        let ret_inferred = false;
        if (ret.k == "tnone") {
            ret_inferred = true;
            ret = t_unk();
            0
        } else { 0; };
        let ft = { k: "tfunc", args: args, ret: ret };
        st = st_bind(st, name, ft, "func");
        let saved_self = st.self;
        let saved_ret = st.ret;
        let saved_depth = st.fdepth;
        st = st_fdepth(st, saved_depth + 1);
        let j = 0;
        while (j < len(fparams)) {
            st = st_bind(st, fparams[j], args[j], "param");
            j = j + 1;
        };
        st = st_self(st, ft);
        st = st_ret(st, ret);
        let b = typeof_block(st, func.body);
        st = b.st;
        if (ret_inferred) {
            let br = b.typ;
            if (br.k == "tnone") {
                br = t_unk();
                0
            } else { 0; };
            ft = { k: "tfunc", args: args, ret: br };
            st = st_bind(st, name, ft, "func");
            0
        } else { 0; };
        if (!(ret_inferred)) {
            st = expect_type(st, b.typ, ret, "'" + disp(name) + "' body", line, col);
            0
        } else { 0; };
        st = st_fdepth(st, saved_depth);
        st = st_self(st, saved_self);
        st = st_ret(st, saved_ret);
        if (ok) {
            { typ: ft, st: st }
        } else {
            st = st_bind(st, name, t_unk(), "func");
            { typ: t_unk(), st: st }
        }
    }
};

def st_fdepth(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, d: long) -> { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } { { bindings: st.bindings, errors: st.errors, ret: st.ret, self: st.self, fdepth: d } };

def check_func_value(st: { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long }, name: str, func, line: long, col: long) -> { bindings: [{ name: str, typ: { k: str }, kind: str, fdepth: long }], errors: [{ msg: str, line: long, col: long }], ret: { k: str }, self: { k: str }, fdepth: long } {
    let r = typeof_def(st, name, func, line, col);
    r.st
};


def check_program(ast) -> [{ msg: str, line: long, col: long }] {
    let defs = [];
    let pstmts = ast.stmts;
    let i = 0;
    while (i < len(pstmts)) {
        let s = pstmts[i];
        if (s.k == "decl") {
            if (s.kind == "def") {
                defs = push(defs, def_sig(s.name, s.v));
                0
            } else if (s.v.k == "func") {
                defs = push(defs, def_sig(s.name, s.v));
                0
            } else { 0; };
            0
        } else { 0; };
        i = i + 1;
    };
    let st = { bindings: [], errors: [], ret: { k: "tnone" }, self: { k: "tnone" }, fdepth: 0 };
    st = st_bind(st, "print", { k: "tfunc", args: [{ k: "tlong" }], ret: { k: "tvoid" } }, "intrinsic");
    st = st_bind(st, "syscall", { k: "tlong" }, "intrinsic");
    let d = 0;
    while (d < len(defs)) {
        st = st_bind(st, defs[d].name, defs[d].typ, "func");
        d = d + 1;
    };
    let r = typeof_block(st, ast);
    r.st.errors
};

def def_sig(name: str, func) -> { name: str, typ: { k: str } } {
    let args = [];
    let fpt = func.ptypes;
    let i = 0;
    while (i < len(func.params)) {
        let pt = fpt[i];
        if (pt.k == "tnone") { pt = t_unk(); };
        args = push(args, pt);
        i = i + 1;
    };
    let ret = func.ret;
    if (ret.k == "tnone") { ret = t_unk(); };
    { name: name, typ: { k: "tfunc", args: args, ret: ret } }
};

export { check_program, tstr, tdisp, tdisp_fnval };
