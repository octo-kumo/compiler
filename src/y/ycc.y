// ycc - the Y code compiler. Compiles Y source straight to a native
// executable (Linux x86_64) with no toolchain: no cc, no as, no ld,
// no libc. Usage: ycc [-o OUTPUT] [-S] [-t] [--no-exec] [-h] FILE
//   (no flags)   compile FILE to a native executable (default output: a.out)
//   -o OUTPUT    output path (executable, or .s file with -S)
//   -S           emit assembly only (stdout, or the -o file)
//   -t, --time   print per-phase time and heap use to stderr
//   -h, --help   show this text and exit

import lexer from "./lexer.y";
import parser from "./parser.y";
import nasm from "./asm.y";
import nativelib from "./native.y";


def parse_cli_args(argv: [str]) -> { out: str, files: [str], asm_only: bool, timing: bool, allow_exec: bool } {
    let out = "";
    let files = [];
    let asm_only = false;
    let timing = false;
    let allow_exec = true;
    let i = 1;    let n = len(argv);
    while (i < n) {
        let a = argv[i];
        if (a == "-o") {
            if (i + 1 < n) {
                i = i + 1;
                out = argv[i];
                0
            } else {
                puts("ycc: -o needs an argument\n");
                exit(1);
                0
            };
        } else if (a == "-S") {
            asm_only = true;
            0
        } else if (a == "--time" || a == "-t") {
            timing = true;
            0
        } else if (a == "--no-exec") {
            allow_exec = false;
            0
        } else if (a == "--help" || a == "-h") {
            puts("Usage: ycc [-o OUTPUT] [-S] [-t] [--no-exec] [-h] FILE\n");
            puts("  (no flags)   compile FILE to a native executable (default: a.out)\n");
            puts("  -o OUTPUT    output path (executable, or .s file with -S)\n");
            puts("  -S           emit assembly only (stdout, or the -o file)\n");
            puts("  -t, --time   print per-phase time and heap use to stderr\n");
            puts("  --no-exec    omit exec() -- the binary cannot reach a shell\n");
            puts("  -h, --help   show this text and exit\n");
            exit(0);
            0
        } else if (substr(a, 0, 1) == "-") {
            puts("ycc: unknown flag '" + a + "' (see ycc -h)\n");
            exit(1);
            0
        } else {
            files = push(files, a);
            0
        };
        i = i + 1;
    };
    { out: out, files: files, asm_only: asm_only, timing: timing, allow_exec: allow_exec }
};


def padr(s: str, w: long) -> str {
    let r = s;
    while (len(r) < w) { r = r + " "; };
    r
};

def padl(s: str, w: long) -> str {
    let r = s;
    while (len(r) < w) { r = " " + r; };
    r
};

def fmt_ms(us: long) -> str {
    let ms = us / 1000;
    let fr = us % 1000;
    let fs = tostring(fr);
    while (len(fs) < 3) { fs = "0" + fs; };
    tostring(ms) + "." + fs
};

def fmt_kb(b: long) -> str {
    tostring(b / 1024)
};

def print_phase_rows(times: [{ name: str, us: long, heap: long }]) -> long {
    let all = times;
    let i = 0;
    while (i < len(all)) {
        let e = all[i];
        eputs("  " + padr(e.name, 12) + padl(fmt_ms(e.us), 12) + " ms" + padl(fmt_kb(e.heap), 12) + " KB\n");
        i = i + 1;
    };
    0
};

def print_counter(name: str, v: long) -> long {
    eputs("  " + padr(name, 12) + padl(tostring(v), 12) + "\n");
    0
};


def print_native_errors(errors: [{ msg: str, line: long, col: long }], pre: long) -> long {
    let all = errors;
    let i = 0;
    while (i < len(all)) {
        let e = all[i];
        let ln = e.line;
        if (ln > pre) { ln = ln - pre; 0; } else { 0; };
        puts(tostring(ln) + ":" + tostring(e.col) + ": error: " + e.msg + "\n");
        i = i + 1;
    };
    0
};

def main(cmdline: [str]) -> long {
    let args = parse_cli_args(cmdline);
    let pargs = args;
    let out = pargs.out;
    let files = pargs.files;

    if (len(files) == 0) {
        puts("error: no input file (see ycc -h)\n");
        exit(1);
        1
    } else if (len(files) > 1) {
        puts("error: ycc compiles one program; use imports to combine files\n");
        exit(1);
        1
    } else {
        let file = files[0];
        let src = read_file(file);
        if (src == null) {
            puts("error: cannot read file '" + file + "'\n");
            exit(1);
            1
        } else {
            let src2 = unwrap(src);
            let last_slash = last_index_of(file, "/");
            let base_dir = ".";
            if (last_slash >= 0) {
                base_dir = substr(file, 0, last_slash);
                0
            } else { 0; };

            let t0 = clock_us();
            let h0 = heap_used();
            let tstart = t0;
            let hstart = h0;
            let dt: [{ name: str, us: long, heap: long }] = [];
            let nr = nativelib.native_resolve_x(src2, base_dir, 0, pargs.allow_exec);
            let ph = nativelib.phase_end(dt, "resolve", t0, h0);
            dt = ph.times; t0 = ph.t; h0 = ph.h;
            let nrsrc = nr.src;
            let nrimports = nr.imports;
            let nrpre = nr.pre;
            let toks = lexer.tokenize(nrsrc);
            ph = nativelib.phase_end(dt, "tokenize", t0, h0);
            dt = ph.times; t0 = ph.t; h0 = ph.h;
            let ast = parser.parse_program(toks);
            ph = nativelib.phase_end(dt, "parse", t0, h0);
            dt = ph.times; t0 = ph.t; h0 = ph.h;
            let r = nativelib.emit_program(ast, nrimports);
            let sub = r.times;
            let si = 0;
            while (si < len(sub)) {
                let se = sub[si];
                dt = push(dt, se);
                si = si + 1;
            };
            t0 = clock_us();
            h0 = heap_used();
            let rok = r.ok;
            if (!(rok)) {
                print_native_errors(r.errors, nrpre);
                exit(1);
                1
            } else if (pargs.asm_only) {
                let rasm = r.asm;
                if (len(out) == 0) {
                    puts(rasm);
                    0
                } else {
                    write_file(out, rasm);
                    0
                };
                ph = nativelib.phase_end(dt, "write", t0, h0);
                dt = ph.times;
                if (pargs.timing) {
                    eputs("ycc --time: " + file + "\n");
                    print_phase_rows(dt);
                    eputs("  " + padr("TOTAL", 12) + padl(fmt_ms(clock_us() - tstart), 12) + " ms" + padl(fmt_kb(heap_used() - hstart), 12) + " KB\n");
                    print_counter("src_bytes", len(nrsrc));
                    print_counter("tokens", len(toks));
                    print_counter("asm_bytes", len(rasm));
                    0
                } else { 0; };
                0
            } else {
                let rasm2 = r.asm;
                let ab = nasm.ycc_assemble(rasm2);
                ph = nativelib.phase_end(dt, "assemble", t0, h0);
                dt = ph.times; t0 = ph.t; h0 = ph.h;
                let asub = ab.times;
                let ai = 0;
                while (ai < len(asub)) {
                    let ae = asub[ai];
                    dt = push(dt, ae);
                    ai = ai + 1;
                };
                let abok = ab.ok;
                if (!(abok)) {
                    puts("error: assemble: " + ab.error + "\n");
                    exit(1);
                    1
                } else {
                    let out_path = out;
                    if (len(out_path) == 0) { out_path = "a.out"; 0; } else { 0; };
                    let abbytes = ab.bytes;
                    let ok = write_bytes(out_path, abbytes, 493);
                    ph = nativelib.phase_end(dt, "write", t0, h0);
                    dt = ph.times;
                    if (pargs.timing) {
                        eputs("ycc --time: " + file + "\n");
                        print_phase_rows(dt);
                        eputs("  " + padr("TOTAL", 12) + padl(fmt_ms(clock_us() - tstart), 12) + " ms" + padl(fmt_kb(heap_used() - hstart), 12) + " KB\n");
                        print_counter("src_bytes", len(nrsrc));
                        print_counter("tokens", len(toks));
                        print_counter("asm_bytes", len(rasm2));
                        print_counter("out_bytes", len(abbytes));
                        0
                    } else { 0; };
                    if (!(ok)) {
                        puts("error: writing '" + out_path + "' failed\n");
                        exit(1);
                        1
                    } else {
                        0
                    }
                }
            }
        }
    }
};

let result = main(argv());
