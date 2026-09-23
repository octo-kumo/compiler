import elfenc from "./enc64.y";

def elf_build(code: [long], rodata: [long], entry_off: long) -> [long] {
    let code_off = 120;
    let base = 4194304;
    let out = [];
    let codesz = len(code);
    let codetrail = codesz % 4096;
    let codepad = 0;
    if (codetrail != 0) { codepad = 4096 - codetrail; 0; } else { 0 };
    let rosz = len(rodata) + 8;
    let rotrail = rosz % 4096;
    let ropad = 0;
    if (rotrail != 0) { ropad = 4096 - rotrail; 0; } else { 0 };
    let total = code_off + codesz + codepad + rosz + ropad;
    let entry = base + code_off + entry_off;
    out = push_bytes(out, [127, 69, 76, 70, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    out = push_le16(out, 2);
    out = push_le16(out, 62);
    out = push_le32(out, 1);
    out = push_le64(out, entry);
    out = push_le64(out, 64);
    out = push_le64(out, 0);
    out = push_le32(out, 0);
    out = push_le16(out, 64);
    out = push_le16(out, 56);
    out = push_le16(out, 1);
    out = push_le16(out, 0);
    out = push_le16(out, 0);
    out = push_le16(out, 0);
    out = push_le32(out, 1);
    out = push_le32(out, 5);
    out = push_le64(out, 0);
    out = push_le64(out, base);
    out = push_le64(out, base);
    out = push_le64(out, total);
    out = push_le64(out, total);
    out = push_le64(out, 4096);
    out = push_bytes(out, code);
    let p = 0;
    while (p < codepad) {
        out = push(out, 0);
        p = p + 1;
        0
    };
    out = push_bytes(out, rodata);
    out = push_bytes(out, [0, 0, 0, 0, 0, 0, 0, 0]);
    let q = 0;
    while (q < ropad) {
        out = push(out, 0);
        q = q + 1;
        0
    };
    out
};

def push_bytes(out: [long], bytes: [long]) -> [long] {
    let i = 0;
    while (i < len(bytes)) {
        out = push(out, bytes[i]);
        i = i + 1;
        0
    };
    out
};

def push_le16(out: [long], v: long) -> [long] {
    out = push(out, elfenc.byte_at(v, 0));
    out = push(out, elfenc.byte_at(v, 1));
    out
};

def push_le32(out: [long], v: long) -> [long] {
    out = push(out, elfenc.byte_at(v, 0));
    out = push(out, elfenc.byte_at(v, 1));
    out = push(out, elfenc.byte_at(v, 2));
    out = push(out, elfenc.byte_at(v, 3));
    out
};

def push_le64(out: [long], v: long) -> [long] {
    out = push(out, elfenc.byte_at(v, 0));
    out = push(out, elfenc.byte_at(v, 1));
    out = push(out, elfenc.byte_at(v, 2));
    out = push(out, elfenc.byte_at(v, 3));
    out = push(out, elfenc.byte_at(v, 4));
    out = push(out, elfenc.byte_at(v, 5));
    out = push(out, elfenc.byte_at(v, 6));
    out = push(out, elfenc.byte_at(v, 7));
    out
};

export { elf_build };
