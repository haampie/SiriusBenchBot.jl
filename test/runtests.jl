using Test

import SiriusBenchBot: options_from_comment

@testset "Trigger comments" begin

    @testset "No yaml" begin
        no_options = """
            Here is some comment

            @siriusbot run
            """

        result = options_from_comment(no_options)

        @test result.reference_spec === result.reference_args === result.spec === result.args === nothing
    end

    @testset "Only top-level options" begin
        only_top_level = """
            Here is some comment

            @siriusbot run

            ```
            spec: sirius@develop ^spla@2.0.0
            ```
            """

        result = options_from_comment(only_top_level)

        @test result.reference_spec == result.spec == "sirius@develop ^spla@2.0.0"
        @test result.reference_args === result.args === nothing
    end

    @testset "All level options" begin
        all_level_options = """
            Here is some comment

            @siriusbot run

            ```
            spec: sirius@develop ^spla@2.0.0
            args: ["--some-arg", "--another"]

            current:
                spec: sirius@develop +new_feature
            
            reference:
                args: ["--different", "--arguments"]
            ```
            """

        result = options_from_comment(all_level_options)

        @test result.reference_spec == "sirius@develop ^spla@2.0.0"
        @test result.reference_args == ["--different", "--arguments"]
        @test result.spec == "sirius@develop +new_feature"
        @test result.args == ["--some-arg", "--another"]
    end

    @testset "No defaults" begin
        all_level_options = """
            Here is some comment

            @siriusbot run

            ```
            current:
                spec: sirius@develop +new_feature
                args: ["-x", "-y"]
            
            reference:
                spec: "sirius@6.5.4"
                args: ["-a", "-b"]
            ```
            """

        result = options_from_comment(all_level_options)

        @test result.reference_spec == "sirius@6.5.4"
        @test result.reference_args == ["-a", "-b"]
        @test result.spec == "sirius@develop +new_feature"
        @test result.args == ["-x", "-y"]
    end

    @testset "Invalid YAML" begin
        invalid_yaml = """
            Here is some comment

            @siriusbot run

            ```
            a:b:c:d"aergaerg"
            ```
            """
        result = options_from_comment(invalid_yaml)

        @test result.reference_spec === result.reference_args === result.spec === result.args === nothing
    end
end