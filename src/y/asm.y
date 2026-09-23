import enc from "./enc64.y";
import elf from "./elf.y";

def is_digit_ch(c: str) -> bool {
    if (c == "0") { true }
    else if (c == "1") { true }
    else if (c == "2") { true }
    else if (c == "3") { true }
    else if (c == "4") { true }
    else if (c == "5") { true }
    else if (c == "6") { true }
    else if (c == "7") { true }
    else if (c == "8") { true }
    else { c == "9" }
};

def is_oct_ch(c: str) -> bool {
    let o = ord(c);
    if (o >= 48) {
        if (o <= 55) { true } else { false }
    } else { false }
};

def is_alpha_ch(c: str) -> bool {
    let o = ord(c);
    if (o == 95) { true }
    else if (o < 65) { false }
    else if (o <= 90) { true }
    else if (o < 97) { false }
    else if (o <= 122) { true }
    else { false }
};

def parse_num(s: str) -> {ok: bool, v: long} {
    let neg = false;
    let i = 0;
    if (substr(s, 0, 1) == "-") {
        neg = true;
        i = 1;
        0
    } else { 0 };
    if (i >= len(s)) {
        { ok: false, v: 0 }
    } else {
        parse_num_go(s, i, neg)
    }
};

def parse_num_go(s: str, i: long, neg: bool) -> {ok: bool, v: long} {
    let v = 0;
    let ok = true;
    while (i < len(s)) {
        let c = substr(s, i, 1);
        if (is_digit_ch(c)) {
            v = v * 10 + ord(c) - 48;
            0
        } else {
            ok = false;
            0
        };
        i = i + 1;
        0
    };
    if (neg) { v = 0 - v; 0; } else { 0 };
    { ok: ok, v: v }
};

def is_num_text(s: str) -> bool {
    let r = parse_num(s);
    r.ok
};

def split_ops(s: str) -> [str] {
    let out = [];
    let depth = 0;
    let cur = "";
    let i = 0;
    while (i < len(s)) {
        let c = substr(s, i, 1);
        if (c == "(") { depth = depth + 1; 0; } else { 0 };
        if (c == ")") { depth = depth - 1; 0; } else { 0 };
        if (c == ",") {
            if (depth == 0) {
                out = push(out, trim(cur));
                cur = "";
                0
            } else {
                cur = cur + c;
                0
            };
            0
        } else {
            cur = cur + c;
            0
        };
        i = i + 1;
        0
    };
    out = push(out, trim(cur));
    out
};

def parse_operand(t: str) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    if (t == "") {
        parse_operand_empty(t)
    } else {
        parse_operand_nonempty(t)
    }
};

def parse_operand_empty(t: str) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    { ok: false, op: { k: "bad", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: 0, idx: 0, scale: 0, disp: 0, rip: false, lbl: "" }, error: "empty operand" }
};

def parse_operand_nonempty(t: str) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    if (substr(t, 0, 1) == "*") {
        parse_operand_ind(t)
    } else if (substr(t, 0, 1) == "%") {
        parse_operand_reg(t)
    } else {
        parse_operand_noreg(t)
    }
};

def parse_operand_ind(t: str) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    let r = substr(t, 1, len(t) - 1);
    let n = enc.reg_num(r);
    if (n < 0) {
        { ok: false, op: { k: "bad", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: 0, idx: 0, scale: 0, disp: 0, rip: false, lbl: "" }, error: "unknown register '" + r + "'" }
    } else {
        { ok: true, op: { k: "ind", n: n, size: enc.reg_size(r), v: 0, a: "", b: "", name: "", base: 0, idx: 0, scale: 0, disp: 0, rip: false, lbl: "" }, error: "" }
    }
};

def parse_operand_reg(t: str) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    let n = enc.reg_num(t);
    if (n < 0) {
        { ok: false, op: { k: "bad", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: 0, idx: 0, scale: 0, disp: 0, rip: false, lbl: "" }, error: "unknown register '" + t + "'" }
    } else {
        { ok: true, op: { k: "reg", n: n, size: enc.reg_size(t), v: 0, a: "", b: "", name: "", base: 0, idx: 0, scale: 0, disp: 0, rip: false, lbl: "" }, error: "" }
    }
};

def parse_operand_noreg(t: str) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    if (substr(t, 0, 1) == "$") {
        parse_operand_imm(t)
    } else {
        parse_operand_memlbl(t)
    }
};

def parse_operand_imm(t: str) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    parse_imm(substr(t, 1, len(t) - 1))
};

def parse_operand_memlbl(t: str) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    if (index_of(t, "(") >= 0) {
        parse_mem(t)
    } else {
        { ok: true, op: { k: "lbl", n: 0, size: 0, v: 0, a: "", b: "", name: t, base: 0, idx: 0, scale: 0, disp: 0, rip: false, lbl: "" }, error: "" }
    }
};

def parse_imm(s: str) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    let dash = index_of(substr(s, 1, len(s) - 1), "-");
    if (len(s) > 0) {
        parse_imm_alpha(s, dash)
    } else {
        parse_imm_num(s)
    }
};

def parse_imm_alpha(s: str, dash: long) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    if (is_alpha_ch(substr(s, 0, 1))) {
        parse_imm_diff(s, dash)
    } else {
        parse_imm_num(s)
    }
};

def parse_imm_diff(s: str, dash: long) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    if (dash >= 0) {
        let a = substr(s, 0, dash + 1);
        let b = substr(s, dash + 2, len(s) - dash - 2);
        { ok: true, op: { k: "diff", n: 0, size: 0, v: 0, a: a, b: b, name: "", base: 0, idx: 0, scale: 0, disp: 0, rip: false, lbl: "" }, error: "" }
    } else {
        parse_imm_num(s)
    }
};

def parse_imm_num(s: str) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    let r = parse_num(s);
    if (r.ok) {
        { ok: true, op: { k: "imm", n: 0, size: 0, v: r.v, a: "", b: "", name: "", base: 0, idx: 0, scale: 0, disp: 0, rip: false, lbl: "" }, error: "" }
    } else {
        { ok: false, op: { k: "bad", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: 0, idx: 0, scale: 0, disp: 0, rip: false, lbl: "" }, error: "bad immediate '" + s + "'" }
    }
};

def parse_mem(t: str) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    let open = index_of(t, "(");
    let head = trim(substr(t, 0, open));
    let inside = substr(t, open + 1, len(t) - open - 2);
    let parts = split_ops(inside);
    if (head != "") {
        parse_mem_head(t, head, parts)
    } else {
        parse_mem_regs(t, parts, 0)
    }
};

def parse_mem_head(t: str, head: str, parts: [str]) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    if (is_num_text(head)) {
        parse_mem_disp(t, head, parts)
    } else {
        parse_mem_rip(t, head, parts)
    }
};

def parse_mem_rip(t: str, head: str, parts: [str]) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    if (len(parts) != 1) {
        { ok: false, op: { k: "bad", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: 0, idx: 0, scale: 0, disp: 0, rip: false, lbl: "" }, error: "bad rip-relative '" + t + "'" }
    } else if (parts[0] != "%rip") {
        { ok: false, op: { k: "bad", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: 0, idx: 0, scale: 0, disp: 0, rip: false, lbl: "" }, error: "bad rip-relative '" + t + "'" }
    } else {
        { ok: true, op: { k: "mem", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: -1, idx: -1, scale: 1, disp: 0, rip: true, lbl: head }, error: "" }
    }
};

def parse_mem_disp(t: str, head: str, parts: [str]) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    let r = parse_num(head);
    parse_mem_regs(t, parts, r.v)
};

def parse_mem_regs(t: str, parts: [str], disp: long) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    if (len(parts) < 1) {
        { ok: false, op: { k: "bad", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: 0, idx: 0, scale: 0, disp: 0, rip: false, lbl: "" }, error: "bad memory '" + t + "'" }
    } else if (len(parts) > 3) {
        { ok: false, op: { k: "bad", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: 0, idx: 0, scale: 0, disp: 0, rip: false, lbl: "" }, error: "bad memory '" + t + "'" }
    } else {
        let bn = enc.reg_num(parts[0]);
        if (bn < 0) {
            { ok: false, op: { k: "bad", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: 0, idx: 0, scale: 0, disp: 0, rip: false, lbl: "" }, error: "bad base register '" + t + "'" }
        } else {
            mem_rest(t, parts, disp, bn)
        }
    }
};

def mem_rest(t: str, parts: [str], disp: long, bn: long) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    if (len(parts) == 1) {
        { ok: true, op: { k: "mem", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: bn, idx: -1, scale: 1, disp: disp, rip: false, lbl: "" }, error: "" }
    } else {
        let xn = enc.reg_num(parts[1]);
        if (xn < 0) {
            { ok: false, op: { k: "bad", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: 0, idx: 0, scale: 0, disp: 0, rip: false, lbl: "" }, error: "bad index register '" + t + "'" }
        } else if (xn == 4) {
            { ok: false, op: { k: "bad", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: 0, idx: 0, scale: 0, disp: 0, rip: false, lbl: "" }, error: "rsp cannot be index '" + t + "'" }
        } else {
            mem_scale(t, parts, disp, bn, xn)
        }
    }
};

def mem_scale(t: str, parts: [str], disp: long, bn: long, xn: long) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    let scale = 1;
    if (len(parts) == 3) {
        mem_scaleThree(t, parts, disp, bn, xn)
    } else {
        { ok: true, op: { k: "mem", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: bn, idx: xn, scale: scale, disp: disp, rip: false, lbl: "" }, error: "" }
    }
};

def mem_scaleThree(t: str, parts: [str], disp: long, bn: long, xn: long) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    let r = parse_num(parts[2]);
    if (!(r.ok)) {
        { ok: false, op: { k: "bad", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: 0, idx: 0, scale: 0, disp: 0, rip: false, lbl: "" }, error: "bad scale '" + t + "'" }
    } else {
        mem_scaleVal(t, r.v, disp, bn, xn)
    }
};

def mem_scaleVal(t: str, v: long, disp: long, bn: long, xn: long) -> {ok: bool, op: {k: str, n: long, size: long, v: long, a: str, b: str, name: str, base: long, idx: long, scale: long, disp: long, rip: bool, lbl: str}, error: str} {
    if (v == 1) {
        { ok: true, op: { k: "mem", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: bn, idx: xn, scale: 1, disp: disp, rip: false, lbl: "" }, error: "" }
    } else if (v == 2) {
        { ok: true, op: { k: "mem", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: bn, idx: xn, scale: 2, disp: disp, rip: false, lbl: "" }, error: "" }
    } else if (v == 4) {
        { ok: true, op: { k: "mem", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: bn, idx: xn, scale: 4, disp: disp, rip: false, lbl: "" }, error: "" }
    } else if (v == 8) {
        { ok: true, op: { k: "mem", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: bn, idx: xn, scale: 8, disp: disp, rip: false, lbl: "" }, error: "" }
    } else {
        { ok: false, op: { k: "bad", n: 0, size: 0, v: 0, a: "", b: "", name: "", base: 0, idx: 0, scale: 0, disp: 0, rip: false, lbl: "" }, error: "bad scale '" + t + "'" }
    }
};

def decode_str(s: str) -> {ok: bool, bytes: [long], error: str} {
    let out = [];
    let i = 0;
    let n = len(s);
    let err = "";
    while (i < n) {
        let c = substr(s, i, 1);
        if (c != "\\") {
            out = push(out, ord(c));
            i = i + 1;
        } else {
            let e = substr(s, i + 1, 1);
            if (e == "n") {
                out = push(out, 10);
                i = i + 2;
            } else if (e == "t") {
                out = push(out, 9);
                i = i + 2;
            } else if (e == "r") {
                out = push(out, 13);
                i = i + 2;
            } else if (e == "\\") {
                out = push(out, 92);
                i = i + 2;
            } else if (e == "\"") {
                out = push(out, 34);
                i = i + 2;
            } else if (is_oct_ch(e)) {
                let oct = decode_oct(s, i + 2, n);
                if (oct.err != "") {
                    err = oct.err;
                    0
                } else {
                    out = push(out, oct.v);
                    0
                };
                i = oct.k;
            } else {
                err = "bad escape '\\" + e + "'";
                i = n;
            };
        };
    };
    { ok: err == "", bytes: out, error: err }
};

def decode_oct(s: str, k: long, n: long) -> {v: long, k: long, err: str} {
    let e = substr(s, k - 1, 1);
    let v = ord(e) - 48;
    let kk = k;
    let nd = 1;
    while (nd < 3) {
        if (kk < n) {
            let d = substr(s, kk, 1);
            if (is_oct_ch(d)) {
                v = v * 8 + ord(d) - 48;
                kk = kk + 1;
                nd = nd + 1;
                0
            } else {
                kk = n + 1;
                0
            };
            0
        } else {
            nd = 3;
            0
        };
        0
    };
    if (v > 255) {
        { v: 0, k: kk, err: "octal escape out of range" }
    } else {
        { v: v, k: kk, err: "" }
     }
};




def hash_str(s: str) -> long {
    let h = 0;
    let i = 0;
    while (i < len(s)) {
        h = (h * 31 + ord(substr(s, i, 1))) % 1000000007;
        i = i + 1;
    };
    h
};

def labmap_new(cap: long) -> [{ name: str, sec: long, off: long }] {
    let m = [];
    let i = 0;
    while (i < cap) {
        m = push(m, { name: "", sec: 0, off: 0 });
        i = i + 1;
    };
    m
};

def labmap_put(m: [{ name: str, sec: long, off: long }], name: str, sec: long, off: long) -> { map: [{ name: str, sec: long, off: long }], dup: bool } {
    let cap = len(m);
    let i = hash_str(name) % cap;
    let dup = false;
    let done = false;
    let n = 0;
    while (done == false) {
        let e = m[i];
        if (e.name == "") {
            m[i] = { name: name, sec: sec, off: off };
            done = true;
            0
        } else if (e.name == name) {
            dup = true;
            done = true;
            0
        } else {
            i = i + 1;
            if (i >= cap) { i = 0; 0; } else { 0; };
            0
        };
        n = n + 1;
        if (n > cap) { done = true; 0; } else { 0; };
    };
    { map: m, dup: dup }
};

def labmap_get(m: [{ name: str, sec: long, off: long }], name: str) -> { sec: long, off: long } {
    let cap = len(m);
    let i = hash_str(name) % cap;
    let found_sec = -1;
    let found_off = 0;
    let done = false;
    let n = 0;
    while (done == false) {
        let e = m[i];
        if (e.name == "") {
            done = true;
            0
        } else if (e.name == name) {
            found_sec = e.sec;
            found_off = e.off;
            done = true;
            0
        } else {
            i = i + 1;
            if (i >= cap) { i = 0; 0; } else { 0; };
            0
        };
        n = n + 1;
        if (n > cap) { done = true; 0; } else { 0; };
    };
    { sec: found_sec, off: found_off }
};

def labmap_build(labels: [{ name: str, sec: long, off: long }]) -> { map: [{ name: str, sec: long, off: long }], dup: str } {
    let cap = len(labels) * 2 + 16;
    let m = labmap_new(cap);
    let dup = "";
    let i = 0;
    while (i < len(labels)) {
        let e = labels[i];
        let r = labmap_put(m, e.name, e.sec, e.off);
        m = r.map;
        if (r.dup) { dup = e.name; 0; } else { 0; };
        i = i + 1;
    };
    { map: m, dup: dup }
};

def label_addr(lmap: [{name: str, sec: long, off: long}], code_len: long, pad: long, name: str) -> {ok: bool, addr: long} {
    let e = labmap_get(lmap, name);
    if (e.sec < 0) {
        { ok: false, addr: 0 }
    } else if (e.sec == 0) {
        { ok: true, addr: e.off }
    } else {
        { ok: true, addr: code_len + pad + e.off }
    }
};


def asm_assemble(text: str) -> {ok: bool, bytes: [long], error: str, times: [{ name: str, us: long, heap: long }]} {
    let t0 = clock_us();
    let h0 = heap_used();
    let lines = split(text, "\n");
    let t1 = clock_us();
    let h1 = heap_used();
    let items = [];
    let labels = [];
    let sec = 0;
    let offs = [0, 0];
    let li = 0;
    let err = "";
    while (li < len(lines)) {
        if (err != "") {
            li = len(lines);
            0
        } else {
            let st = asm_assemble_line(lines, li, sec, offs, items, labels, err);
            sec = st.sec;
            offs = st.offs;
            items = st.items;
            labels = st.labels;
            err = st.err;
            0
        };
        li = li + 1;
        0
    };
    let t2 = clock_us();
    let h2 = heap_used();
    if (err != "") {
        { ok: false, bytes: [], error: err,
          times: [ { name: "a:split", us: t1 - t0, heap: h1 - h0 },
                   { name: "a:encode", us: t2 - t1, heap: h2 - h1 } ] }
    } else {
        let lk = asm_link(items, labels);
        let t3 = clock_us();
        let h3 = heap_used();
        let tl: [{ name: str, us: long, heap: long }] =
            [ { name: "a:split", us: t1 - t0, heap: h1 - h0 },
              { name: "a:encode", us: t2 - t1, heap: h2 - h1 },
              { name: "a:link", us: t3 - t2, heap: h3 - h2 } ];
        let lsub = lk.times;
        let k = 0;
        while (k < len(lsub)) {
            let le = lsub[k];
            tl = push(tl, le);
            k = k + 1;
        };
        { ok: lk.ok, bytes: lk.bytes, error: lk.error, times: tl }
    }
};

def asm_assemble_line(lines: [str], li: long, sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str) -> {sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str} {
    let line = trim(lines[li]);
    let lno = li + 1;
    if (line == "") {
        asm_state(sec, offs, items, labels, err)
    } else if (substr(line, 0, 1) == "#") {
        asm_state_err(sec, offs, items, labels, lno, "unexpected comment (backend bug)")
    } else if (substr(line, len(line) - 1, 1) == ":") {
        asm_labdef(line, lno, sec, offs, items, labels, err)
    } else if (substr(line, 0, 1) == ".") {
        asm_dirline(line, lno, sec, offs, items, labels, err)
    } else {
        asm_maybe_labline(line, lno, sec, offs, items, labels, err)
    }
};

def asm_state(sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str) -> {sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str} {
    { sec: sec, offs: offs, items: items, labels: labels, err: err }
};

def asm_state_err(sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], lno: long, msg: str) -> {sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str} {
    { sec: sec, offs: offs, items: items, labels: labels, err: "L" + tostring(lno) + ": " + msg }
};

def asm_labdef(line: str, lno: long, sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str) -> {sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str} {
    let nm = trim(substr(line, 0, len(line) - 1));
    if (nm == "") {
        asm_state_err(sec, offs, items, labels, lno, "bad label")
    } else if (index_of(nm, " ") >= 0) {
        asm_state_err(sec, offs, items, labels, lno, "bad label")
    } else {
        asm_labdef_go(nm, lno, sec, offs, items, labels, err)
    }
};

def asm_labdef_go(nm: str, lno: long, sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str) -> {sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str} {
    asm_state(sec, offs, items, push(labels, { name: nm, sec: sec, off: offs[sec] }), err)
};

def asm_dirline(line: str, lno: long, sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str) -> {sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str} {
    let r = asm_directive(line, lno, sec, offs);
    if (r.err != "") {
        asm_state(r.sec, r.offs, items, labels, r.err)
    } else {
        asm_state(r.sec, r.offs, push(items, r.item), labels, err)
    }
};

def asm_maybe_labline(line: str, lno: long, sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str) -> {sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str} {
    let ci = index_of(line, ":");
    if (ci > 0) {
        asm_labline(line, lno, sec, offs, items, labels, err, ci)
    } else {
        asm_insnline(line, lno, sec, offs, items, labels, err)
    }
};

def asm_insnline(line: str, lno: long, sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str) -> {sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str} {
    let r = asm_content(line, lno, sec, offs);
    if (r.err != "") {
        asm_state(r.sec, r.offs, items, labels, r.err)
    } else {
        asm_state(r.sec, r.offs, push(items, r.item), labels, err)
    }
};

def asm_labline(line: str, lno: long, sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str, ci: long) -> {sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str} {
    let nm = trim(substr(line, 0, ci));
    let rest = trim(substr(line, ci + 1, len(line) - ci - 1));
    if (nm == "") {
        asm_state_err(sec, offs, items, labels, lno, "bad label")
    } else if (index_of(nm, " ") >= 0) {
        asm_state_err(sec, offs, items, labels, lno, "bad label")
    } else if (rest == "") {
        asm_state_err(sec, offs, items, labels, lno, "bad label")
    } else {
        asm_labline_go(nm, rest, lno, sec, offs, items, labels, err)
    }
};

def asm_labline_go(nm: str, rest: str, lno: long, sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str) -> {sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str} {
    asm_labline_content(nm, rest, lno, sec, offs, items, labels, err)
};

def asm_labline_content(nm: str, rest: str, lno: long, sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str) -> {sec: long, offs: [long], items: [{sec: long}], labels: [{name: str, sec: long, off: long}], err: str} {
    let lab_off = offs[sec];
    let r = asm_content(rest, lno, sec, offs);
    if (r.err != "") {
        asm_state(r.sec, r.offs, items, labels, r.err)
    } else {
        asm_state(r.sec, r.offs, push(items, r.item), push(labels, { name: nm, sec: sec, off: lab_off }), err)
    }
};

def asm_content(line: str, lno: long, sec: long, offs: [long]) -> {err: str, sec: long, offs: [long], item: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}} {
    if (substr(line, 0, 1) == ".") {
        asm_directive(line, lno, sec, offs)
    } else {
        asm_insn(line, lno, sec, offs)
    }
};

def asm_strdata(line: str, lno: long, sec: long, offs: [long], rest: str, nul: bool) -> {err: str, sec: long, offs: [long], item: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}} {
    if (asm_strdata_bad(rest)) {
        asm_strdata_err(line, lno, sec, offs)
    } else {
        asm_strdata_go(line, lno, sec, offs, substr(rest, 1, len(rest) - 2), nul)
    }
};

def asm_strdata_bad(rest: str) -> bool {
    if (len(rest) < 2) { true }
    else if (substr(rest, 0, 1) != "\"") { true }
    else if (substr(rest, len(rest) - 1, 1) != "\"") { true }
    else { false }
};

def asm_strdata_err(line: str, lno: long, sec: long, offs: [long]) -> {err: str, sec: long, offs: [long], item: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}} {
    { err: "L" + tostring(lno) + ": bad string literal", sec: sec, offs: offs, item: { sec: -1, off: 0, len: 0, kind: "", bytes: [], fix: [] } }
};

def asm_strdata_go(line: str, lno: long, sec: long, offs: [long], payload: str, nul: bool) -> {err: str, sec: long, offs: [long], item: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}} {
    let d = decode_str(payload);
    if (!(d.ok)) {
        { err: "L" + tostring(lno) + ": " + d.error, sec: sec, offs: offs, item: { sec: -1, off: 0, len: 0, kind: "", bytes: [], fix: [] } }
    } else {
        asm_strdata_emit(sec, offs, d.bytes, nul)
    }
};

def asm_strdata_emit(sec: long, offs: [long], bytes: [long], nul: bool) -> {err: str, sec: long, offs: [long], item: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}} {
    let bb = bytes;
    if (nul) {
        bb = push(bb, 0);
        0
    } else { 0 };
    asm_strdata_item(sec, offs, bb)
};

def asm_strdata_item(sec: long, offs: [long], bb: [long]) -> {err: str, sec: long, offs: [long], item: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}} {
    let item = { sec: sec, off: offs[sec], len: len(bb), kind: "data", bytes: bb, fix: [] };
    offs[sec] = offs[sec] + len(bb);
    { err: "", sec: sec, offs: offs, item: item }
};

def asm_directive(line: str, lno: long, sec: long, offs: [long]) -> {err: str, sec: long, offs: [long], item: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}} {
    let sp = index_of(line, " ");
    let dir = line;
    let rest = "";
    if (sp >= 0) {
        dir = substr(line, 0, sp);
        rest = trim(substr(line, sp + 1, len(line) - sp - 1));
        0
    } else { 0 };
    if (dir == ".text") {
        { err: "", sec: 0, offs: offs, item: { sec: -1, off: 0, len: 0, kind: "", bytes: [], fix: [] } }
    } else if (dir == ".globl") {
        { err: "", sec: sec, offs: offs, item: { sec: -1, off: 0, len: 0, kind: "", bytes: [], fix: [] } }
    } else if (dir == ".string") {
        asm_strdata(line, lno, sec, offs, rest, true)
    } else if (dir == ".ascii") {
        asm_strdata(line, lno, sec, offs, rest, false)
    } else if (dir == ".section") {
        asm_section(line, lno, sec, offs, rest)
    } else if (dir == ".quad") {
        asm_quad(line, lno, sec, offs, rest)
    } else {
        { err: "L" + tostring(lno) + ": unsupported directive '" + dir + "'", sec: sec, offs: offs, item: { sec: -1, off: 0, len: 0, kind: "", bytes: [], fix: [] } }
    }
};

def asm_section(line: str, lno: long, sec: long, offs: [long], rest: str) -> {err: str, sec: long, offs: [long], item: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}} {
    if (asm_section_bad(rest)) {
        asm_section_err(line, lno, sec, offs, rest)
    } else {
        asm_section_go(sec, offs, rest)
    }
};

def asm_section_bad(rest: str) -> bool {
    if (rest == ".rodata") { false }
    else if (rest == ".text") { false }
    else { true }
};

def asm_section_err(line: str, lno: long, sec: long, offs: [long], rest: str) -> {err: str, sec: long, offs: [long], item: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}} {
    { err: "L" + tostring(lno) + ": unsupported section '" + rest + "'", sec: sec, offs: offs, item: { sec: -1, off: 0, len: 0, kind: "", bytes: [], fix: [] } }
};

def asm_section_go(sec: long, offs: [long], rest: str) -> {err: str, sec: long, offs: [long], item: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}} {
    if (rest == ".rodata") {
        { err: "", sec: 1, offs: offs, item: { sec: -1, off: 0, len: 0, kind: "", bytes: [], fix: [] } }
    } else {
        { err: "", sec: 0, offs: offs, item: { sec: -1, off: 0, len: 0, kind: "", bytes: [], fix: [] } }
    }
};

def asm_quad(line: str, lno: long, sec: long, offs: [long], rest: str) -> {err: str, sec: long, offs: [long], item: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}} {
    if (asm_quad_bad(rest)) {
        asm_quad_err(line, lno, sec, offs, rest)
    } else {
        asm_quad_go(sec, offs, rest)
    }
};

def asm_quad_bad(rest: str) -> bool {
    if (!is_num_text(rest)) { true }
    else if (tonum(rest) < 0) { true }
    else { false }
};

def asm_quad_err(line: str, lno: long, sec: long, offs: [long], rest: str) -> {err: str, sec: long, offs: [long], item: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}} {
    if (!is_num_text(rest)) {
        { err: "L" + tostring(lno) + ": bad .quad value '" + rest + "'", sec: sec, offs: offs, item: { sec: -1, off: 0, len: 0, kind: "", bytes: [], fix: [] } }
    } else {
        { err: "L" + tostring(lno) + ": negative .quad value", sec: sec, offs: offs, item: { sec: -1, off: 0, len: 0, kind: "", bytes: [], fix: [] } }
    }
};

def asm_quad_go(sec: long, offs: [long], rest: str) -> {err: str, sec: long, offs: [long], item: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}} {
    let bytes = enc.le64(tonum(rest));
    let item = { sec: sec, off: offs[sec], len: len(bytes), kind: "data", bytes: bytes, fix: [] };
    offs[sec] = offs[sec] + len(bytes);
    { err: "", sec: sec, offs: offs, item: item }
};

def asm_insn(line: str, lno: long, sec: long, offs: [long]) -> {err: str, sec: long, offs: [long], item: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}} {
    let sp = index_of(line, " ");
    let tab = index_of(line, "\t");
    let cut = sp;
    if (tab >= 0) {
        if (sp < 0) { cut = tab; 0; }
        else if (tab < sp) { cut = tab; 0; }
        else { 0 };
        0
    } else { 0 };
    let mn = line;
    let rest = "";
    if (cut >= 0) {
        mn = substr(line, 0, cut);
        rest = trim(substr(line, cut + 1, len(line) - cut - 1));
        0
    } else { 0 };
    let ops = [];
    if (rest != "") {
        let texts = split_ops(rest);
        let i = 0;
        let ok = true;
        while (i < len(texts)) {
            let r = parse_operand(texts[i]);
            if (!(r.ok)) {
                ok = false;
                0
            } else {
                ops = push(ops, r.op);
                0
            };
            i = i + 1;
            0
        };
        if (!ok) {
            { err: "L" + tostring(lno) + ": bad operand", sec: sec, offs: offs, item: { sec: -1, off: 0, len: 0, kind: "", bytes: [], fix: [] } }
        } else {
            asm_encode(mn, ops, lno, sec, offs)
        }
    } else {
        asm_encode(mn, ops, lno, sec, offs)
    }
};

def asm_encode(mn: str, ops, lno: long, sec: long, offs: [long]) -> {err: str, sec: long, offs: [long], item: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}} {
    let r = enc.enc_insn(mn, ops);
    if (r.err != "") {
        { err: "L" + tostring(lno) + ": " + r.err + " in '" + mn + "'", sec: sec, offs: offs, item: { sec: -1, off: 0, len: 0, kind: "", bytes: [], fix: [] } }
    } else {
        let blen = len(r.bytes);
        let item = { sec: sec, off: offs[sec], len: blen, kind: "insn", bytes: r.bytes, fix: r.fix };
        offs[sec] = offs[sec] + blen;
        { err: "", sec: sec, offs: offs, item: item }
    }
};


def asm_link(items: [{sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}], labels: [{name: str, sec: long, off: long}]) -> {ok: bool, bytes: [long], error: str, times: [{ name: str, us: long, heap: long }]} {
    let lt0 = clock_us();
    let lh0 = heap_used();
    let code_len = 0;
    let ro_len = 0;
    let i = 0;
    while (i < len(items)) {
        let it = items[i];
        if (it.sec == 0) { code_len = code_len + it.len; 0; } else { 0 };
        if (it.sec == 1) { ro_len = ro_len + it.len; 0; } else { 0 };
        i = i + 1;
        0
    };
    let lm = labmap_build(labels);
    let lt1 = clock_us();
    let lh1 = heap_used();
    let lmap = lm.map;
    let start = labmap_get(lmap, "_start");
    if (lm.dup != "") {
        { ok: false, bytes: [], error: "duplicate label '" + lm.dup + "'",
          times: [ { name: "l:labmap", us: lt1 - lt0, heap: lh1 - lh0 } ] }
    } else if (start.sec != 0) {
        { ok: false, bytes: [], error: "no _start label (empty program?)",
          times: [ { name: "l:labmap", us: lt1 - lt0, heap: lh1 - lh0 } ] }
    } else {
        let pad = 0;
        let trail = code_len % 4096;
        if (trail != 0) { pad = 4096 - trail; 0; } else { 0 };
        let code = [];
        let ro = [];
        let err = "";
        let i = 0;
        while (i < len(items)) {
            if (err != "") {
                i = len(items);
                0
            } else {
            let it = items[i];
            if (it.sec == 0) {
                let r = patch_item(code, it, lmap, code_len, pad);
                if (r.err != "") {
                    err = r.err;
                    0
                } else {
                    code = r.bytes;
                    0
                };
                0
            } else if (it.sec == 1) {
                let rbytes = it.bytes;
                let j = 0;
                while (j < len(rbytes)) {
                    ro = push(ro, rbytes[j]);
                    j = j + 1;
                    0
                };
                0
            } else { 0 };
            i = i + 1;
            0
            };
        };
        if (err != "") {
            { ok: false, bytes: [], error: err,
              times: [ { name: "l:labmap", us: lt1 - lt0, heap: lh1 - lh0 } ] }
        } else {
            let lt2 = clock_us();
            let lh2 = heap_used();
            let eb = elf.elf_build(code, ro, start.off);
            let lt3 = clock_us();
            let lh3 = heap_used();
            { ok: true, bytes: eb, error: "",
              times: [ { name: "l:labmap", us: lt1 - lt0, heap: lh1 - lh0 },
                       { name: "l:patch", us: lt2 - lt1, heap: lh2 - lh1 },
                       { name: "l:elf", us: lt3 - lt2, heap: lh3 - lh2 } ] }
        }
    }
};

def patch_item(code: [long], it: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}, lmap: [{name: str, sec: long, off: long}], code_len: long, pad: long) -> {bytes: [long], err: str} {
    let bytes = it.bytes;
    let err = "";
    if (patch_item_isdata(it)) {
        patch_item_finish(code, bytes, err)
    } else {
        patch_item_insn(code, it, lmap, code_len, pad, bytes, err)
    }
};

def patch_item_isdata(it: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}) -> bool {
    if (it.kind == "insn") { false } else { true }
};

def patch_item_insn(code: [long], it: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}, lmap: [{name: str, sec: long, off: long}], code_len: long, pad: long, bytes: [long], err: str) -> {bytes: [long], err: str} {
    if (true) {
        patch_item_loop(code, it, lmap, code_len, pad, bytes, err)
    } else {
        patch_item_finish(code, bytes, err)
    }
};

def patch_item_loop(code: [long], it: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}, lmap: [{name: str, sec: long, off: long}], code_len: long, pad: long, bytes: [long], err: str) -> {bytes: [long], err: str} {
        let base = len(code);
        let fxlist = it.fix;
        let f = 0;
        while (f < len(fxlist)) {
            if (err != "") {
                f = len(fxlist);
                0
            } else {
            let fx = fxlist[f];
            let at = fx.off;
            if (fx.kind == "rel32") {
                let rr = patch_item_rel(lmap, code_len, pad, fx, bytes, base, it, at);
                bytes = rr.bytes;
                if (rr.err != "") { err = rr.err; 0; } else { 0 };
                0
            } else {
                let rk = patch_item_kind2(lmap, code_len, pad, fx, bytes, base, it, at);
                bytes = rk.bytes;
                if (rk.err != "") { err = rk.err; 0; } else { 0 };
                0
            };
            f = f + 1;
            0
            };
        };
    patch_item_finish(code, bytes, err)
};

def patch_item_kind2(lmap: [{name: str, sec: long, off: long}], code_len: long, pad: long, fx: {off: long, kind: str, lbl: str, lbl2: str}, bytes: [long], base: long, it: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}, at: long) -> {bytes: [long], err: str} {
    if (fx.kind == "rip32") {
        patch_item_rel(lmap, code_len, pad, fx, bytes, base, it, at)
    } else {
        patch_item_diff(lmap, code_len, pad, fx, bytes, base, it)
    }
};

def patch_item_rel(lmap: [{name: str, sec: long, off: long}], code_len: long, pad: long, fx: {off: long, kind: str, lbl: str, lbl2: str}, bytes: [long], base: long, it: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}, at: long) -> {bytes: [long], err: str} {
    let t = label_addr(lmap, code_len, pad, fx.lbl);
    if (!(t.ok)) {
        { bytes: bytes, err: "undefined label '" + fx.lbl + "'" }
    } else {
        let v = t.addr - (base + it.len);
        { bytes: patch32(bytes, at, v), err: "" }
    }
};

def patch_item_diff(lmap: [{name: str, sec: long, off: long}], code_len: long, pad: long, fx: {off: long, kind: str, lbl: str, lbl2: str}, bytes: [long], base: long, it: {sec: long, off: long, len: long, kind: str, bytes: [long], fix: [{off: long, kind: str, lbl: str, lbl2: str}]}) -> {bytes: [long], err: str} {
    let ta = label_addr(lmap, code_len, pad, fx.lbl);
    if (!(ta.ok)) {
        { bytes: bytes, err: "undefined label '" + fx.lbl + "'" }
    } else {
        let dd = patch_item_diff2(lmap, code_len, pad, fx, bytes, ta.addr);
        { bytes: dd.bytes, err: dd.err }
    }
};

def patch_item_diff2(lmap: [{name: str, sec: long, off: long}], code_len: long, pad: long, fx: {off: long, kind: str, lbl: str, lbl2: str}, bytes: [long], ta: long) -> {bytes: [long], err: str} {
    let tb = label_addr(lmap, code_len, pad, fx.lbl2);
    if (!(tb.ok)) {
        { bytes: bytes, err: "undefined label '" + fx.lbl2 + "'" }
    } else {
        { bytes: patch32(bytes, fx.off, ta - tb.addr), err: "" }
    }
};

def patch_item_finish(code: [long], bytes: [long], err: str) -> {bytes: [long], err: str} {
    { bytes: concat_bytes(code, bytes), err: err }
};

def patch32(bytes: [long], at: long, v: long) -> [long] {
    let b = enc.le32(v);
    let b0 = b;
    bytes[at] = b0[0];
    bytes[at + 1] = b0[1];
    bytes[at + 2] = b0[2];
    bytes[at + 3] = b0[3];
    bytes
};

def concat_bytes(a: [long], b: [long]) -> [long] {
    let i = 0;
    while (i < len(b)) {
        a = push(a, b[i]);
        i = i + 1;
    };
    a
};

def ycc_assemble(asm_text: str) -> {ok: bool, bytes: [long], octal: str, error: str, times: [{ name: str, us: long, heap: long }]} {
    let r = asm_assemble(asm_text);
    if (!(r.ok)) {
        { ok: false, bytes: [], octal: "", error: r.error, times: r.times }
    } else {
        { ok: true, bytes: r.bytes, octal: "", error: "", times: r.times }
    }
};

export { asm_assemble, ycc_assemble };
