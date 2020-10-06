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
