#=
    This script purpose is to facilitate the user to compile all the needed dependencies

    SoleAlphabet
    SoleWorlds
    SoleTraits
    SoleLogics
    SoleModelChecking
=#

using Pkg

# Unregistered packages
Pkg.add(url="https://github.com/aclai-lab/SoleTraits.jl")
Pkg.add(url="https://github.com/aclai-lab/SoleAlphabets.jl", rev="dev")
Pkg.add(url="https://github.com/aclai-lab/SoleWorlds.jl", rev="worlds/mauro")
Pkg.add(url="https://github.com/aclai-lab/SoleLogics.jl", rev="refactoring/mauro")
Pkg.add(url="https://github.com/aclai-lab/SoleModelChecking.jl", rev="mfmm/mauro")

# Registered packages
Pkg.instantiate()
