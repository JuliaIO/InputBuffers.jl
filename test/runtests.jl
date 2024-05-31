using InputBuffers
using Test
using Aqua

@testset "InputBuffers.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(InputBuffers)
    end
    # Write your tests here.
end
