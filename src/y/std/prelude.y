def prelude_lines() -> [str] {
    [
        "def readline() -> str? {",
        "    let one: [byte; 1] = [0; 1];",
        "    let out: [byte] = [];",
        "    let go = true;",
        "    let got = false;",
        "    while (go) {",
        "        let n = syscall(0, 0, &one[0], 1);",
        "        if (n <= 0) {",
        "            go = false;",
        "            0;",
        "        } else {",
        "            got = true;",
        "            let c = one[0];",
        "            if (c == 10) {",
        "                go = false;",
        "                0;",
        "            } else {",
        "                out = push(out, c);",
        "                0;",
        "            };",
        "            0;",
        "        };",
        "    };",
        "    if (got) { some(from_bytes(out)) } else { none }",
        "};",
        "def clear_eof() -> long { 0 };",
        ""
    ]
};

def prelude_src() -> str {
    join(prelude_lines(), "\n")
};

def exec_lines() -> [str] {
    [
        "def exec(cmd: str) -> long {",
        "    let shpath = bytes(\"/bin/sh\");",
        "    shpath = push(shpath, 0);",
        "    let dashc = bytes(\"-c\");",
        "    dashc = push(dashc, 0);",
        "    let cmdb = bytes(cmd);",
        "    cmdb = push(cmdb, 0);",
        "    let argv: [long; 4] = [0; 4];",
        "    argv[0] = ptr_addr(&shpath[0]);",
        "    argv[1] = ptr_addr(&dashc[0]);",
        "    argv[2] = ptr_addr(&cmdb[0]);",
        "    argv[3] = 0;",
        "    let pid = syscall(57);",
        "    if (pid == 0) {",
        "        syscall(59, ptr_addr(&shpath[0]), ptr_addr(&argv[0]), 0);",
        "        syscall(60, 127);",
        "        0",
        "    } else if (pid < 0) {",
        "        0 - 1",
        "    } else {",
        "        let status: [long; 1] = [0; 1];",
        "        let w = syscall(61, pid, ptr_addr(&status[0]), 0, 0);",
        "        if (w < 0) { 0 - 1 } else { exit_status(status[0]) }",
        "    }",
        "};",
        "",
        "def exit_status(raw: long) -> long {",
        "    if (raw % 128 == 0) { (raw / 256) % 256 } else { 0 - 1 }",
        "};",
        ""
    ]
};

def prelude_names() -> [str] {
    ["readline", "clear_eof"]
};

def exec_names() -> [str] {
    ["exec"]
};

export { prelude_src, prelude_lines, prelude_names, exec_lines, exec_names };
