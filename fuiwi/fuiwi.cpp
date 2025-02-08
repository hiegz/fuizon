#include "kiwi/errors.h"
#include <kiwi/constraint.h>
#include <kiwi/expression.h>
#include <kiwi/solver.h>
#include <kiwi/symbolics.h>
#include <kiwi/term.h>
#include <kiwi/variable.h>

#include <new>

extern "C" {
#include "fuiwi.h"
}

void *fuiwi_variable_new(void *user_data, fuiwi_alloc_fn alloc_fn) {
    try {
        auto *variable = reinterpret_cast<kiwi::Variable *>(alloc_fn(user_data, sizeof(kiwi::Variable)));
        if (variable == nullptr)
            return nullptr;
        new (variable) kiwi::Variable();
        return variable;
    } catch (const std::bad_alloc &) {
        return nullptr;
    }
}

void fuiwi_variable_del(void *opaque_variable, void *user_data, fuiwi_free_fn free_fn) {
    auto *variable = reinterpret_cast<kiwi::Variable *>(opaque_variable);
    variable->~Variable();
    free_fn(user_data, variable, sizeof(kiwi::Variable));
}

double fuiwi_variable_value(void *opaque_variable) {
    return reinterpret_cast<kiwi::Variable *>(opaque_variable)->value();
}

void *fuiwi_expression_new(void *user_data, fuiwi_alloc_fn alloc_fn) {
    try {
        auto *expression = reinterpret_cast<kiwi::Expression *>(alloc_fn(user_data, sizeof(kiwi::Expression)));
        if (expression == nullptr)
            return nullptr;
        new (expression) kiwi::Expression();
        return expression;
    } catch (const std::bad_alloc &) {
        return nullptr;
    }
}

void fuiwi_expression_del(void *opaque_expression, void *user_data, fuiwi_free_fn free_fn) {
    auto *expression = reinterpret_cast<kiwi::Expression *>(opaque_expression);
    expression->~Expression();
    free_fn(user_data, expression, sizeof(kiwi::Expression));
}

int fuiwi_expression_add_term(void *opaque_expression, void *opaque_variable, double coefficient) {
    try {
        auto &expression = *reinterpret_cast<kiwi::Expression *>(opaque_expression);
        auto &variable = *reinterpret_cast<kiwi::Variable *>(opaque_variable);
        expression = expression + (coefficient * variable);
        return 0;
    } catch (const std::bad_alloc &) {
        return -5915;
    }
}

int fuiwi_expression_add_constant(void *opaque_expression, double constant) {
    try {
        auto &expression = *reinterpret_cast<kiwi::Expression *>(opaque_expression);
        expression = expression + constant;
        return 0;
    } catch (const std::bad_alloc &) {
        return -5915;
    }
}

void fuiwi_expression_reset(void *opaque_expression) {
    auto *expression = reinterpret_cast<kiwi::Expression *>(opaque_expression);
    expression->~Expression();
    new (expression) kiwi::Expression();
}

void *fuiwi_constraint_new(
    void *opaque_lhs,
    void *opaque_rhs,
    unsigned char relation,
    double strength,
    void *user_data,
    fuiwi_alloc_fn alloc_fn) {
    try {
        auto *constraint = reinterpret_cast<kiwi::Constraint *>(alloc_fn(user_data, sizeof(kiwi::Constraint)));
        if (constraint == nullptr)
            return nullptr;
        auto &lhs = *reinterpret_cast<kiwi::Expression *>(opaque_lhs);
        auto &rhs = *reinterpret_cast<kiwi::Expression *>(opaque_rhs);

        auto op = static_cast<enum kiwi::RelationalOperator>(relation);
        new (constraint) kiwi::Constraint(lhs - rhs, op, strength);

        return constraint;
    } catch (const std::bad_alloc &) {
        return nullptr;
    }
}

void fuiwi_constraint_del(void *opaque_constraint, void *user_data, fuiwi_free_fn free_fn) {
    auto *constraint = reinterpret_cast<kiwi::Constraint *>(opaque_constraint);
    constraint->~Constraint();
    free_fn(user_data, constraint, sizeof(kiwi::Constraint));
}

int fuiwi_constraint_violated(void *opaque_constraint) {
    return reinterpret_cast<kiwi::Constraint *>(opaque_constraint)->violated();
}

void *fuiwi_solver_new(void *user_data, fuiwi_alloc_fn alloc_fn) {
    try {
        auto *solver = reinterpret_cast<kiwi::Solver *>(alloc_fn(user_data, sizeof(kiwi::Solver)));
        if (solver == nullptr)
            return nullptr;
        new (solver) kiwi::Solver();
        return solver;
    } catch (const std::bad_alloc &) {
        return nullptr;
    }
}

void fuiwi_solver_del(void *opaque_solver, void *user_data, fuiwi_free_fn free_fn) {
    auto *solver = reinterpret_cast<kiwi::Solver *>(opaque_solver);
    solver->~Solver();
    free_fn(user_data, solver, sizeof(kiwi::Solver));
}

int fuiwi_solver_add_constraint(void *opaque_solver, void *opaque_constraint) {
    auto *solver = reinterpret_cast<kiwi::Solver *>(opaque_solver);
    auto *constraint = reinterpret_cast<kiwi::Constraint *>(opaque_constraint);

    try {
        solver->addConstraint(*constraint);
        return 0;
    } catch (kiwi::UnsatisfiableConstraint &) {
        return -1;
    } catch (const std::bad_alloc &) {
        return -5915;
    }
}

int fuiwi_solver_has_constraint(void *opaque_solver, void *opaque_constraint) {
    auto *solver = reinterpret_cast<kiwi::Solver *>(opaque_solver);
    auto *constraint = reinterpret_cast<kiwi::Constraint *>(opaque_constraint);

    return solver->hasConstraint(*constraint);
}

void fuiwi_solver_remove_constraint(void *opaque_solver, void *opaque_constraint) {
    auto *solver = reinterpret_cast<kiwi::Solver *>(opaque_solver);
    auto *constraint = reinterpret_cast<kiwi::Constraint *>(opaque_constraint);

    solver->removeConstraint(*constraint);
}

int fuiwi_solver_add_edit_variable(void *opaque_solver, void *opaque_variable, double strength) {
    auto *solver = reinterpret_cast<kiwi::Solver *>(opaque_solver);
    auto *variable = reinterpret_cast<kiwi::Variable *>(opaque_variable);

    try {
        solver->addEditVariable(*variable, strength);
        return 0;
    } catch (const std::bad_alloc &) {
        return -5915;
    }
}

void fuiwi_solver_remove_edit_variable(void *opaque_solver, void *opaque_variable) {
    auto *solver = reinterpret_cast<kiwi::Solver *>(opaque_solver);
    auto *variable = reinterpret_cast<kiwi::Variable *>(opaque_variable);

    solver->removeEditVariable(*variable);
}

int fuiwi_solver_suggest_value(void *opaque_solver, void *opaque_variable, double value) {
    auto *solver = reinterpret_cast<kiwi::Solver *>(opaque_solver);
    auto *variable = reinterpret_cast<kiwi::Variable *>(opaque_variable);

    try {
        solver->suggestValue(*variable, value);
        return 0;
    } catch (const std::bad_alloc &) {
        return -5915;
    }
}

void fuiwi_solver_update_variables(void *opaque_solver) {
    reinterpret_cast<kiwi::Solver *>(opaque_solver)->updateVariables();
}
