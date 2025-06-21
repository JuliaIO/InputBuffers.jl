# InputBuffers

[![CI](https://github.com/JuliaIO/InputBuffers.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/JuliaIO/InputBuffers.jl/actions/workflows/CI.yml)
[![codecov](https://codecov.io/gh/JuliaIO/InputBuffers.jl/graph/badge.svg?token=60AX7T7NTB)](https://codecov.io/gh/JuliaIO/InputBuffers.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

A Julia package to wrap an `AbstractVector{UInt8}` in a readable seekable `IO` type.

## Usage

```julia
using InputBuffers: InputBuffer

data = 0x00:0xFF
io = InputBuffer(data)
@assert io isa IO
@assert read(io) == data
@assert parent(io) === data
```
