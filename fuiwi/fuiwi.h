#ifndef FUIWI_H
#define FUIWI_H

#include <stddef.h>

typedef void *fuiwi_alloc_fn(void *user_data, size_t size);
typedef void fuiwi_free_fn(void *user_data, void *ptr, size_t size);

void *fuiwi_variable_new(void *user_data, fuiwi_alloc_fn alloc_fn);
void fuiwi_variable_del(void *variable, void *user_data, fuiwi_free_fn free_fn);
const char *fuiwi_variable_name(void *variable);
void fuiwi_variable_set_name(void *variable, const char *name);
double fuiwi_variable_value(void *variable);

void *fuiwi_expression_new(void *user_data, fuiwi_alloc_fn alloc_fn);
void fuiwi_expression_del(void *expression, void *user_data, fuiwi_free_fn free_fn);
int fuiwi_expression_add_term(void *expression, void *variable, double coefficient);
int fuiwi_expression_add_constant(void *expression, double constant);
void fuiwi_expression_reset(void *expression);

void *fuiwi_constraint_new(
    void *lhs,
    void *rhs,
    unsigned char relation,
    double strength,
    void *user_data,
    fuiwi_alloc_fn alloc_fn);
void fuiwi_constraint_del(void *constraint, void *user_data, fuiwi_free_fn free_fn);
int fuiwi_constraint_violated(void *constraint);

void *fuiwi_solver_new(void *user_data, fuiwi_alloc_fn alloc_fn);
void fuiwi_solver_del(void *solver, void *user_data, fuiwi_free_fn free_fn);
int fuiwi_solver_add_constraint(void *solver, void *constraint);
int fuiwi_solver_has_constraint(void *solver, void *constraint);
void fuiwi_solver_remove_constraint(void *solver, void *constraint);
int fuiwi_solver_add_edit_variable(void *solver, void *variable, double strength);
void fuiwi_solver_remove_edit_variable(void *solver, void *variable);
int fuiwi_solver_suggest_value(void *solver, void *variable, double value);
void fuiwi_solver_update_variables(void *solver);

#endif
