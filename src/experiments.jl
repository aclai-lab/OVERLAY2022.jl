using SoleModelChecking
using ArgParse
using Random
using Plots, Plots.Measures
using CSV, Tables

# TODO: check dependencies
# TODO: provide the usage of this module without forcing to use flags

"""
    @realtime expr

A macro to evaluate an expression, discarding the resulting value, instead returning the
number of seconds it took to execute as a floating-point number.

Compilation time is not included.
"""
macro realtime(ex)
    quote
        # Compiler heuristic; compilation is forced.
        while false; end # Base.Experimental.@force_compile
        local elapsedtime = time_ns()
        Base.cumulative_compile_timing(true)
        local compile_elapsedtime = first(Base.cumulative_compile_time_ns())
        $(esc(ex))
        elapsedtime = time_ns() - elapsedtime
        Base.cumulative_compile_timing(false)
        compile_elapsedtime =
            first(Base.cumulative_compile_time_ns()) - compile_elapsedtime
        (elapsedtime - compile_elapsedtime) / 1e9
    end
end

"""
    mmcheck_experiment(M, fnumbers, fheight, fmemo; P, prfactor, reps, exp_params, rng)

Check `fnumbers` formulas on every model in `M` and return a `fmemo` x `fnumbers` matrix
    containing the time elapsed to model-checking every model against the nth formula;
    the ith row of this matrix refers to the ith value in `fmemo` (see arguments).

The formulas are generated with a maximum height: it is certain that all the
    formula trees will be tall exactly `fheight` if the `prfactor` is 0.0 while
    it's more likely to have lower heights when `prfactor` increases towards 1.0
    (see Arguments section).

    # Arguments
- `M::Vector{KripkeModel{T}}`: Kripke Models vector containing worlds with the same shape.
- `fnumbers::Integer`: number of formulas generated.
- `fheight::Integer`: maximum height of each generated formula.
- `fmemo::Vector{Int64}`: maximum (sub)formulas height a model will memoize.
    -1 means nothing is memoized, 0 refers only to the leaves, etc...
- `P::LetterAlphabet`: vector of Letter (which, currently, are just strings).
- `prfactor::Float64`: float between 0.0 and 1.0;
    it regulates the real generated-formulas' height: see [`SoleLogics.gen_formula`](@ref).
- `reps::Integer`: number of repetitions.
- `exp_params::Tuple`: tuple containing the name of generated files.
    See also [`driver`](@ref)
- `rng::Union{Integer,AbstractRNG}`: integer to initialize a new rng, or an rng.

# Examples

```jldoctest
julia> models = [gen_kmodel(20, 5, 5) for _ in 1:10]
julia> fnumbers = 10
julia> fheight = 4
julia> fmemo = [-1, 0, 1]
julia> mmcheck_experiment(models, fnumbers, fheight, fmemo)
```
"""
function mmcheck_experiment(
    M::Vector{KripkeModel{T}},
    fnumbers::Integer,
    fheight::Integer,
    fmemo::Vector{Int64};
    P::LetterAlphabet = SoleLogics.alphabet(MODAL_LOGIC),
    prfactor::Float64 = 0.0,
    reps::Integer = 1,
    exp_params::Tuple = (fnumbers),
    rng::Union{Integer,AbstractRNG} = 1337
) where {T<:AbstractWorld}
    times = fill(zero(Float64), length(fmemo), fnumbers)
    rng = (typeof(rng) <: Integer) ? Random.MersenneTwister(rng) : rng

    # Main computational cycle.
    for _ = 1:reps
        # Each _mmcheck_experiment returns a matrix of times.
        times =
            times + _mmcheck_experiment(
                M,
                fnumbers,
                fheight,
                fmemo,
                P = P,
                prfactor = prfactor,
                rng = rng,
            )
    end
    # Compute mean times.
    times = times ./ reps

    # Export times in a CSV file.
    CSV.write(
        "./outcomes/csv/$(join(exp_params, "_")).csv",
        Tables.table(times),
        append = true,
    )

    # Plots
    theme(:vibrant)
    fpath = "./outcomes/plots/"
    mkpath(fpath)

    # Nth formula vs cumulative time
    plt1 = plot()
    for m in eachindex(fmemo)
        plot!(
            plt1,
            1:fnumbers,
            cumsum(times[m, :]),
            labels = "memo: $(fmemo[m])",
            margins = 10mm,
            legend = :topleft
            # yaxis=:log10
        )
    end
    savefig(plt1, fpath * "simple-$(join(exp_params, "_")).png")

    # Nth formula vs istantaneous time
    plt2 = plot()
    for m in eachindex(fmemo)
        scatter!(
            plt2,
            1:fnumbers,
            times[m, :],
            labels = "memo: $(fmemo[m])",
            margins = 10mm,
            legend = :topleft,
            markersize = 2,
            markerstrokewidth = 0
            # yaxis=:log10
        )
    end
    savefig(plt2, fpath * "scatter-$(join(exp_params, "_")).png")

    # If you want to generate your own graphic, here you are the times matrix
    return times
end

# Computational core of mmcheck_experiment
function _mmcheck_experiment(
    M::Vector{KripkeModel{T}},
    fnumbers::Integer,
    fheight::Integer,
    fmemo::Vector{<:Number};
    P::LetterAlphabet = SoleLogics.alphabet(MODAL_LOGIC),
    prfactor::Float64 = 0.0,
    rng::AbstractRNG = Random.GLOBAL_RNG,
) where {T<:AbstractWorld}
    # Initialize time matrix
    times = fill(zero(Float64), length(fmemo), fnumbers)

    # Generate formulas
    fxs = [
        gen_formula(fheight, P = P, pruning_factor = prfactor, rng = rng)
        for _ in 1:fnumbers
    ]

    # For each memoization level `fmemo[m]`, `fnumbers` model checkings
    # are executed on every model `km`, keeping memoization among calls
    # and pushing the execution time in a new times-matrix row (`current_times`).
    for m in eachindex(fmemo)
        current_times = Float64[]

        for i = 1:fnumbers
            elapsed = zero(Float64)
            for km in M
                elapsed =
                    elapsed +
                    _timed_check_experiment(km, fxs[i], max_fmemo = fmemo[m])
            end
            push!(current_times, elapsed)
        end

        # A complete level of memoization has been tested.
        times[m, :] = current_times[:]
        # Memoization is completely cleaned up; this way next iterations will not cheat.
        for km in M
            empty!(memo(km))
        end
    end

    return times
end

# Model checking, timed with @realtime to avoid keeping track of compilation times.
function _timed_check_experiment(
    km::KripkeModel,
    fx::SoleLogics.Formula;
    max_fmemo = Inf,
)
    forget_list = Vector{SoleLogics.Node}()
    t = zero(Float64)

    if !haskey(memo(km), fhash(fx.tree))
        for psi in subformulas(fx.tree)
            if SoleLogics.height(psi) > max_fmemo
                push!(forget_list, psi)
            end

            t = t + @realtime if !haskey(memo(km), fhash(psi))
                _process_node(km, psi)
            end
        end
    end

    for h in forget_list
        k = fhash(h)
        if haskey(memo(km), k)
            empty!(memo(km, k))
            pop!(memo(km), k)
        end
    end

    return t
end

# Utility to transform "no,0,1,Inf" int [-1 0 1 `maxFheight]
function _parse_fmemo(fmemo, maxheight)
    fmemo = map(m -> m == "Inf" ? string(maxheight) : m, split(fmemo, ","))
    fmemo = map(m -> m != "no" ? tryparse(Int64,m) : -1, fmemo)
    unique!(fmemo)
    return fmemo
end

"""
    driver

Helper function to run the experiments from commandline through the specification
    of some flags. Run using --help to know all the available parameters.

# Examples

```
> julia --project=. src/experiments.jl --nmodels 10 --nworlds 10 --nletters 2 --fmaxheight 4 --nformulas 100 --prfactor 0.8 --nreps 10 --fmemo="no,0,1,2"
```
"""
function driver(args)
    rng = Random.MersenneTwister(args["rng"])

    letters = LetterAlphabet(collect(string.(['a':('a'+(args["nletters"]-1))]...)))

    # A "primer" Kripke Model is fixed, then models with different Evaluations set are generated
    primer = gen_kmodel(
        args["nworlds"],
        rand(rng, 1:rand(rng, 1:args["nworlds"])),
        rand(rng, 1:rand(rng, 1:args["nworlds"])),
        P = letters,
        rng = rng,
    )
    kms = [deepcopy(primer) for _ = 1:args["nmodels"]]
    for km in kms
        evaluations!(km, dispense_alphabet(worlds(km), P = letters, rng = rng))
    end

    fmemo = _parse_fmemo(args["fmemo"], args["fmaxheight"])
    println(typeof(fmemo))

    mmcheck_experiment(
        kms,
        args["nformulas"],
        args["fmaxheight"],
        fmemo,
        P = letters,
        prfactor = args["prfactor"],
        reps = args["nreps"],
        exp_params = Tuple([
            args["nmodels"],
            args["nworlds"],
            args["nletters"],
            args["fmaxheight"],
            args["nformulas"],
            args["prfactor"],
            args["nreps"],
            Threads.nthreads(),
        ]),
        rng = rng,
    )
end

# This defines how flags are parsed from the command line
function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--nmodels"
        help = "Number of kripke models"
        arg_type = Int
        required = true

        "--nworlds"
        help = "Number of worlds in each kripke model"
        arg_type = Int
        default = 10

        "--nletters"
        help = "Alphabet cardinality"
        arg_type = Int
        required = true

        "--fmaxheight"
        help = "Formula max height"
        arg_type = Int
        required = true

        "--fmemo"
        help = "Max memoized formulas height"
        required = true

        "--nformulas"
        help = "Number of formulas"
        arg_type = Int
        required = true

        "--prfactor"
        help = "Pruning factor to shorten generated formulas"
        arg_type = Float64
        default = 0.0

        "--nreps"
        help = "Number of repetitions"
        arg_type = Int
        default = 100

        "--rng"
        help = "Seed to reproduce the experiment"
        arg_type = Int
        default = 1337
    end

    return parse_args(s)
end

# Try to execute the experiments through `driver`,
# if some flags are provided
if length(ARGS) > 0
    driver(parse_commandline())
end
