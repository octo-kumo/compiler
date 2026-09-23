def stdin_fd() -> long { 0 };
def stdout_fd() -> long { 1 };
def stderr_fd() -> long { 2 };
def SEEK_SET() -> long { 0 };
def O_RDONLY() -> long { 0 };
def O_WRONLY() -> long { 1 };
def O_RDWR() -> long { 2 };
def O_CREAT() -> long { 64 };
def O_TRUNC() -> long { 512 };

def open(path: str, flags: long, mode: long) -> long {
    syscall(257, -100, path, flags, mode)
};

def chmod(path: str, mode: long) -> long {
    syscall(268, -100, path, mode)
};

def close(fd: long) -> long {
    syscall(3, fd)
};

def write(fd: long, buf: *long, count: long) -> long {
    syscall(1, fd, buf, count)
};

def write_str(fd: long, s: str, count: long) -> long {
    syscall(1, fd, s, count)
};

def write_data(fd: long, addr: long, n: long) -> long {
    let count = 0;
    let i = 0;
    while (i < n) {
        let w = syscall(1, fd, addr + i, 1);
        if (w != 1) {
            count = w;
            i = n;
        } else {
            count = count + 1;
            i = i + 1;
        };
    };
    count
};

def read(fd: long, buf: *long, count: long) -> long {
    syscall(0, fd, buf, count)
};

def exit(code: long) -> long {
    syscall(60, code)
};

export { stdin_fd, stdout_fd, stderr_fd, SEEK_SET, O_RDONLY, O_WRONLY, O_RDWR, O_CREAT, O_TRUNC, open, close, read, write, write_str, write_data, chmod, exit };
