#include "ast.h"
#include "ast_debug.h"
#include "lib.h"
#include "parser.h"
#include "parser_debug.h"
#include "typecheck.h"
#include "vm.h"
#include <stdint.h>
#include <stdio.h>

#include <stdio.h>

void run_tc(Expr *expr) {
    TCVarTypeScope global_scope = {0};
    map_init(&global_scope.variables);
    populate_types(&global_scope);
    typecheck_result_t res = tc_expr(expr, &global_scope);
    if (res.is_ok) {
        printf("Type check successful. Type: %s\n", type_t_to_str(res.type));
    } else {
        printf("Type check failed: %s\n", res.error_message);
        ast_print_code(stdout, res.error_expr, 0);
        printf("\n");
    }
    map_free(&global_scope.variables);
}

void run_vm(Expr *expr) {
    VM vm;
    vm_init(&vm);
    VMValue *output = vm_execute(&vm.globals, expr);
    printf("\n\nResult: ");
    val_print(output);
    vm_scope_free(&vm.globals);
    val_free(output);
}

char *read_file(const char *filename) {
    FILE *f = fopen(filename, "r");
    if (!f) {
        fprintf(stderr, "Failed to open file: %s\n", filename);
        return NULL;
    }
    fseek(f, 0, SEEK_END);
    long length = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *buffer = malloc(length + 1);
    if (!buffer) {
        fprintf(stderr, "Failed to allocate memory for file: %s\n", filename);
        fclose(f);
        return NULL;
    }
    fread(buffer, 1, length, f);
    buffer[length] = '\0';
    fclose(f);
    return buffer;
}

char *read_stdin() {
    size_t capacity = 1024;
    size_t length = 0;
    char *buffer = malloc(capacity);
    if (!buffer) {
        fprintf(stderr, "Failed to allocate memory for stdin\n");
        return NULL;
    }
    int c;
    while ((c = getchar()) != EOF) {
        if (length + 1 >= capacity) {
            capacity *= 2;
            char *new_buffer = realloc(buffer, capacity);
            if (!new_buffer) {
                fprintf(stderr, "Failed to reallocate memory for stdin\n");
                free(buffer);
                return NULL;
            }
            buffer = new_buffer;
        }
        buffer[length++] = (char)c;
    }
    buffer[length] = '\0';
    return buffer;
}

int main(int argc, char *argv[]) {
    char *file = argc > 1 ? argv[1] : NULL;
    char *input = NULL;
    if (file) {
        printf("Reading file: %s\n", file);
        input = read_file(file);
        if (!input) {
            fprintf(stderr, "Failed to read file: %s\n", file);
            return 1;
        }
    } else {
        input = read_stdin();
        if (!input) {
            fprintf(stderr, "Failed to read from stdin\n");
            return 1;
        }
    }
    ast_parser_result_t res = ast_parse_expr_block(input);
    if (res.is_some) {
        printf("success :: remaining='%s'\n", res.remaining);
        ast_walk(res.value, 0);
        ast_print_code(stdout, res.value, 0);
        printf("\n\n");
        run_tc(res.value);
        run_vm(res.value);
    } else {
        printf("failed :: remaining='%s'\n", res.remaining);
    }
    printf("\ncomplete\n");
    ast_free(res.value);
}

void test_parser() {
    char *input = "-12 -455";

    parser_result_t num = parse_long(input);
    printf("res=%ld rem='%s'\n", (long)(uintptr_t)num.value, num.remaining);
    parser_result_t num2 = parse_long(num.remaining);
    printf("res=%ld rem='%s'\n", (long)(uintptr_t)num2.value, num2.remaining);
    parser_result_t num3 = parse_long(num2.remaining);
    printf("res.is_some=%d res.value=%ld rem='%s'\n\n", num3.is_some,
           (long)(uintptr_t)num3.value, num3.remaining);

    parser_result_t res_many = parse_many(parse_long, input);
    if (res_many.is_some) {
        char *s = long_list_to_str(res_many.value);
        printf("Parsed many numbers: %s\n", s);
        free(s);
        free_list(res_many.value);
    } else {
        printf("Failed to parse many numbers.\n");
    }
}