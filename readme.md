# SIRIUS bench bot

A bot for triggering benchmarks for [SIRIUS](https://github.com/electronic-structure/SIRIUS/).

## How to trigger it

Comment on a pull request with 

> @electronic-structure run

and it will build the reference commit (i.e. the target branch of the PR) and the last PR commit, run benchmarks, and report back in the comments.

To change the build and run behavior, add a top-level code block to your comment in YAML. For instance:

> @electronic-structure run
> 
> ```yaml
> spec: sirius@develop ^intel-mkl
> cmd: ['sirius.scf', '--control.processing_unit=gpu']
> ```

will use the provided spec in spack to build both the reference and current commit, and will run using the `--control.processing_unit=gpu` flag.

You can also change the options for the reference and current commit separately:

> @electronic-structure run
> 
> ```yaml
> current:
>   spec: sirius@develop ^intel-mkl
>   cmd: ['sirius.scf', '--control.processing_unit=gpu']
> 
> reference:
>   spec: sirius@develop ^openblas threads=openmp
>   cmd: ['sirius.scf', '--control.processing_unit=cpu']
> ```

## How to install it
Have a webserver and install `julia` and `git` on it.

Install SiriusBenchBot.jl using

```
$ julia
] add https://github.com/haampie/SiriusBenchBot.jl.git
```

Make sure ssh keys are set up such that git can push to the benchmarking
repo `SiriusBenchBot.benchmark_repo`.

If you're on a vm, it's useful to install nginx as a proxy (`proxy_pass`) and certbot
to enable https. The julia server should run as a non-privileged user on non-privileged
port such as 8080; nginx will just forward data to port 80 / 443.

Set the following env variables:
- `GITHUB_AUTH`: a personal access token of a user with minimal access to the GitHub repo.
- `MY_SECRET`: the GitHub secret for webhooks.

Start the julia server with
```julia
julia> import SiriusBenchBot

julia> SiriusBenchBot.start_server()
```
which by default listens on localhost port 8080.

In your GitHub repo go to `Settings` > `Webhooks` and create a new webhook with payload url pointing
to your server, content type `json`, secret same as the `MY_SECRET` env variable, and triggers
for "Commit comments", "Issue comments", "Pull request review comments".