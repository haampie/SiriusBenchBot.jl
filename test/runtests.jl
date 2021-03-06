using Test

import SiriusBenchBot: options_from_comment

@testset "Trigger comments" begin

    @testset "No yaml" begin
        no_options = """
            Here is some comment

            @siriusbot run
            """

        result = options_from_comment(no_options)

        @test result.id ===
              result.reference_spec ===
              result.reference_cmd ===
              result.reference_ref ===
              result.spec ===
              result.cmd === nothing
    end

    @testset "Only top-level options" begin
        only_top_level = """
            Here is some comment

            @siriusbot run

            ```
            id: "some-id"
            spec: sirius@develop ^spla@2.0.0
            cmd: sirius.scf --wut
            ```
            """

        result = options_from_comment(only_top_level)

        @test result.reference_spec == result.spec == "sirius@develop ^spla@2.0.0"
        @test result.id === "some-id"
        @test result.reference_cmd == result.cmd == ["sirius.scf", "--wut"]
        @test result.reference_ref === nothing
    end

    @testset "All level options" begin
        all_level_options = """
            Here is some comment

            @siriusbot run

            ```
            spec: sirius@develop ^spla@2.0.0
            cmd: sirius.scf --some-arg --another

            current:
                spec: sirius@develop +new_feature
            
            reference:
                ref: develop
                cmd: sirius.scf --different --arguments
            ```
            """

        result = options_from_comment(all_level_options)

        @test result.id === nothing
        @test result.reference_spec == "sirius@develop ^spla@2.0.0"
        @test result.reference_cmd == ["sirius.scf", "--different", "--arguments"]
        @test result.reference_ref == "develop"
        @test result.spec == "sirius@develop +new_feature"
        @test result.cmd == ["sirius.scf", "--some-arg", "--another"]
    end

    @testset "No defaults" begin
        all_level_options = """
            Here is some comment

            @siriusbot run

            ```
            current:
                spec: sirius@develop +new_feature
                cmd: sirius.scf -x -y
            
            reference:
                ref: develop
                spec: "sirius@6.5.4"
                cmd: sirius.scf -a -b
            ```
            """

        result = options_from_comment(all_level_options)

        @test result.id === nothing
        @test result.reference_spec == "sirius@6.5.4"
        @test result.reference_cmd == ["sirius.scf", "-a", "-b"]
        @test result.reference_ref == "develop"
        @test result.spec == "sirius@develop +new_feature"
        @test result.cmd == ["sirius.scf", "-x", "-y"]
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

        @test result.reference_ref ===
            result.reference_spec ===
            result.reference_cmd ===
            result.spec ===
            result.cmd ===
            nothing
    end
end