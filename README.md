# InputBuffers

[![Build Status](https://github.com/nhz2/InputBuffers.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/nhz2/InputBuffers.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

A Julia package to wrap an `AbstractVector{UInt8}` in a readable seekable `IO` type.

## Usage

```julia
using InputBuffers: InputBuffer

data = 0x00:0xFF
io = InputBuffer(data)
@assert io isa IO
@assert read(io) == data
```