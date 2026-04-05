#include "ast.h"
#include "type.h"
#include "typecheck.h"
#include "vm.h"
#include <stdio.h>

#define DEFINE_EXTERNAL_FUNC(name, param_name, param_type_base,                \
                             return_type_base, body_code)                      \
    /* 1. The actual C implementation */                                       \
    VMValue *external_##name(VMVariableScope *scope) {                         \
        VMValue *param_name = vm_scope_get(scope, #param_name);                \
        body_code                                                              \
    }                                                                          \
    /* 2. The Type definition */                                               \
    type_t *name##_type = &(type_t){                                           \
        .base = VAL_FUNC,                                                      \
        .as.func =                                                             \
            {                                                                  \
                .param_count = 1,                                              \
                .param_types =                                                 \
                    (type_t *[]){&(type_t){.base = param_type_base}},          \
                .return_type = &(type_t){.base = return_type_base},            \
            },                                                                 \
    };                                                                         \
    /* 3. The VMValue Function Object */                                       \
    VMValue *__external_##name##_func = &(VMValue){                            \
        .type = VAL_FUNC,                                                      \
        .data.func = &(Expr){                                                  \
            .kind = EXPR_EFUNC,                                                \
            .as.efunc =                                                        \
                {                                                              \
                    .param_count = 1,                                          \
                    .param_names = (char *[]){#param_name},                    \
                    .param_types =                                             \
                        (type_t *[]){&(type_t){.base = param_type_base}},      \
                    .body = (void *)external_##name,                           \
                    .external = true,                                          \
                },                                                             \
        }};

DEFINE_EXTERNAL_FUNC(print, x, _VAL_INFERRED, VAL_NULL, {
    if (x) {
        printf("[print] ");
        val_print(x);
        printf("\n");
    } else {
        printf("print: missing argument 'x'\n");
    }
    return nval(VAL_NULL);
});
DEFINE_EXTERNAL_FUNC(tostring, x, _VAL_INFERRED, VAL_STR, {
    if (x) {
        VMValue *result = nval(VAL_STR);
        result->data.s = strdup(val_to_str(x));
        return result;
    } else {
        printf("tostring: missing argument 'x'\n");
        return nval(VAL_NULL);
    }
});
DEFINE_EXTERNAL_FUNC(typeof, x, _VAL_INFERRED, VAL_TYPE, {
    if (x) {
        VMValue *result = nval(VAL_TYPE);
        result->data.type = val_type(x);
        return result;
    } else {
        printf("typeof: missing argument 'x'\n");
        return nval(VAL_NULL);
    }
});

void populate_types(TCVarTypeScope *scope) {
    map_set(&scope->variables, "print", print_type);
    map_set(&scope->variables, "tostring", tostring_type);
    map_set(&scope->variables, "typeof", typeof_type);
}
void populate_scope(VMVariableScope *scope) {
    map_set(&scope->variables, "print", __external_print_func);
    map_set(&scope->variables, "tostring", __external_tostring_func);
    map_set(&scope->variables, "typeof", __external_typeof_func);
}