module SiriusBenchBot

import GitHub, HTTP, YAML, Markdown, JSON
import OrderedCollections: OrderedDict
import Sockets: IPv4
import Base: RefValue, shell_split

# If a comment matches this regex, it starts a bench
const trigger = r".*@electronic-structure run.*"ms

# We push a commit to this repo to trigger pipelines.
const benchmark_repo = "git@gitlab.com:cscs-ci/electronic-structure/benchmarking.git"

# Just keep the auth bit as a global const value, but defer logging in to starting the
# server, so keep it around as a Union for now.
const auth = RefValue{Union{Nothing,GitHub.Authorization}}(nothing)

"""
User-provided config options.
"""
struct ConfigOptions
    reference_ref::Union{Nothing,String}
    reference_spec::Union{Nothing,String}
    reference_cmd::Union{Nothing,Vector{String}}
    spec::Union{Nothing,String}
    cmd::Union{Nothing,Vector{String}}
end

ConfigOptions() = ConfigOptions(nothing, nothing, nothing, nothing, nothing)

function dict_to_settings(dict)
    # top level spec / cmd
    default_spec = get(dict, "spec", nothing)
    default_cmd_str = get(dict, "cmd", nothing)
    default_cmd = default_cmd_str === nothing ? nothing : shell_split(default_cmd_str)

    # reference level settings
    if (reference = get(dict, "reference", nothing)) !== nothing
        reference_spec = get(reference, "spec", nothing)
        reference_cmd_str = get(reference, "cmd", nothing)
        reference_cmd = reference_cmd_str === nothing ? nothing : shell_split(reference_cmd_str)
        reference_ref = get(reference, "ref", nothing)
    else
        reference_spec = nothing
        reference_cmd = nothing
        reference_ref = nothing
    end

    if reference_spec === nothing
        reference_spec = default_spec
    end

    if reference_cmd === nothing
        reference_cmd = default_cmd
    end

    # current level settings
    if (current = get(dict, "current", nothing)) !== nothing
        current_spec = get(current, "spec", nothing)
        current_cmd_str = get(current, "cmd", nothing)
        current_cmd = current_cmd_str === nothing ? nothing : shell_split(current_cmd_str)
    else
        current_spec = nothing
        current_cmd = nothing
    end

    if current_spec === nothing
        current_spec = default_spec
    end

    if current_cmd === nothing
        current_cmd = default_cmd
    end

    return ConfigOptions(
        reference_ref,
        reference_spec,
        reference_cmd,
        current_spec,
        current_cmd
    )
end

"""
    options_from_comment("some comment") -> ConfigOptions

Parse a comment as markdown, find the first top-level code block,
parse it as yaml for configuring the build.
"""
function options_from_comment(comment::AbstractString)
    try
        parsed_markdown = Markdown.parse(comment)

        # Look for a top-level code block
        code_block_idx = findfirst(x -> typeof(x) == Markdown.Code, parsed_markdown.content)
        code_block_idx === nothing && return ConfigOptions()
        
        # If found, try to parse it as yaml and extract some config options
        code_block::Markdown.Code = parsed_markdown.content[code_block_idx]

        return dict_to_settings(YAML.load(code_block.code))
    catch e
        @warn e
        return ConfigOptions()
    end
end

function handle_comment(event, phrase::RegexMatch)
    if event.kind == "issue_comment" && !haskey(event.payload["issue"], "pull_request")
        return HTTP.Response(400, "nanosoldier jobs cannot be triggered from issue comments (only PRs or commits)")
    end
    if haskey(event.payload, "action") && !in(event.payload["action"], ("created", "opened"))
        return HTTP.Response(204, "no action taken (submission was from an edit, close, or delete)")
    end

    # Get user-provided options
    config = options_from_comment(phrase.match)

    # Get the target data
    if event.kind == "commit_comment"
        # When commenting on a commit, the user should provide the ref themselves
        current_repo = event.repository.full_name
        current_sha = event.payload["comment"]["commit_id"]
        reference_repo = event.repository.full_name
        reference_commit = GitHub.commit(reference_repo, config.reference_ref, auth = auth[])
        reference_sha = reference_commit.sha
        fromkind = :commit
        prnumber = nothing
    elseif event.kind == "pull_request"
        current_repo = event.payload["pull_request"]["head"]["repo"]["full_name"]
        current_sha = event.payload["pull_request"]["head"]["sha"]
        reference_repo = event.payload["pull_request"]["base"]["repo"]["full_name"]
        reference_sha = event.payload["pull_request"]["base"]["sha"]
        fromkind = :pr
        prnumber = event.payload["pull_request"]["number"]
    elseif event.kind == "issue_comment"
        pr = GitHub.pull_request(event.repository, event.payload["issue"]["number"], auth = auth[])
        current_repo = pr.head.repo.full_name
        current_sha = pr.head.sha
        reference_repo = pr.base.repo.full_name
        reference_sha = pr.base.sha
        fromkind = :pr
        prnumber = pr.number
    else
        return HTTP.Response(200)
    end

    reference = OrderedDict(
        "spec" => something(config.reference_spec, "sirius@develop"),
        "cmd" => something(config.reference_cmd, ["sirius.scf"]),
        "repo" => reference_repo,
        "sha" => reference_sha
    )

    current = OrderedDict(
        "spec" => something(config.spec, "sirius@develop"),
        "cmd" => something(config.cmd, ["sirius.scf"]),
        "repo" => current_repo,
        "sha" => current_sha
    )

    report_to = OrderedDict(
        "repository" => event.repository.full_name,
        "type" => prnumber === nothing ? "commit" : "pr"
    )

    if prnumber !== nothing
        report_to["issue"] = prnumber
    end

    setup = OrderedDict(
        "reference" => reference,
        "current" => current,
        "report_to" => report_to
    )

    bench_setup = JSON.json(setup, 4)

    # Create the benchmark
    cd(mktempdir()) do
        run(`git clone $benchmark_repo benchmarking`)

        cd("benchmarking") do
            open("benchmark.json", "w") do io
                print(io, bench_setup)
            end

            run(`git add -A`)
            run(`git commit --allow-empty -m "Benchmark $current_sha vs $reference_sha"`)
            run(`git push`)
        end
    end

    comment_params = Dict{String, Any}("body" =>
        """
        Benchmark started with the following settings:

        ```json
        $bench_setup
        ```
        """
    )

    GitHub.create_comment(
        event.repository,
        prnumber === nothing ? current_sha : prnumber,
        fromkind;
        auth = auth[],
        params = comment_params
    )

    return HTTP.Response(200)
end

function start_server(address = IPv4(0,0,0,0), port = 8080)
    auth[] = GitHub.authenticate(ENV["GITHUB_AUTH"])
    listener = GitHub.CommentListener(handle_comment, trigger; auth = auth[], secret = ENV["MY_SECRET"])
    GitHub.run(listener, address, port)
end

end # module
