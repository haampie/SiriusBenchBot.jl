using Test

import SiriusBenchBot: options_from_comment

@testset "Trigger comments" begin

    @testset "No yaml" begin
        no_options = """
            Here is some comment

            @siriusbot run
            """

        result = options_from_comment(no_options)

        @test result.reference_spec ===
              result.reference_cmd ===
              result.reference_build ===
              result.reference_ref ===
              result.spec ===
              result.cmd ===
              result.build === nothing
    end

    @testset "Only top-level options" begin
        only_top_level = """
            Here is some comment

            @siriusbot run

            ```
            spec: sirius@develop ^spla@2.0.0
            build: false
            cmd: sirius.scf --wut
            ```
            """

        result = options_from_comment(only_top_level)

        @test result.reference_spec == result.spec == "sirius@develop ^spla@2.0.0"
        @test result.reference_build == result.build === false
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
            build: true

            current:
                spec: sirius@develop +new_feature
                build: false
            
            reference:
                ref: develop
                cmd: sirius.scf --different --arguments
                build: false
            ```
            """

        result = options_from_comment(all_level_options)

        @test result.reference_spec == "sirius@develop ^spla@2.0.0"
        @test result.reference_cmd == ["sirius.scf", "--different", "--arguments"]
        @test result.reference_ref == "develop"
        @test result.reference_build === false
        @test result.spec == "sirius@develop +new_feature"
        @test result.cmd == ["sirius.scf", "--some-arg", "--another"]
        @test result.build === false
    end

    @testset "No defaults" begin
        all_level_options = """
            Here is some comment

            @siriusbot run

            ```
            current:
                spec: sirius@develop +new_feature
                cmd: sirius.scf -x -y
                build: true
            
            reference:
                ref: develop
                spec: "sirius@6.5.4"
                cmd: sirius.scf -a -b
                build: false
            ```
            """

        result = options_from_comment(all_level_options)

        @test result.reference_spec == "sirius@6.5.4"
        @test result.reference_cmd == ["sirius.scf", "-a", "-b"]
        @test result.reference_ref == "develop"
        @test result.reference_build == false
        @test result.spec == "sirius@develop +new_feature"
        @test result.cmd == ["sirius.scf", "-x", "-y"]
        @test result.build == true
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
            result.reference_build ===
            result.spec ===
            result.cmd ===
            result.build ===
            nothing
    end
end