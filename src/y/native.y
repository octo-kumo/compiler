import arch from "./arch_x64.y";
import types from "./types.y";
import rename from "./rename.y";
import prelude from "./std/prelude.y";


def native_resolve(src: str, base_dir: str, depth: long) -> { src: str, imports: [str], pre: long } {
    native_resolve_x(src, base_dir, depth, true)
};

def native_resolve_x(src: str, base_dir: str, depth: long, allow_exec: bool) -> { src: str, imports: [str], pre: long } {
    let r = native_resolve_seen(src, base_dir, depth, []);
    let rsrc = r.src;
    let rimports = r.imports;
    let pre = 0;
    if (allow_exec) {
        if (names_mentioned(rsrc, prelude.exec_names())) {
            let xl = prelude.exec_lines();
            rsrc = join(xl, "\n") + "\n" + rsrc;
            pre = pre + len(xl);
            0
        } else { 0; };
        0
    } else { 0; };
    if (names_mentioned(rsrc, prelude.prelude_names())) {
        let pl = prelude.prelude_lines();
        rsrc = join(pl, "\n") + "\n" + rsrc;
        pre = pre + len(pl);
        0
    } else { 0; };
    { src: rsrc, imports: rimports, pre: pre }
};

def names_mentioned(src: str, names: [str]) -> bool {
    let i = 0;
    let want = false;
    while (i < len(names)) {
        let nm: str = names[i];
        if (index_of(src, nm) >= 0) {
            want = true;
            0
        } else { 0; };
        i = i + 1;
        0
    };
    want
};

def norm_path(p: str) -> str {
    let parts = split(p, "/");
    let out = [];
    let i = 0;
    while (i < len(parts)) {
        let seg = parts[i];
        if (seg == ".") {
            0
        } else {
            out = push(out, seg);
            0
        };
        i = i + 1;
        0
    };
    join(out, "/")
};

def seen_has(seen: [str], full: str) -> bool {
    let i = 0;
    let found = false;
    while (i < len(seen)) {
        let e = seen[i];
        if (e == full) {
            found = true;
            0
        } else { 0 };
        i = i + 1;
        0
    };
    found
};

def native_resolve_seen(src: str, base_dir: str, depth: long, seen: [str]) -> { src: str, imports: [str], seen: [str] } {
    if (depth > 32) {
        puts("error: native import depth exceeded (cycle?)\n");
        { src: "", imports: [], seen: seen }
    } else {
        let lines = split(src, "\n");
        let out_lines = [];
        let imports = [];
        let i = 0;
        let n = len(lines);
        while (i < n) {
            let line = lines[i];
            let trimmed = trim(line);
            if (substr(trimmed, 0, 7) == "import ") {
                let rest = substr(trimmed, 7, len(trimmed) - 7);
                let from_idx = index_of(rest, " from ");
                if (from_idx >= 0) {
                    let name = trim(substr(rest, 0, from_idx));
                    let path_part = trim(substr(rest, from_idx + 6, len(rest) - from_idx - 6));
                    if (substr(path_part, len(path_part) - 1, 1) == ";") {
                        path_part = substr(path_part, 0, len(path_part) - 1);
                        0
                    } else { 0 };
                    let path = substr(path_part, 1, len(path_part) - 2);
                    let full = norm_path(base_dir + "/" + path);
                    if (substr(path, 0, 1) == "/") { full = norm_path(path); 0; } else { 0 };
                    let mod_src = read_file(full);
                    if (mod_src == null) {
                        puts("error: cannot open import '" + path + "' (resolved to '" + full + "')\n");
                        out_lines = push(out_lines, line);
                        0
                    } else if (seen_has(seen, full)) {
                        imports = push(imports, name);
                        0
                    } else {
                        seen = push(seen, full);
                        let last_slash = last_index_of(path, "/");
                        let mod_dir = base_dir;
                        if (last_slash >= 0) {
                            mod_dir = base_dir + "/" + substr(path, 0, last_slash);
                            0
                        } else { 0 };
                        let mod_src2 = unwrap(mod_src);
                        let sub = native_resolve_seen(mod_src2, mod_dir, depth + 1, seen);
                        let subsrc = sub.src;
                        let subns = sub.imports;
                        let subseen = sub.seen;
                        seen = subseen;
                        let sub_lines = split(subsrc, "\n");
                        let k = 0;
                        while (k < len(sub_lines)) {
                            out_lines = push(out_lines, sub_lines[k]);
                            k = k + 1;
                            0
                        };
                        let m = 0;
                        while (m < len(subns)) {
                            imports = push(imports, subns[m]);
                            m = m + 1;
                            0
                        };
                        imports = push(imports, name);
                        0
                    };
                    0
                } else {
                    out_lines = push(out_lines, line);
                    0
                };
                0
            } else {
                if (substr(trimmed, 0, 7) != "export ") {
                    out_lines = push(out_lines, line);
                    0
                } else { 0 };
                0
            };
            i = i + 1;
            0
        };
        { src: join(out_lines, "\n"), imports: imports, seen: seen }
    }
};

def is_ns(name: str, imports: [str]) -> bool {
    let i = 0;
    let found = false;
    while (i < len(imports)) {
        if (imports[i] == name) { found = true; 0; } else { 0; };
        i = i + 1;
        0
    };
    found
};

def normnode(anode) -> { k: str } { anode };


def strip_list(nodes: [{ k: str }], imports: [str]) -> [{ k: str }] {
    let out = [];
    let i = 0;
    while (i < len(nodes)) {
        out = push(out, strip_ns(nodes[i], imports));
        i = i + 1;
    };
    out
};

def strip_ns(node, imports: [str]) -> { k: str } {
    let k = node.k;
    if (k == "dot") {
        let dobj = node.obj;
        let obj = strip_ns(dobj, imports);
        let okey = node.key;
        let oline = node.line;
        let ocol = node.col;
        if (obj.k == "id") {
            let ov = obj.v;
            if (is_ns(ov, imports)) {
                normnode({ k: "id", v: okey, line: oline, col: ocol })
            } else {
                normnode({ k: "dot", obj: obj, key: okey, line: oline, col: ocol })
            }
        } else {
            normnode({ k: "dot", obj: obj, key: okey, line: oline, col: ocol })
        }
    } else if (k == "un") {
        normnode({ k: "un", op: node.op, e: strip_ns(node.e, imports), line: node.line, col: node.col })
    } else if (k == "addr" || k == "deref") {
        normnode({ k: k, e: strip_ns(node.e, imports), line: node.line, col: node.col })
    } else if (k == "bin") {
        normnode({ k: "bin", op: node.op, l: strip_ns(node.l, imports), r: strip_ns(node.r, imports), line: node.line, col: node.col })
    } else if (k == "call") {
        normnode({ k: "call", callee: strip_ns(node.callee, imports), args: strip_list(node.args, imports), line: node.line, col: node.col })
    } else if (k == "if") {
        normnode({ k: "if", cond: strip_ns(node.cond, imports), then: strip_ns(node.then, imports), els: strip_ns(node.els, imports), has_else: node.has_else, line: node.line, col: node.col })
    } else if (k == "while") {
        normnode({ k: "while", cond: strip_ns(node.cond, imports), body: strip_ns(node.body, imports), line: node.line, col: node.col })
    } else if (k == "block") {
        normnode({ k: "block", stmts: strip_list(node.stmts, imports), line: node.line, col: node.col })
    } else if (k == "decl") {
        strip_decl(node, imports)
    } else if (k == "func") {
        normnode({ k: "func", params: node.params, ptypes: node.ptypes, ret: node.ret, body: strip_ns(node.body, imports), line: node.line, col: node.col })
    } else if (k == "assign") {
        normnode({ k: "assign", name: node.name, v: strip_ns(node.v, imports), line: node.line, col: node.col })
    } else if (k == "store") {
        normnode({ k: "store", p: strip_ns(node.p, imports), v: strip_ns(node.v, imports), line: node.line, col: node.col })
    } else if (k == "ret") {
        normnode({ k: "ret", e: strip_ns(node.e, imports), line: node.line, col: node.col })
    } else if (k == "array") {
        normnode({ k: "array", elems: strip_list(node.elems, imports), line: node.line, col: node.col })
    } else if (k == "arrrep") {
        normnode({ k: "arrrep", v: strip_ns(node.v, imports), n: node.n, line: node.line, col: node.col })
    } else if (k == "map") {
        normnode({ k: "map", keys: node.keys, vals: strip_list(node.vals, imports), line: node.line, col: node.col })
    } else if (k == "index") {
        normnode({ k: "index", arr: strip_ns(node.arr, imports), idx: strip_ns(node.idx, imports), line: node.line, col: node.col })
    } else if (k == "slice") {
        normnode({ k: "slice", arr: strip_ns(node.arr, imports), lo: strip_ns(node.lo, imports), hi: strip_ns(node.hi, imports), line: node.line, col: node.col })
    } else if (k == "idxassign") {
        normnode({ k: "idxassign", arr: strip_ns(node.arr, imports), idx: strip_ns(node.idx, imports), v: strip_ns(node.v, imports), line: node.line, col: node.col })
    } else if (k == "dotassign") {
        normnode({ k: "dotassign", obj: strip_ns(node.obj, imports), key: node.key, v: strip_ns(node.v, imports), line: node.line, col: node.col })
    } else if (k == "foreach") {
        normnode({ k: "foreach", name: node.name, iter: strip_ns(node.iter, imports), body: strip_ns(node.body, imports), line: node.line, col: node.col })
    } else if (k == "forrange") {
        normnode({ k: "forrange", name: node.name, lo: strip_ns(node.lo, imports), hi: strip_ns(node.hi, imports), body: strip_ns(node.body, imports), line: node.line, col: node.col })
    } else if (k == "for") {
        normnode({ k: "for", init: strip_ns(node.init, imports), cond: strip_ns(node.cond, imports), step: strip_ns(node.step, imports), body: strip_ns(node.body, imports), line: node.line, col: node.col })
    } else {
        normnode(node)
    }
};

def strip_decl(node, imports: [str]) -> { k: str } {
    if (node.kind == "def") {
        normnode({ k: "decl", kind: "def", name: node.name, v: strip_ns(node.v, imports), line: node.line, col: node.col })
    } else {
        normnode({ k: "decl", kind: node.kind, name: node.name, typ: node.typ, v: strip_ns(node.v, imports), line: node.line, col: node.col })
    }
};


def st_new() -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    { out: [], rodata: [], uid: 1, fuid: 0, loc: 1, env: [],
      slots: 0, self_label: "", end_label: "", fns: [], bodies: [] }
};

def emit(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, line: str) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    { out: push(st.out, line), rodata: st.rodata, uid: st.uid,
      fuid: st.fuid, loc: st.loc, env: st.env, slots: st.slots,
      self_label: st.self_label, end_label: st.end_label, fns: st.fns,
      bodies: st.bodies }
};

def next_uid(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }) -> { st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, uid: long } {
    let u = st.uid;
    st = { out: st.out, rodata: st.rodata, uid: st.uid + 1,
      fuid: st.fuid, loc: st.loc, env: st.env, slots: st.slots,
      self_label: st.self_label, end_label: st.end_label, fns: st.fns,
      bodies: st.bodies };
    { st: st, uid: u }
};

def next_loc(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }) -> { st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, lbl: str } {
    let n = st.loc;
    let lbl = arch.arch_loc_label(st.fuid, n);
    st = { out: st.out, rodata: st.rodata, uid: st.uid,
      fuid: st.fuid, loc: st.loc + 1, env: st.env, slots: st.slots,
      self_label: st.self_label, end_label: st.end_label, fns: st.fns,
      bodies: st.bodies };
    { st: st, lbl: lbl }
};


def esc_asm(s: str) -> str {
    let buf = "";
    let i = 0;
    let n = len(s);
    while (i < n) {
        let c = substr(s, i, 1);
        let o = ord(c);
        if (c == "\\") { buf = buf + "\\\\"; }
        else if (c == "\"") { buf = buf + "\\\""; }
        else if (c == "\n") { buf = buf + "\\n"; }
        else if (c == "\t") { buf = buf + "\\t"; }
        else if (o < 32 || o > 126) {
            let d2 = o / 64;
            let d1 = (o / 8) % 8;
            let d0 = o % 8;
            buf = buf + "\\" + tostring(d2) + tostring(d1) + tostring(d0);
        } else {
            buf = buf + c;
        };
        i = i + 1;
    };
    buf
};


def env_find(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, name: str) -> { name: str, kind: str, off: long, label: str, typ: { k: str } } {
    let env = st.env;
    let i = 0;
    let found = { name: "", kind: "none", off: 0, label: "", typ: { k: "tnone" } };
    while (i < len(env)) {
        let e = env[i];
        if (e.name == name) {
            found = e;
            0
        } else { 0; };
        i = i + 1;
        0
    };
    found
};

def env_define(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, name: str, kind: str, off: long, label: str, typ) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let env = push(st.env, { name: name, kind: kind, off: off, label: label, typ: typ });
    { out: st.out, rodata: st.rodata, uid: st.uid,
      fuid: st.fuid, loc: st.loc, env: env, slots: st.slots,
      self_label: st.self_label, end_label: st.end_label, fns: st.fns,
      bodies: st.bodies }
};


def infer(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { k: str } {
    let k = node.k;
    if (k == "num") {
        if (lit_is_float(node.v)) { { k: "tfloat" } } else { { k: "tlong" } }
    }
    else if (k == "str") { { k: "tstr" } }
    else if (k == "bool") { { k: "tbool" } }
    else if (k == "null") { { k: "tnull" } }
    else if (k == "id") {
        if (node.v == "self") { { k: "tfunc" } } else {
            let e = env_find(st, node.v);
            if (e.kind == "none") {
                if (node.v == "none") { normnode({ k: "topt", of: { k: "tunk" } }) } else { { k: "tunk" } }
            } else { e.typ }
        }
    } else if (k == "un") {
        if (node.op == "-") { infer(st, node.e) } else { { k: "tbool" } }
    } else if (k == "bin") {
        let op = node.op;
        if (op == "+" || op == "-" || op == "*" || op == "/" || op == "%") {
            let bl = infer(st, node.l);
            let br = infer(st, node.r);
            if (op == "+" && (bl.k == "tstr" || br.k == "tstr")) {
                { k: "tstr" }
            } else if (bl.k == "tfloat") {
                { k: "tfloat" }
            } else if (br.k == "tfloat") {
                { k: "tfloat" }
            } else {
                { k: "tlong" }
            }
        } else {
            { k: "tbool" }
        }
    } else if (k == "func") {
        normnode(func_type_in(st, node))
    } else if (k == "addr") {
        normnode({ k: "tptr", to: infer(st, node.e) })
    } else if (k == "arrrep") {
        normnode({ k: "tarrfix", of: infer(st, node.v), n: node.n })
    } else if (k == "array") {
        let elems = node.elems;
        if (len(elems) == 0) {
            normnode({ k: "tarr", of: { k: "tunk" } })
        } else {
            normnode({ k: "tarr", of: infer(st, elems[0]) })
        }
    } else if (k == "index") {
        if (node.arr.k == "id") {
            let e = env_find(st, node.arr.v);
            if (e.kind == "none") {
                { k: "tunk" }
            } else if (e.typ.k == "tarrfix" || e.typ.k == "tarr") {
                e.typ.of
            } else {
                { k: "tunk" }
            }
        } else {
            { k: "tunk" }
        }
    } else if (k == "slice") {
        let ts = infer(st, node.arr);
        if (ts.k == "tarr") { { k: "tarr", of: ts.of } }
        else if (ts.k == "tarrfix") { { k: "tarr", of: ts.of } }
        else { { k: "tunk" } }
    } else if (k == "deref") {
        let t = infer(st, node.e);
        if (t.k == "tptr") { t.to } else { { k: "tunk" } }
    } else if (k == "call") {
        infer_call(st, node)
    } else if (k == "if") {
        infer(st, node.then)
    } else if (k == "block") {
        infer_block(st, node)
    } else if (k == "decl") {
        infer_decl(st, node)
    } else if (k == "assign") {
        infer(st, node.v)
    } else if (k == "map") {
        let melems = node.vals;
        let mkeys = node.keys;
        if (len(melems) == 0) {
            normnode({ k: "trec", fields: [] })
        } else {
            let mfields = [];
            let mi = 0;
            while (mi < len(melems)) {
                let mf = infer(st, melems[mi]);
                let mk = mkeys[mi];
                mfields = push(mfields, { name: mk, typ: mf });
                mi = mi + 1;
            };
            normnode({ k: "trec", fields: mfields })
        }
    } else if (k == "dot") {
        let dobj = node.obj;
        let dt = infer(st, dobj);
        if (dt.k == "trec") {
            let found = false;
            let ftyp = { k: "tunk" };
            let dfs = dt.fields;
            let di = 0;
            while (di < len(dfs)) {
                let df = dfs[di];
                let dfn: str = df.name;
                if (dfn == node.key) {
                    found = true;
                    ftyp = df.typ;
                    0
                } else { 0; };
                di = di + 1;
            };
            if (found) { ftyp } else { { k: "tunk" } }
        } else {
            { k: "tunk" }
        }
    } else if (k == "store") {
        infer(st, node.v)
    } else if (k == "while") {
        { k: "tnull" }
    } else if (k == "ret") {
        infer(st, node.e)
    } else {
        { k: "tunk" }
    }
};

def infer_call(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { k: str } {
    if (node.callee.k != "id") {
        let cft = infer(st, node.callee);
        if (cft.k == "tfunc") { cft.ret } else { { k: "tunk" } }
    } else {
        let name = node.callee.v;
        if (name == "print") {
            { k: "tnull" }
        } else if (name == "syscall") {
            { k: "tlong" }
        } else if (name == "len") {
            { k: "tlong" }
        } else if (name == "is_some") {
            { k: "tbool" }
        } else if (name == "unwrap") {
            let uargs = node.args;
            if (len(uargs) != 1) { { k: "tunk" } } else {
                let ut = infer(st, uargs[0]);
                if (ut.k == "topt") { ut.of } else { { k: "tunk" } }
            }
        } else if (name == "some") {
            let sargs = node.args;
            if (len(sargs) != 1) { { k: "topt", of: { k: "tunk" } } } else {
                { k: "topt", of: infer(st, sargs[0]) }
            }
        } else if (name == "substr" || name == "trim" || name == "chr" || name == "join" || name == "tostring" || name == "typeof") {
            { k: "tstr" }
        } else if (name == "read_file") {
            { k: "topt", of: { k: "tstr" } }
        } else if (name == "bytes") {
            { k: "tarr", of: { k: "tbyte" } }
        } else if (name == "from_bytes") {
            { k: "tstr" }
        } else if (name == "ptr_addr") {
            { k: "tlong" }
        } else if (name == "tonum" || name == "ord" || name == "index_of" || name == "last_index_of") {
            { k: "tlong" }
        } else if (name == "clock_us" || name == "heap_used") {
            { k: "tlong" }
        } else if (name == "sleep") {
            { k: "tnull" }
        } else if (name == "split" || name == "argv") {
            { k: "tarr", of: { k: "tstr" } }
        } else if (name == "range") {
            { k: "tarr", of: { k: "tlong" } }
        } else if (name == "write_file") {
            { k: "tbool" }
        } else if (name == "write_bytes") {
            { k: "tbool" }
        } else if (name == "puts" || name == "exit") {
            { k: "tnull" }
        } else if (name == "eputs") {
            { k: "tnull" }
        } else {
            let e = env_find(st, name);
            if (e.kind == "none") {
                { k: "tunk" }
            } else if (e.typ.k == "tfunc") {
                e.typ.ret
            } else {
                { k: "tunk" }
            }
        }
    }
};

def infer_block(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { k: str } {
    let stmts = node.stmts;
    if (len(stmts) == 0) {
        { k: "tnull" }
    } else {
        infer(st, stmts[len(stmts) - 1])
    }
};

def infer_decl(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { k: str } {
    if (node.kind == "def") {
        { k: "tfunc", args: [], ret: { k: "tnull" } }
    } else {
        if (node.typ.k == "tnone") {
            infer(st, node.v)
        } else {
            node.typ
        }
    }
};


def uses_scan_block(stmts: [{ k: str }], out: { argv: bool }) -> { argv: bool } {
    let i = 0;
    while (i < len(stmts)) {
        out = uses_scan_node(stmts[i], out);
        i = i + 1;
    };
    out
};

def uses_scan_node(node, out: { argv: bool }) -> { argv: bool } {
    let k = node.k;
    if (k == "call") {
        let ncallee = node.callee;
        let nargs = node.args;
        let found = out;
        if (ncallee.k == "id") {
            if (ncallee.v == "argv") {
                found = { argv: true };
                0
            } else { 0; };
            0
        } else { 0; };
        let o2 = uses_scan_node(ncallee, found);
        uses_scan_block(nargs, o2)
    } else if (k == "un") {
        uses_scan_node(node.e, out)
    } else if (k == "bin") {
        uses_scan_node(node.r, uses_scan_node(node.l, out))
    } else if (k == "addr" || k == "deref") {
        uses_scan_node(node.e, out)
    } else if (k == "if") {
        uses_scan_node(node.els, uses_scan_node(node.then, uses_scan_node(node.cond, out)))
    } else if (k == "while") {
        uses_scan_node(node.body, uses_scan_node(node.cond, out))
    } else if (k == "block") {
        uses_scan_block(node.stmts, out)
    } else if (k == "decl") {
        uses_scan_node(node.v, out)
    } else if (k == "func") {
        uses_scan_node(node.body, out)
    } else if (k == "assign") {
        uses_scan_node(node.v, out)
    } else if (k == "store") {
        uses_scan_node(node.v, uses_scan_node(node.p, out))
    } else if (k == "ret") {
        uses_scan_node(node.e, out)
    } else if (k == "array") {
        uses_scan_block(node.elems, out)
    } else if (k == "arrrep") {
        uses_scan_node(node.v, out)
    } else if (k == "map") {
        uses_scan_block(node.vals, out)
    } else if (k == "index") {
        uses_scan_node(node.idx, uses_scan_node(node.arr, out))
    } else if (k == "slice") {
        uses_scan_node(node.hi, uses_scan_node(node.lo, uses_scan_node(node.arr, out)))
    } else if (k == "idxassign") {
        uses_scan_node(node.v, uses_scan_node(node.idx, uses_scan_node(node.arr, out)))
    } else if (k == "dotassign") {
        uses_scan_node(node.v, uses_scan_node(node.obj, out))
    } else if (k == "foreach") {
        uses_scan_node(node.body, uses_scan_node(node.iter, out))
    } else if (k == "forrange") {
        uses_scan_node(node.body, uses_scan_node(node.hi, uses_scan_node(node.lo, out)))
    } else if (k == "for") {
        uses_scan_node(node.body, uses_scan_node(node.step, uses_scan_node(node.cond, uses_scan_node(node.init, out))))
    } else {
        out
    }
};


def collect_from_block(stmts: [{ k: str }], out: [{ name: str, func: { k: str } }]) -> [{ name: str, func: { k: str } }] {
    let i = 0;
    while (i < len(stmts)) {
        out = collect_from_node(stmts[i], out);
        i = i + 1;
    };
    out
};

def collect_from_node(node, out: [{ name: str, func: { k: str } }]) -> [{ name: str, func: { k: str } }] {
    let k = node.k;
    if (k == "decl") {
        if (node.kind == "def") {
            out = push(out, { name: node.name, func: node.v });
            out = collect_from_node(node.v, out);
            0
        } else {
            if (node.v.k == "func") {
                out = push(out, { name: node.name, func: node.v });
                0
            } else { 0; };
            out = collect_from_node(node.v, out);
            0
        }
    } else if (k == "func") {
        out = collect_from_block(node.body.stmts, out);
        0
    } else if (k == "if") {
        out = collect_from_node(node.then, out);
        if (node.has_else) {
            out = collect_from_node(node.els, out);
            0
        } else { 0; };
        0
    } else if (k == "while") {
        out = collect_from_node(node.body, out);
        0
    } else if (k == "for") {
        out = collect_from_node(node.init, out);
        out = collect_from_node(node.body, out);
        out = collect_from_node(node.step, out);
        0
    } else if (k == "foreach") {
        out = collect_from_node(node.body, out);
        0
    } else if (k == "forrange") {
        out = collect_from_node(node.body, out);
        0
    } else if (k == "block") {
        out = collect_from_block(node.stmts, out);
        0
    } else { 0; };
    out
};


def name_in(xs: [str], n: str) -> bool {
    let i = 0;
    let found = false;
    while (i < len(xs)) {
        let x: str = xs[i];
        if (x == n) { found = true; 0; } else { 0; };
        i = i + 1;
    };
    found
};

def is_intrinsic_name(n: str) -> bool {
    name_in(["print", "syscall", "len", "push", "some", "is_some", "unwrap",
             "substr", "trim", "ord", "chr", "tonum", "tostring", "index_of",
             "last_index_of", "join", "split", "puts", "eputs", "clock_us",
             "sleep", "heap_used", "exit", "argv", "read_file", "write_file",
             "write_bytes", "range", "typeof", "bytes",
             "from_bytes", "ptr_addr", "self", "none"], n)
};

def fv_ids(node, out: [str]) -> [str] {
    let k = node.k;
    if (k == "id") {
        out = push(out, node.v);
        0
    } else if (k == "un") {
        out = fv_ids(node.e, out);
        0
    } else if (k == "addr") {
        out = fv_ids(node.e, out);
        0
    } else if (k == "deref") {
        out = fv_ids(node.e, out);
        0
    } else if (k == "ret") {
        out = fv_ids(node.e, out);
        0
    } else if (k == "bin") {
        out = fv_ids(node.l, out);
        out = fv_ids(node.r, out);
        0
    } else if (k == "array") {
        out = fv_ids_list(node.elems, out);
        0
    } else if (k == "map") {
        out = fv_ids_list(node.vals, out);
        0
    } else if (k == "arrrep") {
        out = fv_ids(node.v, out);
        0
    } else if (k == "call") {
        out = fv_ids(node.callee, out);
        out = fv_ids_list(node.args, out);
        0
    } else if (k == "index") {
        out = fv_ids(node.arr, out);
        out = fv_ids(node.idx, out);
        0
    } else if (k == "slice") {
        out = fv_ids(node.arr, out);
        out = fv_ids(node.lo, out);
        out = fv_ids(node.hi, out);
        0
    } else if (k == "idxassign") {
        out = fv_ids(node.arr, out);
        out = fv_ids(node.idx, out);
        out = fv_ids(node.v, out);
        0
    } else if (k == "dot") {
        out = fv_ids(node.obj, out);
        0
    } else if (k == "dotassign") {
        out = fv_ids(node.obj, out);
        out = fv_ids(node.v, out);
        0
    } else if (k == "store") {
        out = fv_ids(node.p, out);
        out = fv_ids(node.v, out);
        0
    } else if (k == "assign") {
        out = push(out, node.name);
        out = fv_ids(node.v, out);
        0
    } else if (k == "decl") {
        out = fv_ids(node.v, out);
        0
    } else if (k == "if") {
        out = fv_ids(node.cond, out);
        out = fv_ids(node.then, out);
        if (node.has_else) {
            out = fv_ids(node.els, out);
            0
        } else { 0; };
        0
    } else if (k == "while") {
        out = fv_ids(node.cond, out);
        out = fv_ids(node.body, out);
        0
    } else if (k == "for") {
        out = fv_ids(node.init, out);
        out = fv_ids(node.cond, out);
        out = fv_ids(node.step, out);
        out = fv_ids(node.body, out);
        0
    } else if (k == "foreach") {
        out = fv_ids(node.iter, out);
        out = fv_ids(node.body, out);
        0
    } else if (k == "forrange") {
        out = fv_ids(node.lo, out);
        out = fv_ids(node.hi, out);
        out = fv_ids(node.body, out);
        0
    } else if (k == "block") {
        out = fv_ids_list(node.stmts, out);
        0
    } else if (k == "func") {
        out = fv_ids(node.body, out);
        0
    } else { 0; };
    out
};

def fv_ids_list(nodes: [{ k: str }], out: [str]) -> [str] {
    let i = 0;
    while (i < len(nodes)) {
        out = fv_ids(nodes[i], out);
        i = i + 1;
    };
    out
};

def fv_binds(node, out: [str]) -> [str] {
    let k = node.k;
    if (k == "decl") {
        out = push(out, node.name);
        out = fv_binds(node.v, out);
        0
    } else if (k == "func") {
        out = fv_bind_params(node.params, out);
        out = fv_binds(node.body, out);
        0
    } else if (k == "block") {
        out = fv_binds_list(node.stmts, out);
        0
    } else if (k == "if") {
        out = fv_binds(node.cond, out);
        out = fv_binds(node.then, out);
        if (node.has_else) {
            out = fv_binds(node.els, out);
            0
        } else { 0; };
        0
    } else if (k == "while") {
        out = fv_binds(node.cond, out);
        out = fv_binds(node.body, out);
        0
    } else if (k == "for") {
        out = fv_binds(node.init, out);
        out = fv_binds(node.cond, out);
        out = fv_binds(node.step, out);
        out = fv_binds(node.body, out);
        0
    } else if (k == "foreach") {
        out = push(out, node.name);
        out = fv_binds(node.iter, out);
        out = fv_binds(node.body, out);
        0
    } else if (k == "forrange") {
        out = push(out, node.name);
        out = fv_binds(node.lo, out);
        out = fv_binds(node.hi, out);
        out = fv_binds(node.body, out);
        0
    } else if (k == "ret") {
        out = fv_binds(node.e, out);
        0
    } else if (k == "un") {
        out = fv_binds(node.e, out);
        0
    } else if (k == "addr") {
        out = fv_binds(node.e, out);
        0
    } else if (k == "deref") {
        out = fv_binds(node.e, out);
        0
    } else if (k == "bin") {
        out = fv_binds(node.l, out);
        out = fv_binds(node.r, out);
        0
    } else if (k == "array") {
        out = fv_binds_list(node.elems, out);
        0
    } else if (k == "map") {
        out = fv_binds_list(node.vals, out);
        0
    } else if (k == "arrrep") {
        out = fv_binds(node.v, out);
        0
    } else if (k == "call") {
        out = fv_binds(node.callee, out);
        out = fv_binds_list(node.args, out);
        0
    } else if (k == "index") {
        out = fv_binds(node.arr, out);
        out = fv_binds(node.idx, out);
        0
    } else if (k == "slice") {
        out = fv_binds(node.arr, out);
        out = fv_binds(node.lo, out);
        out = fv_binds(node.hi, out);
        0
    } else if (k == "idxassign") {
        out = fv_binds(node.arr, out);
        out = fv_binds(node.idx, out);
        out = fv_binds(node.v, out);
        0
    } else if (k == "dot") {
        out = fv_binds(node.obj, out);
        0
    } else if (k == "dotassign") {
        out = fv_binds(node.obj, out);
        out = fv_binds(node.v, out);
        0
    } else if (k == "store") {
        out = fv_binds(node.p, out);
        out = fv_binds(node.v, out);
        0
    } else if (k == "assign") {
        out = fv_binds(node.v, out);
        0
    } else { 0; };
    out
};

def fv_binds_list(nodes: [{ k: str }], out: [str]) -> [str] {
    let i = 0;
    while (i < len(nodes)) {
        out = fv_binds(nodes[i], out);
        i = i + 1;
    };
    out
};

def fn_captures(func, fnnames: [str]) -> [str] {
    let bound = fv_bind_params(func.params, fv_binds(func.body, []));
    let reads = fv_ids(func.body, []);
    let caps: [str] = [];
    let i = 0;
    while (i < len(reads)) {
        let n: str = reads[i];
        if (name_in(bound, n)) { 0; }
        else if (name_in(fnnames, n)) { 0; }
        else if (is_intrinsic_name(n)) { 0; }
        else if (name_in(caps, n)) { 0; }
        else {
            caps = push(caps, n);
            0
        };
        i = i + 1;
    };
    caps
};

def fv_bind_params(ps: [str], out: [str]) -> [str] {
    let i = 0;
    while (i < len(ps)) {
        let p: str = ps[i];
        out = push(out, p);
        i = i + 1;
    };
    out
};

def fn_names_of(fns: [{ name: str, label: str, typ: { k: str } }]) -> [str] {
    let out: [str] = [];
    let i = 0;
    while (i < len(fns)) {
        let e = fns[i];
        out = push(out, e.name);
        i = i + 1;
    };
    out
};

def fns_find(fns: [{ name: str, label: str, typ: { k: str } }], name: str) -> { name: str, label: str, typ: { k: str } } {
    let i = 0;
    let found = { name: "", label: "y_missing_" + name, typ: { k: "tnone" } };
    while (i < len(fns)) {
        let e = fns[i];
        if (e.name == name) {
            found = e;
            0
        } else { 0; };
        i = i + 1;
    };
    found
};


def gen(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }],     bodies: [str] } {
    let k = node.k;
    if (k == "num") {
        gen_lit(st, node)
    } else if (k == "bool") {
        if (node.v == "true") {
            emit(st, "    mov $1, %rax")
        } else {
            emit(st, "    xor %eax, %eax")
        }
    } else if (k == "str") {
        gen_str_const(st, node.v)
    } else if (k == "null") {
        emit(st, "    xor %eax, %eax")
    } else if (k == "id") {
        gen_id(st, node)
    } else if (k == "un") {
        gen_un(st, node)
    } else if (k == "addr") {
        gen_addr(st, node)
    } else if (k == "array") {
        gen_array(st, node)
    } else if (k == "deref") {
        st = gen(st, node.e);
        emit(st, "    mov (%rax), %rax")
    } else if (k == "bin") {
        gen_bin(st, node)
    } else if (k == "call") {
        gen_call(st, node)
    } else if (k == "if") {
        gen_if(st, node)
    } else if (k == "while") {
        gen_while(st, node)
    } else if (k == "for") {
        gen_for(st, node)
    } else if (k == "forrange") {
        gen_forrange(st, node)
    } else if (k == "foreach") {
        gen_foreach(st, node)
    } else if (k == "block") {
        gen_block(st, node)
    } else if (k == "decl") {
        gen_decl(st, node)
    } else if (k == "assign") {
        gen_assign(st, node)
    } else if (k == "index") {
        gen_index(st, node)
    } else if (k == "slice") {
        gen_slice(st, node)
    } else if (k == "idxassign") {
        gen_idxassign(st, node)
    } else if (k == "dotassign") {
        gen_dotassign(st, node)
    } else if (k == "dot") {
        gen_dot(st, node)
    } else if (k == "map") {
        gen_map(st, node)
    } else if (k == "arrrep") {
        gen_arrrep(st, node)
    } else if (k == "func") {
        gen_func_literal(st, node)
    } else if (k == "store") {
        gen_store(st, node)
    } else if (k == "ret") {
        st = gen(st, node.e);
        emit(st, "    jmp " + st.end_label)
    } else {
        emit(st, "    # INTERNAL: unhandled " + k + " (checker drift)")
    }
};

def gen_str_const(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, s: str) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let r = next_uid(st);
    st = r.st;
    let lbl = arch.arch_str_label(r.uid);
    let rod0 = [];
    rod0 = push(rod0, lbl);
    rod0 = push(rod0, tostring(len(s)));
    rod0 = push(rod0, esc_asm(s));
    let rod = push(st.rodata, rod0);
    st = { out: st.out, rodata: rod, uid: st.uid,
      fuid: st.fuid, loc: st.loc, env: st.env, slots: st.slots,
      self_label: st.self_label, end_label: st.end_label, fns: st.fns,
      bodies: st.bodies };
    emit(st, "    lea " + lbl + "(%rip), %rax")
};

def gen_id(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    if (node.v == "self") {
        emit(st, "    xor %eax, %eax  # bare self (discarded)")
    } else if (node.v == "none") {
        emit(st, "    xor %eax, %eax")
    } else {
        let e = env_find(st, node.v);
        if (e.kind == "none") {
            emit(st, "    # INTERNAL: undefined " + node.v)
        } else if (e.kind == "func") {
            gen_make_closure(st, e.label, [])
        } else if (e.kind == "capture") {
            let idx = tonum(e.label);
            st = emit(st, "    mov " + tostring(e.off) + "(%rbp), %rcx");
            emit(st, "    mov " + tostring(8 * (idx + 1)) + "(%rcx), %rax")
        } else {
            emit(st, "    mov " + tostring(e.off) + "(%rbp), %rax")
        }
    }
};


def gen_make_closure(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, label: str, caps: [str]) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let n = len(caps);
    st = emit(st, "    mov $" + tostring(8 + 8 * n) + ", %rdi");
    st = emit(st, "    call y_alloc");
    st = emit(st, "    push %rax");
    st = emit(st, "    lea " + label + "(%rip), %rcx");
    st = emit(st, "    mov %rcx, (%rax)");
    let i = 0;
    while (i < n) {
        let cn: str = caps[i];
        st = gen_id(st, { k: "id", v: cn, line: 0, col: 0 });
        st = emit(st, "    pop %rcx");
        st = emit(st, "    push %rcx");
        st = emit(st, "    mov %rax, " + tostring(8 * (i + 1)) + "(%rcx)");
        i = i + 1;
    };
    emit(st, "    pop %rax")
};

def gen_range(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    st = gen_push_args(st, node.args);
    st = emit(st, "    call y_range");
    emit(st, "    add $8, %rsp")
};

def gen_slice(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let lo = node.lo;
    let hi = node.hi;
    let slesz = arr_elem_bytes(infer(st, node.arr));
    st = gen(st, node.arr);
    st = emit(st, "    push %rax");
    if (lo.k == "null") {
        st = emit(st, "    xor %eax, %eax");
        0
    } else {
        st = gen(st, lo);
        0
    };
    st = emit(st, "    push %rax");
    if (hi.k == "null") {
        st = emit(st, "    mov 8(%rsp), %rax");
        st = emit(st, "    mov (%rax), %rax");
        0
    } else {
        st = gen(st, hi);
        0
    };
    st = emit(st, "    push %rax");
    st = emit(st, "    mov $" + tostring(slesz) + ", %rax");
    st = emit(st, "    push %rax");
    st = emit(st, "    call y_arr_slice");
    emit(st, "    add $32, %rsp")
};

def gen_indirect(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node, callee) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let args = node.args;
    let n = len(args);
    st = gen(st, callee);
    st = emit(st, "    push %rax");
    st = gen_push_args(st, args);
    st = emit(st, "    mov " + tostring(8 * n) + "(%rsp), %rax");
    st = emit(st, "    mov (%rax), %rax");
    st = emit(st, "    call *%rax");
    emit(st, "    add $" + tostring(8 * (n + 1)) + ", %rsp")
};

def gen_un(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let ut = infer(st, node.e);
    st = gen(st, node.e);
    if (node.op == "-") {
        if (ut.k == "tfloat") {
            st = emit(st, "    movq %rax, %xmm1");
            st = emit(st, "    xor %ecx, %ecx");
            st = emit(st, "    movq %rcx, %xmm0");
            st = emit(st, "    subsd %xmm1, %xmm0");
            emit(st, "    movq %xmm0, %rax")
        } else {
            emit(st, "    neg %rax")
        }
    } else {
        emit(st, "    xor $1, %rax")
    }
};

def gen_addr(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    if (node.e.k == "index") {
        gen_elem_addr(st, node.e)
    } else {
        let e = env_find(st, node.e.v);
        emit(st, "    lea " + tostring(e.off) + "(%rbp), %rax")
    }
};

def gen_elem_addr(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let e = env_find(st, node.arr.v);
    let eaesz = arr_elem_bytes(e.typ);
    let eascale = "8";
    if (eaesz == 1) { eascale = "1"; 0; } else { 0; };
    st = gen(st, node.idx);
    st = emit(st, "    push %rax");
    st = emit(st, "    mov " + tostring(e.off) + "(%rbp), %rax");
    st = emit(st, "    pop %rcx");
    st = emit(st, "    test %rcx, %rcx");
    st = emit(st, "    js y_oob");
    if (e.typ.k == "tarrfix") {
        st = emit(st, "    cmp $" + tostring(e.typ.n) + ", %rcx");
        st = emit(st, "    jge y_oob");
        emit(st, "    lea 16(%rax,%rcx," + eascale + "), %rax")
    } else {
        st = emit(st, "    mov (%rax), %rdx");
        st = emit(st, "    cmp %rdx, %rcx");
        st = emit(st, "    jge y_oob");
        emit(st, "    lea 16(%rax,%rcx," + eascale + "), %rax")
    }
};

def gen_bin(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let op = node.op;
    if (op == "&&") {
        gen_logic(st, node, false)
    } else if (op == "||") {
        gen_logic(st, node, true)
    } else {
        gen_bin_rest(st, node)
    }
};

def gen_logic(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node, is_or: bool) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let rT = next_loc(st);
    st = rT.st;
    let rF = next_loc(st);
    st = rF.st;
    let rE = next_loc(st);
    st = rE.st;
    st = gen(st, node.l);
    st = emit(st, "    test %rax, %rax");
    if (is_or) {
        st = emit(st, "    jnz " + rT.lbl);
        0
    } else { 0; };
    if (is_or) {
        0
    } else {
        st = emit(st, "    jz " + rF.lbl);
        0
    };
    st = gen(st, node.r);
    st = emit(st, "    test %rax, %rax");
    if (is_or) {
        st = emit(st, "    jnz " + rT.lbl);
        0
    } else { 0; };
    if (is_or) {
        0
    } else {
        st = emit(st, "    jz " + rF.lbl);
        0
    };
    if (is_or) {
        0
    } else {
        st = emit(st, "    mov $1, %rax");
        st = emit(st, "    jmp " + rE.lbl);
        0
    };
    if (is_or) {
        st = emit(st, "    xor %eax, %eax");
        st = emit(st, "    jmp " + rE.lbl);
        st = emit(st, rT.lbl + ":");
        st = emit(st, "    mov $1, %rax");
        0
    } else { 0; };
    if (is_or) {
        0
    } else {
        st = emit(st, rF.lbl + ":");
        st = emit(st, "    xor %eax, %eax");
        0
    };
    st = emit(st, rE.lbl + ":")
};

def gen_cat(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node, lt: { k: str }, rt: { k: str }) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    if (lt.k == "tstr") {
        if (rt.k == "tstr") {
            st = gen_push_args(st, [node.l, node.r]);
            st = emit(st, "    call y_str_cat");
            st = emit(st, "    add $16, %rsp")
        } else if (rt.k == "tlong") {
            st = gen(st, node.l);
            st = emit(st, "    push %rax");
            st = gen(st, node.r);
            st = emit(st, "    push %rax");
            st = emit(st, "    call y_long_tostr");
            st = emit(st, "    add $8, %rsp");
            st = emit(st, "    push %rax");
            st = emit(st, "    call y_str_cat");
            st = emit(st, "    add $16, %rsp")
        } else if (rt.k == "tbool") {
            st = gen(st, node.l);
            st = emit(st, "    push %rax");
            st = gen(st, node.r);
            st = emit(st, "    push %rax");
            st = emit(st, "    call y_bool_tostr");
            st = emit(st, "    add $8, %rsp");
            st = emit(st, "    push %rax");
            st = emit(st, "    call y_str_cat");
            st = emit(st, "    add $16, %rsp")
        } else if (rt.k == "tfloat") {
            st = gen(st, node.l);
            st = emit(st, "    push %rax");
            st = gen(st, node.r);
            st = emit(st, "    push %rax");
            st = emit(st, "    call y_float_tostr");
            st = emit(st, "    add $8, %rsp");
            st = emit(st, "    push %rax");
            st = emit(st, "    call y_str_cat");
            st = emit(st, "    add $16, %rsp")
        } else {
            st = gen_push_args(st, [node.l, node.r]);
            st = emit(st, "    call y_str_cat");
            st = emit(st, "    add $16, %rsp")
        };
        0
    } else { 0; };
    if (!(lt.k == "tstr")) {
        if (lt.k == "tlong") {
            st = gen(st, node.l);
            st = emit(st, "    push %rax");
            st = emit(st, "    call y_long_tostr");
            st = emit(st, "    add $8, %rsp");
            st = emit(st, "    push %rax");
            st = gen(st, node.r);
            st = emit(st, "    push %rax");
            st = emit(st, "    call y_str_cat");
            st = emit(st, "    add $16, %rsp")
        } else if (lt.k == "tbool") {
            st = gen(st, node.l);
            st = emit(st, "    push %rax");
            st = emit(st, "    call y_bool_tostr");
            st = emit(st, "    add $8, %rsp");
            st = emit(st, "    push %rax");
            st = gen(st, node.r);
            st = emit(st, "    push %rax");
            st = emit(st, "    call y_str_cat");
            st = emit(st, "    add $16, %rsp")
        } else if (lt.k == "tfloat") {
            st = gen(st, node.l);
            st = emit(st, "    push %rax");
            st = emit(st, "    call y_float_tostr");
            st = emit(st, "    add $8, %rsp");
            st = emit(st, "    push %rax");
            st = gen(st, node.r);
            st = emit(st, "    push %rax");
            st = emit(st, "    call y_str_cat");
            st = emit(st, "    add $16, %rsp")
        } else {
            st = gen_push_args(st, [node.l, node.r]);
            st = emit(st, "    call y_str_cat");
            st = emit(st, "    add $16, %rsp")
        };
        0
    } else { 0; };
    st
};

def gen_float_bin(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node, lt: { k: str }, rt: { k: str }) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let op = node.op;
    st = gen(st, node.l);
    if (lt.k == "tfloat") { 0; } else {
        st = emit(st, "    cvtsi2sd %rax, %xmm0");
        st = emit(st, "    movq %xmm0, %rax");
        0
    };
    st = emit(st, "    push %rax");
    st = gen(st, node.r);
    if (rt.k == "tfloat") { 0; } else {
        st = emit(st, "    cvtsi2sd %rax, %xmm0");
        st = emit(st, "    movq %xmm0, %rax");
        0
    };
    st = emit(st, "    movq %rax, %xmm1");
    st = emit(st, "    pop %rax");
    st = emit(st, "    movq %rax, %xmm0");
    if (op == "+") {
        st = emit(st, "    addsd %xmm1, %xmm0");
        emit(st, "    movq %xmm0, %rax")
    } else if (op == "-") {
        st = emit(st, "    subsd %xmm1, %xmm0");
        emit(st, "    movq %xmm0, %rax")
    } else if (op == "*") {
        st = emit(st, "    mulsd %xmm1, %xmm0");
        emit(st, "    movq %xmm0, %rax")
    } else if (op == "/") {
        st = emit(st, "    divsd %xmm1, %xmm0");
        emit(st, "    movq %xmm0, %rax")
    } else {
        st = emit(st, "    ucomisd %xmm1, %xmm0");
        if (op == "<") {
            st = emit(st, "    setb %al");
            0
        } else if (op == "<=") {
            st = emit(st, "    setbe %al");
            0
        } else if (op == ">") {
            st = emit(st, "    seta %al");
            0
        } else if (op == ">=") {
            st = emit(st, "    setae %al");
            0
        } else if (op == "==") {
            st = emit(st, "    sete %al");
            0
        } else {
            st = emit(st, "    setne %al");
            0
        };
        emit(st, "    movzbq %al, %rax")
    }
};

def gen_str_cmp(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node, op: str) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    st = gen_push_args(st, [node.l, node.r]);
    st = emit(st, "    call y_str_cmp");
    st = emit(st, "    add $16, %rsp");
    st = emit(st, "    cmp $0, %rax");
    if (op == "<") {
        st = emit(st, "    setl %al");
        0
    } else if (op == ">") {
        st = emit(st, "    setg %al");
        0
    } else if (op == "<=") {
        st = emit(st, "    setle %al");
        0
    } else {
        st = emit(st, "    setge %al");
        0
    };
    emit(st, "    movzbq %al, %rax")
};

def gen_bin_rest(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let op = node.op;
    let lt = infer(st, node.l);
    let rt = infer(st, node.r);
    if (op == "+" && (lt.k == "tstr" || rt.k == "tstr")) {
        gen_cat(st, node, lt, rt)
    } else if (lt.k == "tfloat" || rt.k == "tfloat") {
        gen_float_bin(st, node, lt, rt)
    } else if ((op == "==" || op == "!=") && (lt.k == "tstr" || rt.k == "tstr")) {
        st = gen_push_args(st, [node.l, node.r]);
        st = emit(st, "    call y_str_eq");
        st = emit(st, "    add $16, %rsp");
        if (op == "!=") {
            emit(st, "    xor $1, %rax")
        } else {
            st
        }
    } else if ((op == "<" || op == ">" || op == "<=" || op == ">=") && lt.k == "tstr") {
        gen_str_cmp(st, node, op)
    } else if ((op == "==" || op == "!=") && (lt.k == "tarr" || rt.k == "tarr")) {
        let elt = { k: "tunk" };
        if (lt.k == "tarr") { elt = lt.of; 0; } else { 0; };
        if (elt.k == "tunk") {
            if (rt.k == "tarr") { elt = rt.of; 0; } else { 0; };
            0
        } else { 0; };
        st = gen_push_args(st, [node.l, node.r]);
        if (elt.k == "tstr") {
            st = emit(st, "    call y_arr_eq_str");
            st = emit(st, "    add $16, %rsp");
            0
        } else {
            st = emit(st, "    mov $" + tostring(elem_bytes(elt)) + ", %rax");
            st = emit(st, "    push %rax");
            st = emit(st, "    call y_arr_eq");
            st = emit(st, "    add $24, %rsp");
            0
        };
        if (op == "!=") {
            emit(st, "    xor $1, %rax")
        } else {
            st
        }
    } else {
    st = gen(st, node.l);
    st = emit(st, "    push %rax");
    st = gen(st, node.r);
    st = emit(st, "    mov %rax, %rcx");
    st = emit(st, "    pop %rax");
    if (op == "+") {
        emit(st, "    add %rcx, %rax")
    } else if (op == "-") {
        emit(st, "    sub %rcx, %rax")
    } else if (op == "*") {
        emit(st, "    imul %rcx, %rax")
    } else if (op == "/") {
        st = emit(st, "    test %rcx, %rcx");
        st = emit(st, "    jz y_div_zero");
        let d1 = next_loc(st);
        st = d1.st;
        let d2 = next_loc(st);
        st = d2.st;
        st = emit(st, "    cmp $-1, %rcx");
        st = emit(st, "    jne " + d1.lbl);
        st = emit(st, "    neg %rax");
        st = emit(st, "    jmp " + d2.lbl);
        st = emit(st, d1.lbl + ":");
        st = emit(st, "    cqo");
        st = emit(st, "    idiv %rcx");
        emit(st, d2.lbl + ":")
    } else if (op == "%") {
        st = emit(st, "    test %rcx, %rcx");
        st = emit(st, "    jz y_div_zero");
        let m1 = next_loc(st);
        st = m1.st;
        let m2 = next_loc(st);
        st = m2.st;
        st = emit(st, "    cmp $-1, %rcx");
        st = emit(st, "    jne " + m1.lbl);
        st = emit(st, "    xor %eax, %eax");
        st = emit(st, "    jmp " + m2.lbl);
        st = emit(st, m1.lbl + ":");
        st = emit(st, "    cqo");
        st = emit(st, "    idiv %rcx");
        st = emit(st, "    mov %rdx, %rax");
        emit(st, m2.lbl + ":")
    } else if (op == "<") {
        st = emit(st, "    cmp %rcx, %rax");
        st = emit(st, "    setl %al");
        emit(st, "    movzbq %al, %rax")
    } else if (op == ">") {
        st = emit(st, "    cmp %rcx, %rax");
        st = emit(st, "    setg %al");
        emit(st, "    movzbq %al, %rax")
    } else if (op == "<=") {
        st = emit(st, "    cmp %rcx, %rax");
        st = emit(st, "    setle %al");
        emit(st, "    movzbq %al, %rax")
    } else if (op == ">=") {
        st = emit(st, "    cmp %rcx, %rax");
        st = emit(st, "    setge %al");
        emit(st, "    movzbq %al, %rax")
    } else if (op == "==") {
        st = emit(st, "    cmp %rcx, %rax");
        st = emit(st, "    sete %al");
        emit(st, "    movzbq %al, %rax")
    } else if (op == "!=") {
        st = emit(st, "    cmp %rcx, %rax");
        st = emit(st, "    setne %al");
        emit(st, "    movzbq %al, %rax")
    } else if (op == "&&") {
        emit(st, "    and %rcx, %rax")
    } else {
        emit(st, "    or %rcx, %rax")
    }
    }
};


def syscall_reg(i: long) -> str {
    if (i == 0) { "%rdi" }
    else if (i == 1) { "%rsi" }
    else if (i == 2) { "%rdx" }
    else if (i == 3) { "%r10" }
    else if (i == 4) { "%r8" }
    else { "%r9" }
};

def gen_push_args(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, args: [{ k: str }]) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let i = 0;
    while (i < len(args)) {
        st = gen(st, args[i]);
        st = emit(st, "    push %rax");
        i = i + 1;
    };
    st
};

def gen_call(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let callee = node.callee;
    if (callee.k != "id") {
        gen_indirect(st, node, callee)
    } else {
        let name = callee.v;
        if (name == "print") {
            gen_print(st, node)
        } else if (name == "syscall") {
            gen_syscall(st, node)
        } else if (name == "len") {
            gen_len(st, node)
        } else if (name == "range") {
            gen_range(st, node)
        } else if (name == "push") {
            gen_push(st, node)
        } else if (name == "some") {
            gen_some(st, node)
        } else if (name == "is_some") {
            gen_is_some(st, node)
        } else if (name == "unwrap") {
            gen_unwrap(st, node)
        } else if (name == "substr") {
            gen_substr(st, node)
        } else if (name == "trim") {
            gen_trim(st, node)
        } else if (name == "ord") {
            gen_ord(st, node)
        } else if (name == "chr") {
            gen_chr(st, node)
        } else if (name == "tonum") {
            gen_tonum(st, node)
        } else if (name == "tostring") {
            gen_tostring(st, node)
        } else if (name == "typeof") {
            gen_typeof(st, node)
        } else if (name == "index_of") {
            gen_index_of(st, node, false)
        } else if (name == "last_index_of") {
            gen_index_of(st, node, true)
        } else if (name == "join") {
            gen_join(st, node)
        } else if (name == "split") {
            gen_split(st, node)
        } else if (name == "puts") {
            gen_puts(st, node)
        } else if (name == "eputs") {
            gen_eputs(st, node)
        } else if (name == "clock_us") {
            gen_clock_us(st, node)
        } else if (name == "sleep") {
            gen_sleep(st, node)
        } else if (name == "heap_used") {
            gen_heap_used(st, node)
        } else if (name == "exit") {
            gen_exit(st, node)
        } else if (name == "argv") {
            gen_argv(st, node)
        } else if (name == "read_file") {
            gen_read_file(st, node)
        } else if (name == "bytes") {
            st = gen_push_args(st, node.args);
            st = emit(st, "    call y_str_to_bytes");
            emit(st, "    add $8, %rsp")
        } else if (name == "from_bytes") {
            st = gen_push_args(st, node.args);
            st = emit(st, "    call y_bytes_to_str");
            emit(st, "    add $8, %rsp")
        } else if (name == "ptr_addr") {
            let paargs = node.args;
            gen(st, paargs[0])
        } else if (name == "write_file") {
            gen_write_file(st, node)
        } else if (name == "write_bytes") {
            gen_write_bytes(st, node)
        } else {
            gen_direct(st, node, name)
        }
    }
};

def gen_print(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let args = node.args;
    let pa0 = args[0];
    let t = infer(st, pa0);
    if (t.k == "trec") {
        st = gen_rec_str(st, pa0, t);
        st = emit(st, "    mov %rax, %rdi");
        st = emit(st, "    call y_print_hstr");
        emit(st, "    xor %eax, %eax")
    } else if (t.k == "tfunc") {
        st = gen(st, pa0);
        st = gen_str_const(st, "<function " + types.tdisp_fnval(t) + ">");
        st = emit(st, "    mov %rax, %rdi");
        st = emit(st, "    call y_print_hstr");
        emit(st, "    xor %eax, %eax")
    } else {
        gen_print_scalar(st, pa0, t)
    }
};

def gen_print_scalar(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, arg, t) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    st = gen(st, arg);
    st = emit(st, "    mov %rax, %rdi");
    if (t.k == "tbool") {
        st = emit(st, "    call y_print_bool");
        emit(st, "    xor %eax, %eax")
    } else if (t.k == "tstr") {
        st = emit(st, "    call y_print_hstr");
        emit(st, "    xor %eax, %eax")
    } else if (t.k == "tfloat") {
        st = emit(st, "    call y_print_float");
        emit(st, "    xor %eax, %eax")
    } else {
        st = emit(st, "    call y_print_long");
        emit(st, "    xor %eax, %eax")
    }
};

def gen_typeof(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let targs = node.args;
    gen_str_const(st, types.tdisp(infer(st, targs[0])))
};


def gen_rec_str(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, arg, t) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    st = gen(st, arg);
    st = emit(st, "    push %rax");
    st = gen_str_const(st, "{");
    st = emit(st, "    push %rax");
    let fs = t.fields;
    let i = 0;
    while (i < len(fs)) {
        let f = fs[i];
        let sep = "";
        if (i > 0) { sep = ", "; 0; } else { 0; };
        st = gen_acc_cat_const(st, sep + f.name + ": ");
        st = gen_rec_field_str(st, i, f.typ);
        i = i + 1;
        0
    };
    st = gen_acc_cat_const(st, "}");
    st = emit(st, "    mov (%rsp), %rax");
    emit(st, "    add $16, %rsp")
};

def gen_acc_cat_const(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, s: str) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    st = emit(st, "    mov (%rsp), %rax");
    st = emit(st, "    push %rax");
    st = gen_str_const(st, s);
    st = emit(st, "    push %rax");
    st = emit(st, "    call y_str_cat");
    st = emit(st, "    add $16, %rsp");
    emit(st, "    mov %rax, (%rsp)")
};

def gen_rec_field_str(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, idx: long, ft) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let fk = ft.k;
    if (fk == "tstr") {
        st = emit(st, "    mov 8(%rsp), %rcx");
        st = emit(st, "    mov " + tostring(8 * idx) + "(%rcx), %rdx")
    } else if (fk == "tlong") {
        st = emit(st, "    mov 8(%rsp), %rcx");
        st = emit(st, "    mov " + tostring(8 * idx) + "(%rcx), %rax");
        st = emit(st, "    push %rax");
        st = emit(st, "    call y_long_tostr");
        st = emit(st, "    add $8, %rsp");
        st = emit(st, "    mov %rax, %rdx")
    } else if (fk == "tbool") {
        st = emit(st, "    mov 8(%rsp), %rcx");
        st = emit(st, "    mov " + tostring(8 * idx) + "(%rcx), %rax");
        st = emit(st, "    push %rax");
        st = emit(st, "    call y_bool_tostr");
        st = emit(st, "    add $8, %rsp");
        st = emit(st, "    mov %rax, %rdx")
    } else if (fk == "tfloat") {
        st = emit(st, "    mov 8(%rsp), %rcx");
        st = emit(st, "    mov " + tostring(8 * idx) + "(%rcx), %rax");
        st = emit(st, "    push %rax");
        st = emit(st, "    call y_float_tostr");
        st = emit(st, "    add $8, %rsp");
        st = emit(st, "    mov %rax, %rdx")
    } else if (fk == "tfunc") {
        st = gen_str_const(st, "<function " + types.tdisp_fnval(ft) + ">");
        st = emit(st, "    mov %rax, %rdx")
    } else {
        st = gen_str_const(st, "<" + types.tdisp(ft) + ">");
        st = emit(st, "    mov %rax, %rdx")
    };
    st = emit(st, "    mov (%rsp), %rax");
    st = emit(st, "    push %rax");
    st = emit(st, "    push %rdx");
    st = emit(st, "    call y_str_cat");
    st = emit(st, "    add $16, %rsp");
    emit(st, "    mov %rax, (%rsp)")
};

def gen_syscall(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let args = node.args;
    st = gen_push_args(st, args);
    let n = len(args) - 1;
    let i = n;
    while (i >= 1) {
        st = emit(st, "    pop " + syscall_reg(i - 1));
        let at = infer(st, args[i]);
        if (at.k == "tstr") {
            st = emit(st, "    add $8, " + syscall_reg(i - 1));
            0
        } else { 0; };
        i = i - 1;
    };
    st = emit(st, "    pop %rax");
    emit(st, "    syscall")
};

def gen_direct(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node, name: str) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let label = "";
    let indirect = false;
    if (name == "self") {
        label = st.self_label;
        0
    } else {
        let e = env_find(st, name);
        if (e.kind == "none") {
            label = "y_missing_" + name;
            0
        } else if (e.kind == "func") {
            label = e.label;
            0
        } else {
            indirect = true;
            0
        };
        0
    };
    if (indirect) {
        gen_indirect(st, node, node.callee)
    } else {
        st = gen_push_args(st, node.args);
        st = emit(st, "    call " + label);
        let nbytes = len(node.args) * 8;
        if (nbytes == 0) {
            st
        } else {
            emit(st, "    add $" + tostring(nbytes) + ", %rsp")
        }
    }
};


def gen_if(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let r1 = next_loc(st);
    st = r1.st;
    let r2 = next_loc(st);
    st = r2.st;
    st = gen(st, node.cond);
    st = emit(st, "    test %rax, %rax");
    st = emit(st, "    jz " + r1.lbl);
    st = gen(st, node.then);
    if (node.has_else) {
        st = emit(st, "    jmp " + r2.lbl);
        st = emit(st, r1.lbl + ":");
        st = gen(st, node.els);
        emit(st, r2.lbl + ":")
    } else {
        emit(st, r1.lbl + ":")
    }
};

def gen_while(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let r1 = next_loc(st);
    st = r1.st;
    let r2 = next_loc(st);
    st = r2.st;
    st = emit(st, r1.lbl + ":");
    st = gen(st, node.cond);
    st = emit(st, "    test %rax, %rax");
    st = emit(st, "    jz " + r2.lbl);
    st = gen(st, node.body);
    st = emit(st, "    jmp " + r1.lbl);
    st = emit(st, r2.lbl + ":");
    emit(st, "    xor %eax, %eax")
};


def gen_for(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    st = gen(st, node.init);
    let r1 = next_loc(st);
    st = r1.st;
    let r2 = next_loc(st);
    st = r2.st;
    st = emit(st, r1.lbl + ":");
    st = gen(st, node.cond);
    st = emit(st, "    test %rax, %rax");
    st = emit(st, "    jz " + r2.lbl);
    st = gen(st, node.body);
    st = gen(st, node.step);
    st = emit(st, "    jmp " + r1.lbl);
    st = emit(st, r2.lbl + ":");
    emit(st, "    xor %eax, %eax")
};

def gen_forrange(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let voff = (st.slots + 1) * -8;
    let loff = (st.slots + 2) * -8;
    st = { out: st.out, rodata: st.rodata, uid: st.uid,
      fuid: st.fuid, loc: st.loc, env: st.env, slots: st.slots + 2,
      self_label: st.self_label, end_label: st.end_label, fns: st.fns,
      bodies: st.bodies };
    st = gen(st, node.hi);
    st = emit(st, "    mov %rax, " + tostring(loff) + "(%rbp)");
    st = gen(st, node.lo);
    st = emit(st, "    mov %rax, " + tostring(voff) + "(%rbp)");
    st = env_define(st, node.name, "local", voff, "", { k: "tlong" });
    let r1 = next_loc(st);
    st = r1.st;
    let r2 = next_loc(st);
    st = r2.st;
    st = emit(st, r1.lbl + ":");
    st = emit(st, "    mov " + tostring(voff) + "(%rbp), %rax");
    st = emit(st, "    mov " + tostring(loff) + "(%rbp), %rcx");
    st = emit(st, "    cmp %rcx, %rax");
    st = emit(st, "    jge " + r2.lbl);
    st = gen(st, node.body);
    st = emit(st, "    mov " + tostring(voff) + "(%rbp), %rax");
    st = emit(st, "    inc %rax");
    st = emit(st, "    mov %rax, " + tostring(voff) + "(%rbp)");
    st = emit(st, "    jmp " + r1.lbl);
    st = emit(st, r2.lbl + ":");
    emit(st, "    xor %eax, %eax")
};

def gen_foreach(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let voff = (st.slots + 1) * -8;
    let aoff = (st.slots + 2) * -8;
    let ioff = (st.slots + 3) * -8;
    st = { out: st.out, rodata: st.rodata, uid: st.uid,
      fuid: st.fuid, loc: st.loc, env: st.env, slots: st.slots + 3,
      self_label: st.self_label, end_label: st.end_label, fns: st.fns,
      bodies: st.bodies };
    let elt = infer(st, node.iter);
    let eltyp = { k: "tunk" };
    if (elt.k == "tarr") { eltyp = elt.of; 0; } else { 0; };
    if (elt.k == "tarrfix") { eltyp = elt.of; 0; } else { 0; };
    st = gen(st, node.iter);
    st = emit(st, "    mov %rax, " + tostring(aoff) + "(%rbp)");
    st = emit(st, "    xor %eax, %eax");
    st = emit(st, "    mov %rax, " + tostring(ioff) + "(%rbp)");
    st = env_define(st, node.name, "local", voff, "", eltyp);
    let r1 = next_loc(st);
    st = r1.st;
    let r2 = next_loc(st);
    st = r2.st;
    st = emit(st, r1.lbl + ":");
    st = emit(st, "    mov " + tostring(aoff) + "(%rbp), %rdx");
    st = emit(st, "    mov (%rdx), %rcx");
    st = emit(st, "    mov " + tostring(ioff) + "(%rbp), %rax");
    st = emit(st, "    cmp %rcx, %rax");
    st = emit(st, "    jge " + r2.lbl);
    st = emit(st, elem_load(arr_elem_bytes(elt), "%rdx", "%rax", "%rcx"));
    st = emit(st, "    mov %rcx, " + tostring(voff) + "(%rbp)");
    st = gen(st, node.body);
    st = emit(st, "    mov " + tostring(ioff) + "(%rbp), %rax");
    st = emit(st, "    inc %rax");
    st = emit(st, "    mov %rax, " + tostring(ioff) + "(%rbp)");
    st = emit(st, "    jmp " + r1.lbl);
    st = emit(st, r2.lbl + ":");
    emit(st, "    xor %eax, %eax")
};

def gen_block(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {    let stmts = node.stmts;
    if (len(stmts) == 0) {
        emit(st, "    xor %eax, %eax")
    } else {
        let i = 0;
        while (i < len(stmts)) {
            st = gen(st, stmts[i]);
            i = i + 1;
        };
        st
    }
};

def gen_map(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let mvals = node.vals;
    let mkeys = node.keys;
    let n = len(mvals);
    let ru = next_uid(st);
    st = ru.st;
    let tlbl = "ytd_" + tostring(ru.uid);
    let te = [];
    te = push(te, tlbl);
    te = push(te, "TABLE");
    te = push(te, "1498307412");
    te = push(te, tostring(n));
    let j = 0;
    while (j < n) {
        let nm: str = mkeys[j];
        te = push(te, tostring(8 * j));
        let nl = len(nm);
        te = push(te, tostring(nl));
        let c = 0;
        while (c < nl) {
            let ch = substr(nm, c, 1);
            let co = ord(ch);
            te = push(te, tostring(co));
            c = c + 1;
        };
        j = j + 1;
    };
    let trod = push(st.rodata, te);
    st = { out: st.out, rodata: trod, uid: st.uid,
      fuid: st.fuid, loc: st.loc, env: st.env, slots: st.slots,
      self_label: st.self_label, end_label: st.end_label, fns: st.fns,
      bodies: st.bodies };
    st = emit(st, "    mov $" + tostring(8 * n + 16) + ", %rdi");
    st = emit(st, "    call y_alloc");
    st = emit(st, "    push %rax");
    st = emit(st, "    lea " + tlbl + "(%rip), %rax");
    st = emit(st, "    pop %rcx");
    st = emit(st, "    mov %rax, 0(%rcx)");
    st = emit(st, "    push %rcx");
    let i = 0;
    while (i < n) {
        let mv = mvals[i];
        st = gen(st, mv);
        st = emit(st, "    pop %rcx");
        st = emit(st, "    mov %rax, " + tostring(8 + i * 8) + "(%rcx)");
        st = emit(st, "    push %rcx");
        i = i + 1;
    };
    st = emit(st, "    pop %rax");
    emit(st, "    add $8, %rax")
};

def gen_func_literal(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let caps = fn_captures(node, fn_names_of(st.fns));
    let captypes: [{ k: str }] = [];
    let ci = 0;
    while (ci < len(caps)) {
        let cn: str = caps[ci];
        let ce = env_find(st, cn);
        captypes = push(captypes, ce.typ);
        ci = ci + 1;
    };
    let rl = next_uid(st);
    st = rl.st;
    let lbl = arch.arch_fn_label(rl.uid, "anon");
    let ru = next_uid(st);
    st = ru.st;
    st = emit_one_fn(st, lbl, ru.uid, node, false, false, captypes);
    gen_make_closure(st, lbl, caps)
};

def gen_closure_binding(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, name: str, func, caps: [str]) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let fe = fns_find(st.fns, name);
    let captypes: [{ k: str }] = [];
    let ci = 0;
    while (ci < len(caps)) {
        let cn2: str = caps[ci];
        let ce = env_find(st, cn2);
        captypes = push(captypes, ce.typ);
        ci = ci + 1;
    };
    let ru = next_uid(st);
    st = ru.st;
    st = emit_one_fn(st, fe.label, ru.uid, func, false, false, captypes);
    st = gen_make_closure(st, fe.label, caps);
    let coff = (st.slots + 1) * -8;
    st = emit(st, "    mov %rax, " + tostring(coff) + "(%rbp)");
    let st3 = { out: st.out, rodata: st.rodata, uid: st.uid,
      fuid: st.fuid, loc: st.loc, env: st.env, slots: st.slots + 1,
      self_label: st.self_label, end_label: st.end_label, fns: st.fns,
      bodies: st.bodies };
    env_define(st3, name, "closure", coff, "", func_type_in(st3, func))
};

def gen_decl(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    if (node.kind == "def") {
        let dcaps = fn_captures(node.v, fn_names_of(st.fns));
        if (len(dcaps) == 0) {
            st
        } else {
            gen_closure_binding(st, node.name, node.v, dcaps)
        }
    } else {
        if (node.v.k == "func") {
            let caps = fn_captures(node.v, fn_names_of(st.fns));
            if (len(caps) == 0) {
                st
            } else {
                gen_closure_binding(st, node.name, node.v, caps)
            }
        } else if (node.v.k == "arrrep") {
            let t = node.typ;
            if (t.k == "tnone") {
                t = infer(st, node.v);
            };
            st = gen_arrrep_esz(st, node.v, arr_elem_bytes(t));
            let off = (st.slots + 1) * -8;
            st = emit(st, "    mov %rax, " + tostring(off) + "(%rbp)");
            let st2 = { out: st.out, rodata: st.rodata, uid: st.uid,
              fuid: st.fuid, loc: st.loc, env: st.env, slots: st.slots + 1,
              self_label: st.self_label, end_label: st.end_label, fns: st.fns,
              bodies: st.bodies };
            env_define(st2, node.name, "local", off, "", t)
        } else if (node.v.k == "array") {
            let t = node.typ;
            if (t.k == "tnone") {
                t = infer(st, node.v);
            };
            st = gen_array_esz(st, node.v, arr_elem_bytes(t));
            let off = (st.slots + 1) * -8;
            st = emit(st, "    mov %rax, " + tostring(off) + "(%rbp)");
            let st2 = { out: st.out, rodata: st.rodata, uid: st.uid,
              fuid: st.fuid, loc: st.loc, env: st.env, slots: st.slots + 1,
              self_label: st.self_label, end_label: st.end_label, fns: st.fns,
              bodies: st.bodies };
            env_define(st2, node.name, "local", off, "", t)
        } else if (node.v.k == "map") {
            st = gen(st, node.v);
            let off = (st.slots + 1) * -8;
            st = emit(st, "    mov %rax, " + tostring(off) + "(%rbp)");
            let t = node.typ;
            if (t.k == "tnone") {
                t = infer(st, node.v);
            };
            let st2 = { out: st.out, rodata: st.rodata, uid: st.uid,
              fuid: st.fuid, loc: st.loc, env: st.env, slots: st.slots + 1,
              self_label: st.self_label, end_label: st.end_label, fns: st.fns,
              bodies: st.bodies };
            env_define(st2, node.name, "local", off, "", t)
        } else {
            st = gen(st, node.v);
            let off = (st.slots + 1) * -8;
            st = emit(st, "    mov %rax, " + tostring(off) + "(%rbp)");
            let t = node.typ;
            if (t.k == "tnone") {
                t = infer(st, node.v);
            };
            let st2 = { out: st.out, rodata: st.rodata, uid: st.uid,
              fuid: st.fuid, loc: st.loc, env: st.env, slots: st.slots + 1,
              self_label: st.self_label, end_label: st.end_label, fns: st.fns,
              bodies: st.bodies };
            env_define(st2, node.name, "local", off, "", t)
        }
    }
};

def gen_assign(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let e = env_find(st, node.name);
    st = gen(st, node.v);
    st = emit(st, "    mov %rax, " + tostring(e.off) + "(%rbp)");
    st
};

def gen_fill(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, base: long, n: long) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    if (n == 0) {
        st
    } else {
        let r = next_loc(st);
        st = r.st;
        st = emit(st, "    mov $" + tostring(n) + ", %rcx");
        st = emit(st, r.lbl + ":");
        st = emit(st, "    dec %rcx");
        st = emit(st, "    mov %rax, " + tostring(base) + "(%rbp,%rcx,8)");
        emit(st, "    jnz " + r.lbl)
    }
};

def gen_fill_heap(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, n: long, esz: long) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    if (n == 0) {
        st
    } else {
        let r = next_loc(st);
        st = r.st;
        st = emit(st, "    mov %rdx, %r10");
        st = emit(st, "    mov %rax, %rdx");
        st = emit(st, "    mov $" + tostring(n) + ", %rcx");
        st = emit(st, r.lbl + ":");
        st = emit(st, "    dec %rcx");
        st = emit(st, elem_store_rdx(esz, "%r10", "%rcx"));
        st = emit(st, "    jnz " + r.lbl);
        st = emit(st, "    mov %r10, %rdx");
        st
    }
};

def gen_arrrep(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    gen_arrrep_esz(st, node, elem_bytes(infer(st, node.v)))
};

def gen_arrrep_esz(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node, esz: long) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let n = node.n;
    st = gen(st, node.v);
    st = emit(st, "    push %rax");
    st = emit(st, "    mov $" + tostring(arr_alloc_size(esz, n)) + ", %rdi");
    st = emit(st, "    call y_alloc");
    st = emit(st, "    mov %rax, %rdx");
    st = emit(st, "    mov $" + tostring(n) + ", (%rdx)");
    st = emit(st, "    mov $" + tostring(n) + ", 8(%rdx)");
    st = emit(st, "    pop %rax");
    st = gen_fill_heap(st, n, esz);
    emit(st, "    mov %rdx, %rax")
};

def hexval_ch(c: str) -> long {
    let o = ord(c);
    let v = 0;
    if (o >= 48) {
        if (o <= 57) { v = o - 48; 0; } else { 0; };
        0
    } else { 0; };
    if (o >= 97) {
        if (o <= 102) { v = o - 87; 0; } else { 0; };
        0
    } else { 0; };
    if (o >= 65) {
        if (o <= 70) { v = o - 55; 0; } else { 0; };
        0
    } else { 0; };
    v
};

def lit_is_float(s: str) -> bool {
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

def norm_num(s: str) -> str {
    let radix = 0;
    if (len(s) > 2) {
        let p = substr(s, 0, 2);
        if (p == "0x") { radix = 16; 0; } else { 0; };
        if (p == "0X") { radix = 16; 0; } else { 0; };
        if (p == "0b") { radix = 2; 0; } else { 0; };
        if (p == "0B") { radix = 2; 0; } else { 0; };
        0
    } else { 0; };
    if (radix == 0) {
        s
    } else {
        let v = 0;
        let i = 2;
        while (i < len(s)) {
            let c = substr(s, i, 1);
            if (c == "_") { 0; } else {
                v = v * radix + hexval_ch(c);
                0
            };
            i = i + 1;
        };
        tostring(v)
    }
};

def flit_mant(s: str) -> long {
    let v = 0;
    let i = 0;
    let n = flit_ebase(s);
    while (i < n) {
        let c = substr(s, i, 1);
        if (c == ".") { 0; } else {
            v = v * 10 + hexval_ch(c);
            0
        };
        i = i + 1;
    };
    v
};

def flit_ebase(s: str) -> long {
    let e = index_of(s, "e");
    if (e < 0) { e = index_of(s, "E"); 0; } else { 0; };
    if (e < 0) { len(s) } else { e }
};

def flit_exp(s: str) -> long {
    let eb = flit_ebase(s);
    let dot = index_of(s, ".");
    let frac = 0;
    if (dot >= 0) { frac = eb - dot - 1; 0; } else { 0; };
    let ex = 0;
    if (eb < len(s)) {
        let i = eb + 1;
        let neg = false;
        let sc = substr(s, i, 1);
        if (sc == "-") { neg = true; i = i + 1; 0; } else { 0; };
        if (sc == "+") { i = i + 1; 0; } else { 0; };
        while (i < len(s)) {
            ex = ex * 10 + hexval_ch(substr(s, i, 1));
            i = i + 1;
        };
        if (neg) { ex = 0 - ex; 0; } else { 0; };
        0
    } else { 0; };
    ex - frac
};

def flit_num(s: str) -> long {
    let v = 0;
    let i = 0;
    let n = len(s);
    while (i < n) {
        let c = substr(s, i, 1);
        if (c == ".") { 0; } else {
            v = v * 10 + hexval_ch(c);
            0
        };
        i = i + 1;
    };
    v
};

def flit_den(s: str) -> long {
    let dot = index_of(s, ".");
    let frac = 0;
    if (dot >= 0) { frac = len(s) - dot - 1; 0; } else { 0; };
    let d = 1;
    let i = 0;
    while (i < frac) {
        d = d * 10;
        i = i + 1;
    };
    d
};

def pow10(k: long) -> long {
    let d = 1;
    let i = 0;
    while (i < k) {
        d = d * 10;
        i = i + 1;
    };
    d
};

def gen_lit(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    if (lit_is_float(node.v)) {
        st = emit(st, "    mov $" + tostring(flit_mant(node.v)) + ", %rax");
        st = emit(st, "    cvtsi2sd %rax, %xmm0");
        gen_scale10(st, flit_exp(node.v))
    } else {
        emit(st, "    mov $" + norm_num(node.v) + ", %rax")
    }
};

def gen_scale10(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, n: long) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let up = n > 0;
    let left = n;
    if (!(up)) { left = 0 - n; 0; } else { 0; };
    while (left > 0) {
        let chunk = left;
        if (chunk > 18) { chunk = 18; 0; } else { 0; };
        st = emit(st, "    mov $" + tostring(pow10(chunk)) + ", %rax");
        st = emit(st, "    cvtsi2sd %rax, %xmm1");
        if (up) {
            st = emit(st, "    mulsd %xmm1, %xmm0");
            0
        } else {
            st = emit(st, "    divsd %xmm1, %xmm0");
            0
        };
        left = left - chunk;
    };
    emit(st, "    movq %xmm0, %rax")
};

def gen_index(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let e = env_find(st, node.arr.v);
    let ixesz = arr_elem_bytes(e.typ);
    st = gen(st, node.arr);
    st = emit(st, "    push %rax");
    st = gen(st, node.idx);
    st = emit(st, "    mov %rax, %rcx");
    st = emit(st, "    pop %rax");
    st = emit(st, "    test %rcx, %rcx");
    st = emit(st, "    js y_oob");
    if (e.typ.k == "tarrfix") {
        st = emit(st, "    cmp $" + tostring(e.typ.n) + ", %rcx");
        st = emit(st, "    jge y_oob");
        emit(st, elem_load(ixesz, "%rax", "%rcx", "%rax"))
    } else {
        st = emit(st, "    mov (%rax), %rdx");
        st = emit(st, "    cmp %rdx, %rcx");
        st = emit(st, "    jge y_oob");
        emit(st, elem_load(ixesz, "%rax", "%rcx", "%rax"))
    }
};

def gen_dotassign(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let e = env_find(st, node.obj.v);
    let idx = rec_field_idx(e.typ, node.key);
    st = gen(st, node.v);
    st = emit(st, "    push %rax");
    st = emit(st, "    mov " + tostring(e.off) + "(%rbp), %rdx");
    st = emit(st, "    pop %rax");
    st = emit(st, "    mov %rax, " + tostring(8 * idx) + "(%rdx)")
};

def gen_idxassign(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let e = env_find(st, node.arr.v);
    let iaesz = arr_elem_bytes(e.typ);
    st = gen(st, node.arr);
    st = emit(st, "    push %rax");
    st = gen(st, node.idx);
    st = emit(st, "    push %rax");
    st = gen(st, node.v);
    st = emit(st, "    pop %rcx");
    st = emit(st, "    pop %rdx");
    st = emit(st, "    test %rcx, %rcx");
    st = emit(st, "    js y_oob");
    if (e.typ.k == "tarrfix") {
        st = emit(st, "    cmp $" + tostring(e.typ.n) + ", %rcx");
        st = emit(st, "    jge y_oob");
        st = emit(st, "    mov %rdx, %r10");
        st = emit(st, "    mov %rax, %rdx");
        st = emit(st, elem_store_rdx(iaesz, "%r10", "%rcx"));
        st = emit(st, "    mov %r10, %rdx");
        0
    } else {
        st = emit(st, "    push %rax");
        st = emit(st, "    mov (%rdx), %rax");
        st = emit(st, "    cmp %rax, %rcx");
        st = emit(st, "    jge y_oob");
        st = emit(st, "    pop %rax");
        st = emit(st, "    mov %rdx, %r10");
        st = emit(st, "    mov %rax, %rdx");
        st = emit(st, elem_store_rdx(iaesz, "%r10", "%rcx"));
        st = emit(st, "    mov %r10, %rdx");
        0
    };
    st = emit(st, "    mov %rdx, " + tostring(e.off) + "(%rbp)");
    st
};


def gen_val_tostr_rax(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, t) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let tk = t.k;
    if (tk == "tstr") {
        st
    } else if (tk == "tbool") {
        st = emit(st, "    push %rax");
        st = emit(st, "    call y_bool_tostr");
        emit(st, "    add $8, %rsp")
    } else if (tk == "tfloat") {
        st = emit(st, "    push %rax");
        st = emit(st, "    call y_float_tostr");
        emit(st, "    add $8, %rsp")
    } else if (tk == "tarr") {
        gen_arr_tostr_rax(st, t.of)
    } else if (tk == "tarrfix") {
        gen_arr_tostr_rax(st, t.of)
    } else {
        st = emit(st, "    push %rax");
        st = emit(st, "    call y_long_tostr");
        emit(st, "    add $8, %rsp")
    }
};

def gen_arr_tostr_rax(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, elty) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let soff = (st.slots + 1) * -8;
    let aoff = (st.slots + 2) * -8;
    let ioff = (st.slots + 3) * -8;
    st = { out: st.out, rodata: st.rodata, uid: st.uid,
      fuid: st.fuid, loc: st.loc, env: st.env, slots: st.slots + 3,
      self_label: st.self_label, end_label: st.end_label, fns: st.fns,
      bodies: st.bodies };
    st = emit(st, "    mov %rax, " + tostring(soff) + "(%rbp)");
    st = gen_str_const(st, "[");
    st = emit(st, "    mov %rax, " + tostring(aoff) + "(%rbp)");
    st = emit(st, "    xor %eax, %eax");
    st = emit(st, "    mov %rax, " + tostring(ioff) + "(%rbp)");
    let r1 = next_loc(st);
    st = r1.st;
    let r2 = next_loc(st);
    st = r2.st;
    let r3 = next_loc(st);
    st = r3.st;
    st = emit(st, r1.lbl + ":");
    st = emit(st, "    mov " + tostring(soff) + "(%rbp), %rdx");
    st = emit(st, "    mov (%rdx), %rcx");
    st = emit(st, "    mov " + tostring(ioff) + "(%rbp), %rax");
    st = emit(st, "    cmp %rcx, %rax");
    st = emit(st, "    jge " + r2.lbl);
    st = emit(st, "    test %rax, %rax");
    st = emit(st, "    jz " + r3.lbl);
    st = gen_acc_cat_slot(st, aoff, ", ");
    st = emit(st, r3.lbl + ":");
    st = emit(st, "    mov " + tostring(soff) + "(%rbp), %rdx");
    st = emit(st, "    mov " + tostring(ioff) + "(%rbp), %rcx");
    st = emit(st, elem_load(elem_bytes(elty), "%rdx", "%rcx", "%rax"));
    st = gen_val_tostr_rax(st, elty);
    st = emit(st, "    mov %rax, %rdx");
    st = emit(st, "    mov " + tostring(aoff) + "(%rbp), %rax");
    st = emit(st, "    push %rax");
    st = emit(st, "    push %rdx");
    st = emit(st, "    call y_str_cat");
    st = emit(st, "    add $16, %rsp");
    st = emit(st, "    mov %rax, " + tostring(aoff) + "(%rbp)");
    st = emit(st, "    mov " + tostring(ioff) + "(%rbp), %rax");
    st = emit(st, "    inc %rax");
    st = emit(st, "    mov %rax, " + tostring(ioff) + "(%rbp)");
    st = emit(st, "    jmp " + r1.lbl);
    st = emit(st, r2.lbl + ":");
    st = gen_acc_cat_slot(st, aoff, "]");
    emit(st, "    mov " + tostring(aoff) + "(%rbp), %rax")
};

def gen_acc_cat_slot(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, off: long, s: str) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    st = emit(st, "    mov " + tostring(off) + "(%rbp), %rax");
    st = emit(st, "    push %rax");
    st = gen_str_const(st, s);
    st = emit(st, "    push %rax");
    st = emit(st, "    call y_str_cat");
    st = emit(st, "    add $16, %rsp");
    emit(st, "    mov %rax, " + tostring(off) + "(%rbp)")
};


def elem_bytes(t) -> long {
    if (t.k == "tbyte") { 1 } else { 8 }
};

def arr_elem_bytes(t) -> long {
    if (t.k == "tarr") { elem_bytes(t.of) }
    else if (t.k == "tarrfix") { elem_bytes(t.of) }
    else { 8 }
};

def elem_load(esz: long, base: str, idx: str, dst: str) -> str {
    if (esz == 1) {
        "    movzbq 16(" + base + "," + idx + ",1), " + dst
    } else {
        "    mov 16(" + base + "," + idx + ",8), " + dst
    }
};

def elem_store_rdx(esz: long, base: str, idx: str) -> str {
    if (esz == 1) {
        "    movb %dl, 16(" + base + "," + idx + ",1)"
    } else {
        "    mov %rdx, 16(" + base + "," + idx + ",8)"
    }
};

def elem_store_rdx_const(esz: long, base: str, k: long) -> str {
    if (esz == 1) {
        "    movb %dl, " + tostring(16 + k) + "(" + base + ")"
    } else {
        "    mov %rdx, " + tostring(16 + k * 8) + "(" + base + ")"
    }
};

def arr_alloc_size(esz: long, n: long) -> long {
    16 + n * esz
};

def gen_dot(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let dobj = node.obj;
    let dkey = node.key;
    let t = infer(st, dobj);
    let idx = rec_field_idx(t, dkey);
    if (idx < 0) {
        let r = next_uid(st);
        st = r.st;
        let klbl = arch.arch_str_label(r.uid);
        let krod = [];
        krod = push(krod, klbl);
        krod = push(krod, tostring(len(dkey)));
        krod = push(krod, esc_asm(dkey));
        let rod = push(st.rodata, krod);
        st = { out: st.out, rodata: rod, uid: st.uid,
          fuid: st.fuid, loc: st.loc, env: st.env, slots: st.slots,
          self_label: st.self_label, end_label: st.end_label, fns: st.fns,
          bodies: st.bodies };
        st = gen(st, dobj);
        st = emit(st, "    push %rax");
        st = emit(st, "    lea " + klbl + "(%rip), %rax");
        st = emit(st, "    push %rax");
        st = emit(st, "    call y_dot_lookup");
        st = emit(st, "    add $16, %rsp");
        0
    } else {
        st = gen(st, dobj);
        st = emit(st, "    mov " + tostring(idx * 8) + "(%rax), %rax");
        0
    };
    st
};

def rec_field_idx(t, key: str) -> long {
    let idx = -1;
    if (t.k == "trec") {
        let fs = t.fields;
        let i = 0;
        while (i < len(fs)) {
            let f = fs[i];
            if (f.name == key) {
                idx = i;
                0
            } else { 0; };
            i = i + 1;
        };
    };
    idx
};

def gen_array(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    gen_array_esz(st, node, arr_elem_bytes(infer(st, node)))
};

def gen_array_esz(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node, esz: long) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let elems = node.elems;
    st = gen_push_args(st, elems);
    let n = len(elems);
    st = emit(st, "    mov $" + tostring(arr_alloc_size(esz, n)) + ", %rdi");
    st = emit(st, "    call y_alloc");
    st = emit(st, "    mov %rax, %r10");
    st = emit(st, "    mov $" + tostring(n) + ", (%r10)");
    st = emit(st, "    mov $" + tostring(n) + ", 8(%r10)");
    let k = n - 1;
    while (k >= 0) {
        st = emit(st, "    pop %rdx");
        st = emit(st, elem_store_rdx_const(esz, "%r10", k));
        k = k - 1;
    };
    emit(st, "    mov %r10, %rax")
};

def gen_len(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let args = node.args;
    let at = infer(st, args[0]);
    if (at.k == "tstr") {
        st = gen(st, args[0]);
        emit(st, "    mov (%rax), %rax")
    } else {
        st = gen(st, args[0]);
        emit(st, "    mov (%rax), %rax")
    }
};

def gen_push(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let pargs = node.args;
    let pesz = arr_elem_bytes(infer(st, pargs[0]));
    st = gen_push_args(st, node.args);
    st = emit(st, "    mov $" + tostring(pesz) + ", %rax");
    st = emit(st, "    push %rax");
    st = emit(st, "    call y_arr_push");
    let nbytes = len(node.args) * 8 + 8;
    emit(st, "    add $" + tostring(nbytes) + ", %rsp")
};

def gen_some(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let args = node.args;
    st = gen(st, args[0]);
    st = emit(st, "    push %rax");
    st = emit(st, "    mov $8, %rdi");
    st = emit(st, "    call y_alloc");
    st = emit(st, "    pop %rcx");
    st = emit(st, "    mov %rcx, (%rax)");
    st
};

def gen_is_some(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let args = node.args;
    st = gen(st, args[0]);
    st = emit(st, "    test %rax, %rax");
    st = emit(st, "    setne %al");
    emit(st, "    movzbq %al, %rax")
};

def gen_unwrap(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let args = node.args;
    st = gen(st, args[0]);
    st = emit(st, "    test %rax, %rax");
    st = emit(st, "    jz y_opt_unwrap");
    emit(st, "    mov (%rax), %rax")
};


def gen_substr(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    st = gen_push_args(st, node.args);
    st = emit(st, "    call y_str_substr");
    emit(st, "    add $24, %rsp")
};

def gen_trim(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    st = gen_push_args(st, node.args);
    st = emit(st, "    call y_str_trim");
    emit(st, "    add $8, %rsp")
};

def gen_ord(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    st = gen_push_args(st, node.args);
    st = emit(st, "    call y_str_ord");
    emit(st, "    add $8, %rsp")
};

def gen_chr(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    st = gen_push_args(st, node.args);
    st = emit(st, "    call y_str_chr");
    emit(st, "    add $8, %rsp")
};

def gen_tonum(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    st = gen_push_args(st, node.args);
    st = emit(st, "    call y_str_tonum");
    emit(st, "    add $8, %rsp")
};

def gen_tostring(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let targs = node.args;
    let a0 = targs[0];
    let t = infer(st, a0);
    if (t.k == "tstr") {
        gen(st, a0)
    } else if (t.k == "tbool") {
        st = gen_push_args(st, node.args);
        st = emit(st, "    call y_bool_tostr");
        emit(st, "    add $8, %rsp")
    } else if (t.k == "tfloat") {
        st = gen_push_args(st, node.args);
        st = emit(st, "    call y_float_tostr");
        emit(st, "    add $8, %rsp")
    } else if (t.k == "tarr") {
        st = gen(st, a0);
        gen_arr_tostr_rax(st, t.of)
    } else if (t.k == "tarrfix") {
        st = gen(st, a0);
        gen_arr_tostr_rax(st, t.of)
    } else {
        st = gen_push_args(st, node.args);
        st = emit(st, "    call y_long_tostr");
        emit(st, "    add $8, %rsp")
    }
};

def gen_index_of(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node, last: bool) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    st = gen_push_args(st, node.args);
    if (last) {
        st = emit(st, "    call y_str_lastidx");
        emit(st, "    add $16, %rsp")
    } else {
        st = emit(st, "    call y_str_index");
        emit(st, "    add $16, %rsp")
    }
};

def gen_join(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let jargs = node.args;
    let at = infer(st, jargs[0]);
    let eltyp = { k: "tunk" };
    if (at.k == "tarr") { eltyp = at.of; 0; } else { 0; };
    if (at.k == "tarrfix") { eltyp = at.of; 0; } else { 0; };
    let ek = eltyp.k;
    if (ek == "tlong") {
        gen_join_conv(st, node, "y_long_tostr", 8)
    } else if (ek == "tbyte") {
        gen_join_conv(st, node, "y_long_tostr", 1)
    } else if (ek == "tbool") {
        gen_join_conv(st, node, "y_bool_tostr", 8)
    } else if (ek == "tfloat") {
        gen_join_conv(st, node, "y_float_tostr", 8)
    } else {
        st = gen_push_args(st, node.args);
        st = emit(st, "    call y_str_join");
        emit(st, "    add $16, %rsp")
    }
};

def gen_join_conv(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node, tostr_fn: str, esz: long) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let soff = (st.slots + 1) * -8;
    let doff = (st.slots + 2) * -8;
    let ioff = (st.slots + 3) * -8;
    st = { out: st.out, rodata: st.rodata, uid: st.uid,
      fuid: st.fuid, loc: st.loc, env: st.env, slots: st.slots + 3,
      self_label: st.self_label, end_label: st.end_label, fns: st.fns,
      bodies: st.bodies };
    let jargs = node.args;
    st = gen(st, jargs[0]);
    st = emit(st, "    mov %rax, " + tostring(soff) + "(%rbp)");
    st = emit(st, "    mov (%rax), %rdi");
    st = emit(st, "    shl $3, %rdi");
    st = emit(st, "    add $16, %rdi");
    st = emit(st, "    call y_alloc");
    st = emit(st, "    mov %rax, " + tostring(doff) + "(%rbp)");
    st = emit(st, "    mov " + tostring(soff) + "(%rbp), %rcx");
    st = emit(st, "    mov (%rcx), %rdx");
    st = emit(st, "    mov %rdx, (%rax)");
    st = emit(st, "    mov %rdx, 8(%rax)");
    st = emit(st, "    xor %eax, %eax");
    st = emit(st, "    mov %rax, " + tostring(ioff) + "(%rbp)");
    let r1 = next_loc(st);
    st = r1.st;
    let r2 = next_loc(st);
    st = r2.st;
    st = emit(st, r1.lbl + ":");
    st = emit(st, "    mov " + tostring(soff) + "(%rbp), %rdx");
    st = emit(st, "    mov (%rdx), %rcx");
    st = emit(st, "    mov " + tostring(ioff) + "(%rbp), %rax");
    st = emit(st, "    cmp %rcx, %rax");
    st = emit(st, "    jge " + r2.lbl);
    st = emit(st, elem_load(esz, "%rdx", "%rax", "%rcx"));
    st = emit(st, "    push %rcx");
    st = emit(st, "    call " + tostr_fn);
    st = emit(st, "    add $8, %rsp");
    st = emit(st, "    mov " + tostring(ioff) + "(%rbp), %rcx");
    st = emit(st, "    mov " + tostring(doff) + "(%rbp), %rdx");
    st = emit(st, "    mov %rax, 16(%rdx,%rcx,8)");
    st = emit(st, "    inc %rcx");
    st = emit(st, "    mov %rcx, " + tostring(ioff) + "(%rbp)");
    st = emit(st, "    jmp " + r1.lbl);
    st = emit(st, r2.lbl + ":");
    st = emit(st, "    mov " + tostring(doff) + "(%rbp), %rax");
    st = emit(st, "    push %rax");
    st = gen(st, jargs[1]);
    st = emit(st, "    push %rax");
    st = emit(st, "    call y_str_join");
    emit(st, "    add $16, %rsp")
};

def gen_split(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    st = gen_push_args(st, node.args);
    st = emit(st, "    call y_str_split");
    emit(st, "    add $16, %rsp")
};

def gen_puts(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let pargs = node.args;
    let pa = pargs[0];
    st = gen(st, pa);
    let t = infer(st, pa);
    st = emit(st, "    mov %rax, %rdi");
    if (t.k == "tbool") {
        st = emit(st, "    call y_put_bool");
        emit(st, "    xor %eax, %eax")
    } else if (t.k == "tstr") {
        st = emit(st, "    call y_put_hstr");
        emit(st, "    xor %eax, %eax")
    } else {
        st = emit(st, "    call y_put_long");
        emit(st, "    xor %eax, %eax")
    }
};

def gen_eputs(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let pargs = node.args;
    let pa = pargs[0];
    st = gen(st, pa);
    let t = infer(st, pa);
    st = emit(st, "    mov %rax, %rdi");
    if (t.k == "tbool") {
        st = emit(st, "    call y_eput_bool");
        emit(st, "    xor %eax, %eax")
    } else if (t.k == "tstr") {
        st = emit(st, "    call y_eput_hstr");
        emit(st, "    xor %eax, %eax")
    } else {
        st = emit(st, "    call y_eput_long");
        emit(st, "    xor %eax, %eax")
    }
};

def gen_clock_us(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let unused = node;
    emit(st, "    call y_clock_us")
};

def gen_heap_used(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let unused = node;
    emit(st, "    call y_heap_used")
};

def gen_sleep(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let sargs = node.args;
    let sa = sargs[0];
    st = gen(st, sa);
    st = emit(st, "    mov %rax, %rdi");
    emit(st, "    call y_sleep")
};


def gen_exit(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let eargs = node.args;
    let ea = eargs[0];
    st = gen(st, ea);
    st = emit(st, "    mov %rax, %rdi");
    st = emit(st, "    mov $60, %rax");
    st = emit(st, "    syscall");
    emit(st, "    jmp " + st.end_label)
};


def gen_argv(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    emit(st, "    call y_argv")
};

def gen_read_file(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    st = gen_push_args(st, node.args);
    st = emit(st, "    call y_read_file");
    emit(st, "    add $8, %rsp")
};

def gen_write_file(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    st = gen_push_args(st, node.args);
    st = emit(st, "    call y_write_file");
    emit(st, "    add $16, %rsp")
};

def gen_write_bytes(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    st = gen_push_args(st, node.args);
    st = emit(st, "    call y_write_bytes");
    emit(st, "    add $24, %rsp")
};

def gen_store(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, node) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    st = gen(st, node.p);
    st = emit(st, "    push %rax");
    st = gen(st, node.v);
    st = emit(st, "    pop %rcx");
    emit(st, "    mov %rax, (%rcx)")
};


def emit_one_fn(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, label: str, fuid: long, func, is_main: bool, want_argv: bool, captypes: [{ k: str }]) -> { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] } {
    let f = { out: [], rodata: st.rodata, uid: st.uid,
      fuid: fuid, loc: 1, env: [], slots: 0,
      self_label: label, end_label: arch.arch_loc_label(fuid, 0),
      fns: st.fns, bodies: st.bodies };
    let fnsall = st.fns;
    let g = 0;
    while (g < len(fnsall)) {
        let fe = fnsall[g];
        f = env_define(f, fe.name, "func", 0, fe.label, fe.typ);
        g = g + 1;
    };
    let params = func.params;
    let ptypes = func.ptypes;
    let nargs = len(params);
    let i = 0;
    while (i < nargs) {
        f = env_define(f, params[i], "param", 16 + (nargs - 1 - i) * 8, "", ptypes[i]);
        i = i + 1;
    };
    if (is_main) { 0; } else {
        let mycaps = fn_captures(func, fn_names_of(st.fns));
        let cloff = 16 + nargs * 8;
        let c = 0;
        while (c < len(mycaps)) {
            let cn: str = mycaps[c];
            let ct = { k: "tnone" };
            if (c < len(captypes)) {
                ct = captypes[c];
                0
            } else { 0; };
            f = env_define(f, cn, "capture", cloff, tostring(c), ct);
            c = c + 1;
        };
        0
    };
    f = gen_block(f, func.body);
    let frame = arch.arch_frame(f.slots);
    let code = [];
    code = push(code, label + ":");
    if (is_main) {
        if (want_argv) {
            code = push(code, "    mov %rsp, %rax");
            code = push(code, "    mov (%rax), %r15");
            code = push(code, "    mov %rax, %r14");
            code = push(code, "    add $8, %r14");
            code = push(code, "    push %r14");
            code = push(code, "    push %r15");
            code = push(code, "    call y_argv_init");
            code = push(code, "    add $16, %rsp");
            0
        } else { 0; };
        0
    } else { 0; };
    code = push(code, "    push %rbp");
    code = push(code, "    mov %rsp, %rbp");
    if (frame > 0) {
        code = push(code, "    sub $" + tostring(frame) + ", %rsp");
        0
    } else { 0; };
    let fout = f.out;
    let j = 0;
    while (j < len(fout)) {
        code = push(code, fout[j]);
        j = j + 1;
    };
    code = push(code, f.end_label + ":");
    if (is_main) {
        code = push(code, "    mov $60, %rax");
        code = push(code, "    xor %edi, %edi");
        code = push(code, "    syscall");
    } else {
        code = push(code, "    mov %rbp, %rsp");
        code = push(code, "    pop %rbp");
        code = push(code, "    ret");
    };
    let bodies = push(f.bodies, join(code, "\n"));
    { out: st.out, rodata: f.rodata, uid: f.uid,
      fuid: st.fuid, loc: st.loc, env: st.env, slots: st.slots,
      self_label: st.self_label, end_label: st.end_label, fns: st.fns,
      bodies: bodies }
};

def infer_fn_ret(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, func) -> { k: str } {
    let f = { out: [], rodata: st.rodata, uid: st.uid,
      fuid: 0, loc: 1, env: [], slots: 0,
      self_label: "", end_label: "", fns: st.fns, bodies: st.bodies };
    let fnsall = st.fns;
    let g = 0;
    while (g < len(fnsall)) {
        let fe = fnsall[g];
        f = env_define(f, fe.name, "func", 0, fe.label, fe.typ);
        g = g + 1;
    };
    let params = func.params;
    let ptypes = func.ptypes;
    let n = len(params);
    let i = 0;
    while (i < n) {
        f = env_define(f, params[i], "param", 16 + (n - 1 - i) * 8, "", ptypes[i]);
        i = i + 1;
    };
    infer(f, func.body)
};

def func_type(func) -> { k: str, args: [{ k: str }], ret: { k: str } } {
    { k: "tfunc", args: func.ptypes, ret: func.ret }
};

def func_type_in(st: { out: [str], rodata: [[str]], uid: long, fuid: long, loc: long, env: [{ name: str, kind: str, off: long, label: str, typ: { k: str } }], slots: long, self_label: str, end_label: str, fns: [{ name: str, label: str, typ: { k: str } }], bodies: [str] }, func) -> { k: str, args: [{ k: str }], ret: { k: str } } {
    let r = func.ret;
    if (r.k == "tnone") {
        r = infer_fn_ret(st, func);
        0
    } else { 0; };
    { k: "tfunc", args: func.ptypes, ret: r }
};

def ndisp(name: str) -> str {
    let i = index_of(name, "$");
    if (i < 0) { name } else { substr(name, 0, i) }
};

def find_dup(defs: [{ name: str, func: { k: str } }]) -> { found: bool, err: { msg: str, line: long, col: long } } {
    let seen = [];
    let i = 0;
    let out = { found: false, err: { msg: "", line: 1, col: 1 } };
    while (i < len(defs)) {
        let d = defs[i];
        let j = 0;
        while (j < len(seen)) {
            let sn: str = seen[j];
            if (sn == d.name) {
                out = { found: true, err: { msg: "duplicate definition '" + ndisp(d.name) + "' (native imports splice; rename one)", line: d.func.line, col: d.func.col } };
                0
            } else { 0; };
            j = j + 1;
        };
        seen = push(seen, d.name);
        i = i + 1;
    };
    out
};


def phase_end(times: [{ name: str, us: long, heap: long }], name: str, t0: long, h0: long) -> { times: [{ name: str, us: long, heap: long }], t: long, h: long } {
    let t1 = clock_us();
    let h1 = heap_used();
    { times: push(times, { name: name, us: t1 - t0, heap: h1 - h0 }), t: t1, h: h1 }
};


def emit_program(ast, imports: [str]) -> { ok: bool, asm: str, errors: [{ msg: str, line: long, col: long }], times: [{ name: str, us: long, heap: long }] } {
    let times: [{ name: str, us: long, heap: long }] = [];
    let pt = clock_us();
    let ph = heap_used();
    let ast2 = strip_ns(ast, imports);
    let pr = phase_end(times, "strip_ns", pt, ph);
    times = pr.times; pt = pr.t; ph = pr.h;
    let ast3 = rename.rename_program(ast2);
    pr = phase_end(times, "rename", pt, ph);
    times = pr.times; pt = pr.t; ph = pr.h;
    let errors = types.check_program(ast3);
    pr = phase_end(times, "typecheck", pt, ph);
    times = pr.times; pt = pr.t; ph = pr.h;
    let defs = collect_from_block(ast3.stmts, []);
    let dup = find_dup(defs);
    if (dup.found) {
        errors = push(errors, dup.err);
        0
    } else { 0; };
    if (len(errors) > 0) {
        { ok: false, asm: "", errors: errors, times: times }
    } else {
        let st = st_new();
        let r = next_uid(st);
        st = r.st;
        let i = 0;
        while (i < len(defs)) {
            let d = defs[i];
            let rl = next_uid(st);
            st = rl.st;
            let label = arch.arch_fn_label(rl.uid, d.name);
            let fns = push(st.fns, { name: d.name, label: label, typ: func_type(d.func) });
            st = { out: st.out, rodata: st.rodata, uid: st.uid,
              fuid: st.fuid, loc: st.loc, env: st.env, slots: st.slots,
              self_label: st.self_label, end_label: st.end_label, fns: fns,
              bodies: st.bodies };
            st = env_define(st, d.name, "func", 0, label, func_type(d.func));
            i = i + 1;
        };
        let fixedfns: [{ name: str, label: str, typ: { k: str } }] = [];
        let fx = 0;
        while (fx < len(defs)) {
            let dfx = defs[fx];
            let ftab = st.fns;
            let fe0 = ftab[fx];
            let ty0 = fe0.typ;
            if (ty0.ret.k == "tnone") {
                let rt2 = infer_fn_ret(st, dfx.func);
                fixedfns = push(fixedfns, { name: fe0.name, label: fe0.label,
                  typ: { k: "tfunc", args: ty0.args, ret: rt2 } });
                0
            } else {
                fixedfns = push(fixedfns, fe0);
                0
            };
            fx = fx + 1;
        };
        st = { out: st.out, rodata: st.rodata, uid: st.uid,
          fuid: st.fuid, loc: st.loc, env: st.env, slots: st.slots,
          self_label: st.self_label, end_label: st.end_label, fns: fixedfns,
          bodies: st.bodies };
        i = 0;
        let allfnnames = fn_names_of(st.fns);
        while (i < len(defs)) {
            let d = defs[i];
            let fns = st.fns;
            let f = fns[i];
            if (len(fn_captures(d.func, allfnnames)) == 0) {
                let rf = next_uid(st);
                st = rf.st;
                st = emit_one_fn(st, f.label, rf.uid, d.func, false, false, []);
                0
            } else { 0; };
            i = i + 1;
        };
        pr = phase_end(times, "emit_fns", pt, ph);
        times = pr.times; pt = pr.t; ph = pr.h;
        let main_stmts = [];
        let pstmts = ast3.stmts;
        let i = 0;
        while (i < len(pstmts)) {
            let s = pstmts[i];
            if (s.k == "decl") {
                if (s.kind == "def") {
                    0;
                } else if (s.v.k == "func") {
                    0;
                } else {
                    main_stmts = push(main_stmts, s);
                    0;
                };
                0
            } else {
                main_stmts = push(main_stmts, s);
                0;
            };
            i = i + 1;
        };
        let rm = next_uid(st);
        st = rm.st;
        let want = uses_scan_block(ast3.stmts, { argv: false });
        st = emit_one_fn(st, "_start", rm.uid, { params: [], ptypes: [], ret: { k: "tnull" }, body: { k: "block", stmts: main_stmts } }, true, want.argv, []);
        pr = phase_end(times, "emit_start", pt, ph);
        times = pr.times; pt = pr.t; ph = pr.h;
        let asm = arch.arch_header();
        asm = asm + arch.arch_text() + arch.arch_prelude();
        let allbodies = st.bodies;
        let pieces: [str] = [];
        let b = 0;
        while (b < len(allbodies)) {
            pieces = push(pieces, allbodies[b]);
            pieces = push(pieces, "\n");
            b = b + 1;
        };
        asm = asm + join(pieces, "");
        asm = asm + arch.arch_rodata() + arch.arch_consts();
        let allrod = st.rodata;
        let s2 = 0;
        let rodpieces: [str] = [];
        while (s2 < len(allrod)) {
            let pair = allrod[s2];
            if (len(pair) == 3) {
                rodpieces = push(rodpieces, pair[0] + ":\n.quad " + tostring(pair[1]) + "\n.string \"" + pair[2] + "\"\n");
                0
            } else {
                rodpieces = push(rodpieces, pair[0] + ":\n");
                let q = 2;
                while (q < len(pair)) {
                    rodpieces = push(rodpieces, ".quad " + pair[q] + "\n");
                    q = q + 1;
                };
                0
            };
            s2 = s2 + 1;
        };
        asm = asm + join(rodpieces, "");
        pr = phase_end(times, "asm_text", pt, ph);
        times = pr.times; pt = pr.t; ph = pr.h;
        { ok: true, asm: asm, errors: errors, times: times }
    }
};

export { emit_program, native_resolve, native_resolve_x, strip_ns, strip_list, strip_decl, phase_end };
