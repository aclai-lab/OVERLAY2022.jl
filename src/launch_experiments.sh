#!/bin/bash

# Utility script to execute multiple OVERLAY2022 experiments,
# specifying all the possible permutations of the specified 
# parametrizations.

# The following parameters are exactly those specified in 
# mmcheck_experiment (see the documentation).

exec_repetitions=(1000)
exec_pruning_factor=(0.2 0.5 0.8)
exec_n_models=(10)
exec_n_worlds_per_model=(10)
exec_n_letters=(2 4 8 16)
exec_max_formula_height=(1)
exec_n_formulas=(1000)
exec_n_threads=(1)

# Memoization levels considered in each experiment.
# If a memo-level is higher than the maximum formula height,
# it is automatically converted to this exact height.
fmemos="no,0,1,2,4,8"

for repetitions in "${exec_repetitions[@]}"; do
for n_formulas in "${exec_n_formulas[@]}"; do
for max_formula_height in "${exec_max_formula_height[@]}"; do
for pruning_factor in "${exec_pruning_factor[@]}"; do
for n_letters in "${exec_n_letters[@]}"; do
for n_models in "${exec_n_models[@]}"; do
for n_worlds_per_model in "${exec_n_worlds_per_model[@]}"; do
for n_threads in "${exec_n_threads[@]}"; do
        echo MODELS: $n_models NLETTERS: $n_letters MAXHEIGHT: $max_formula_height NFORMULAS: $n_formulas PRFACTOR: $pruning_factor REPS: $repetitions
        julia -t$n_threads --project=. src/experiments.jl --nmodels $n_models --nworlds $n_worlds_per_model --nletters $n_letters --fmaxheight $max_formula_height --fmemo=$fmemos --nformulas $n_formulas --prfactor $pruning_factor --nreps $repetitions
done
done
done
done
done
done
done
done