def isdigit(c: str) -> bool {
    let o = ord(c);
    if (o >= 48) {
        if (o <= 57) { true } else { false }
    } else { false }
};

def isalpha(c: str) -> bool {
    let o = ord(c);
    if (o >= 65) {
        if (o <= 90) { true }
        else if (o >= 97) {
            if (o <= 122) { true } else { false }
        } else if (o == 95) { true }
        else if (o >= 48) {
            if (o <= 57) { true } else { false }
        } else { false }
    } else if (o == 95) { true }
    else if (o >= 48) {
        if (o <= 57) { true } else { false }
    } else { false }
};

def isalnum(c: str) -> bool {
    if (isdigit(c)) { true } else { isalpha(c) }
};

def is_radix_ch(c: str, radix: long) -> bool {
    let ok = false;
    if (c == "_") { ok = true; 0; } else { 0; };
    if (radix == 2) {
        if (c == "0") { ok = true; 0; } else { 0; };
        if (c == "1") { ok = true; 0; } else { 0; };
        0
    } else {
        if (isdigit(c)) { ok = true; 0; } else { 0; };
        let o = ord(c);
        if (o >= 97) {
            if (o <= 102) { ok = true; 0; } else { 0; };
            0
        } else { 0; };
        if (o >= 65) {
            if (o <= 70) { ok = true; 0; } else { 0; };
            0
        } else { 0; };
        0
    };
    ok
};

def isspace(c: str) -> bool {
    if (c == " ") { true }
    else if (c == "\t") { true }
    else if (c == "\n") { true }
    else { c == "\r" }
};


def ispunct(c: str) -> bool {
    if (c == "(") { true }
    else if (c == ")") { true }
    else if (c == "{") { true }
    else if (c == "}") { true }
    else if (c == "[") { true }
    else if (c == "]") { true }
    else if (c == ",") { true }
    else if (c == ";") { true }
    else { c == ":" }
};

def mktok(t: str, v: str, line: long, col: long) -> { t: str, v: str, line: long, col: long } {
    { t: t, v: v, line: line, col: col }
};

def hexvalx(c: str) -> long {
    let o = ord(c);
    if (o >= 48) {
        if (o <= 57) { o - 48 }
        else if (o >= 65) {
            if (o <= 70) { o - 65 + 10 }
            else if (o >= 97) {
                if (o <= 102) { o - 97 + 10 } else { -1 }
            } else { -1 }
        } else { -1 }
    } else { -1 }
};

def twocharop(src: str, i: long) -> str {
    let two = substr(src, i, 2);
    if (two == "==") { two }
    else if (two == "!=") { two }
    else if (two == "<=") { two }
    else if (two == ">=") { two }
    else if (two == "&&") { two }
    else if (two == "||") { two }
    else if (two == "::") { two }
    else if (two == "..") { two }
    else if (two == "->") { two }
    else { "" }
};

def issingleop(c: str) -> bool {
    if (c == "+") { true }
    else if (c == "-") { true }
    else if (c == "*") { true }
    else if (c == slash()) { true }
    else if (c == "%") { true }
    else if (c == "<") { true }
    else if (c == ">") { true }
    else if (c == "=") { true }
    else if (c == ".") { true }
    else if (c == "!") { true }
    else if (c == "&") { true }
    else { c == "?" }
};

def slash() -> str { chr(47) };

def isdigitch(c: str) -> bool {
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

def tokenize(src: str) -> [{ t: str, v: str, line: long, col: long }] {
    let toks: [{ t: str, v: str, line: long, col: long }] = [];
    let i = 0;
    let n = len(src);
    let line = 1;
    let col = 1;
    while (i < n) {
        let c = substr(src, i, 1);
        if (isspace(c)) {
            if (c == "\n") { line = line + 1; col = 1; 0; }
            else { col = col + 1; 0; };
            i = i + 1;
            0
        } else if (isdigit(c)) {
            let start = i;
            let startcol = col;
            let radix = 0;
            if (c == "0") {
                let nxt = substr(src, i + 1, 1);
                if (nxt == "x") { radix = 16; 0; } else { 0; };
                if (nxt == "X") { radix = 16; 0; } else { 0; };
                if (nxt == "b") { radix = 2; 0; } else { 0; };
                if (nxt == "B") { radix = 2; 0; } else { 0; };
                0
            } else { 0; };
            if (radix > 0) {
                i = i + 2;
                col = col + 2;
                let rdone = false;
                while (rdone == false) {
                    if (i < n) {
                        if (is_radix_ch(substr(src, i, 1), radix)) { i = i + 1; col = col + 1; 0; }
                        else { rdone = true; 0; };
                        0
                    } else { rdone = true; 0 };
                };
                0
            } else {
            let ind = false;
            while (ind == false) {
                if (i < n) {
                    if (isdigit(substr(src, i, 1))) { i = i + 1; col = col + 1; 0; }
                    else { ind = true; 0; };
                    0
                } else { ind = true; 0 };
            };
            if (substr(src, i, 1) == ".") {
                if (substr(src, i + 1, 1) != ".") {
                    i = i + 1;
                    col = col + 1;
                    let frd = false;
                    while (frd == false) {
                        if (i < n) {
                            if (isdigit(substr(src, i, 1))) { i = i + 1; col = col + 1; 0; }
                            else { frd = true; 0; };
                            0
                        } else { frd = true; 0 };
                    };
                    0
                } else { 0 };
                0
            } else { 0 };
            let ec = substr(src, i, 1);
            let is_e = false;
            if (ec == "e") { is_e = true; 0; } else { 0; };
            if (ec == "E") { is_e = true; 0; } else { 0; };
            if (is_e) {
                let esign = 0;
                let sc = substr(src, i + 1, 1);
                if (sc == "+") { esign = 1; 0; } else { 0; };
                if (sc == "-") { esign = 1; 0; } else { 0; };
                if (isdigit(substr(src, i + 1 + esign, 1))) {
                    i = i + 1 + esign;
                    col = col + 1 + esign;
                    let exd = false;
                    while (exd == false) {
                        if (i < n) {
                            if (isdigit(substr(src, i, 1))) { i = i + 1; col = col + 1; 0; }
                            else { exd = true; 0; };
                            0
                        } else { exd = true; 0 };
                    };
                    0
                } else { 0 };
                0
            } else { 0 };
            0
            };
            toks = push(toks, mktok("num", substr(src, start, i - start), line, startcol));
            0
        } else if (isalpha(c)) {
            let start = i;
            let startcol = col;
            let inw = false;
            while (inw == false) {
                if (i < n) {
                    if (isalnum(substr(src, i, 1))) { i = i + 1; col = col + 1; 0; }
                    else { inw = true; 0; };
                    0
                } else { inw = true; 0 };
            };
            let word = substr(src, start, i - start);
            let ty = "id";
            if (word == "let") { ty = "kw"; 0; }
            else if (word == "const") { ty = "kw"; 0; }
            else if (word == "def") { ty = "kw"; 0; }
            else if (word == "if") { ty = "kw"; 0; }
            else if (word == "else") { ty = "kw"; 0; }
            else if (word == "while") { ty = "kw"; 0; }
            else if (word == "for") { ty = "kw"; 0; }
            else if (word == "foreach") { ty = "kw"; 0; }
            else if (word == "in") { ty = "kw"; 0; }
            else if (word == "return") { ty = "kw"; 0; }
            else if (word == "true") { ty = "kw"; 0; }
            else if (word == "false") { ty = "kw"; 0; }
            else if (word == "null") { ty = "kw"; 0; }
            else { 0 };
            toks = push(toks, mktok(ty, word, line, startcol));
            0
        } else if (c == "\"") {
            let startline = line;
            let startcol = col;
            i = i + 1;
            col = col + 1;
            let start = i;
            let open = true;
            let hasesc = false;
            while (open) {
                if (i < n) {
                    let ch = substr(src, i, 1);
                    if (ch == "\\") { hasesc = true; i = i + 2; col = col + 2; 0; }
                    else if (ch == "\"") { open = false; 0; }
                    else {
                        if (ch == "\n") { line = line + 1; col = 1; 0; }
                        else { col = col + 1; 0; };
                        i = i + 1;
                        0
                    };
                    0
                } else { open = false; 0 };
            };
            if (open) {
                puts("error: unterminated string literal\n");
                0
            } else { 0 };
            let raw = substr(src, start, i - start);
            i = i + 1;            col = col + 1;
            let buf = raw;
            if (hasesc) {
                let chunks: [str] = [];
                let k = 0;
                let rn = len(raw);
                while (k < rn) {
                    let rc = substr(raw, k, 1);
                    if (rc == "\\") {
                        let esc = substr(raw, k + 1, 1);
                        if (esc == "n") { chunks = push(chunks, "\n"); k = k + 2; 0; }
                        else if (esc == "t") { chunks = push(chunks, "\t"); k = k + 2; 0; }
                        else if (esc == "r") { chunks = push(chunks, "\r"); k = k + 2; 0; }
                        else if (esc == "x") {
                            let h1 = hexvalx(substr(raw, k + 2, 1));
                            let h2 = hexvalx(substr(raw, k + 3, 1));
                            if (h1 >= 0 && h2 >= 0) {
                                chunks = push(chunks, chr(h1 * 16 + h2));
                                k = k + 4;
                                0
                            } else {
                                chunks = push(chunks, esc);
                                k = k + 2;
                                0
                            };
                            0
                        }
                        else { chunks = push(chunks, esc); k = k + 2; 0; };
                        0
                    } else {
                        chunks = push(chunks, rc);
                        k = k + 1;
                        0
                    };
                };
                buf = join(chunks, "");
                0
            } else { 0 };
            toks = push(toks, mktok("str", buf, startline, startcol));
            0
        } else if (c == slash()) {
            if (substr(src, i + 1, 1) == slash()) {
                i = i + 2;
                col = col + 2;
                let done = false;
                while (done == false) {
                    if (i < n) {
                        if (substr(src, i, 1) != "\n") { i = i + 1; col = col + 1; 0; }
                        else { done = true; 0; };
                        0
                    } else { done = true; 0 };
                };
                0
            } else if (substr(src, i + 1, 1) == "*") {
                i = i + 2;
                col = col + 2;
                let open = true;
                while (open) {
                    if (i + 1 < n) {
                        if (substr(src, i, 2) == "*/") {
                            i = i + 2;
                            col = col + 2;
                            open = false;
                            0
                        } else {
                            let ch = substr(src, i, 1);
                            if (ch == "\n") { line = line + 1; col = 1; 0; }
                            else { col = col + 1; 0; };
                            i = i + 1;
                            0
                        };
                        0
                    } else { open = false; 0 };
                };
                if (open) {
                    puts("error: unterminated block comment\n");
                    0
                } else { 0 };
                0
            } else {
                toks = push(toks, mktok("op", slash(), line, col));
                i = i + 1;
                col = col + 1;
                0
            };
        } else {
            let two = twocharop(src, i);
            if (two != "") {
                toks = push(toks, mktok("op", two, line, col));
                i = i + 2;
                col = col + 2;
                0
            } else if (issingleop(c)) {
                toks = push(toks, mktok("op", c, line, col));
                i = i + 1;
                col = col + 1;
                0
            } else if (ispunct(c)) {
                toks = push(toks, mktok("punct", c, line, col));
                i = i + 1;
                col = col + 1;
                0
            } else {
                i = i + 1;
                col = col + 1;
                0
            };
        };
    };
    toks = push(toks, mktok("eof", "", line, col));
    toks
};

export { tokenize };
