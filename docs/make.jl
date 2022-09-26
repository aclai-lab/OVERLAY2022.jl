using OVERLAY2022
using Documenter

DocMeta.setdocmeta!(OVERLAY2022, :DocTestSetup, :(using OVERLAY2022); recursive = true)

makedocs(;
    modules = [OVERLAY2022],
    authors = "Mauro MILELLA, Giovanni PAGLIARINI, Andrea PARADISO, Eduard I. STAN",
    repo = "https://github.com/aclai-lab/OVERLAY2022.jl/blob/{commit}{path}#{line}",
    sitename = "OVERLAY2022.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://aclai-lab.github.io/OVERLAY2022.jl",
        assets = String[],
    ),
    pages = ["Home" => "index.md"],
)

deploydocs(; repo = "github.com/aclai-lab/OVERLAY2022.jl")
