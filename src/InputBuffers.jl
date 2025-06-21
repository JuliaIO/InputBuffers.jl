module InputBuffers

export InputBuffer

mutable struct InputBuffer{T<:AbstractVector{UInt8}} <: IO
    data::T
    pos::Int64
    size::Int64
    mark::Int64
end

"""
    InputBuffer(data::AbstractVector{UInt8}) -> InputBuffer

Create a readable and seekable I/O stream wrapper around a vector of bytes.
"""
function InputBuffer(data::AbstractVector{UInt8})
    InputBuffer{typeof(data)}(data, 0, length(data), -1)
end

Base.parent(b::InputBuffer) = b.data

Base.close(::InputBuffer)::Nothing = nothing
Base.isopen(::InputBuffer)::Bool = true
Base.isreadable(::InputBuffer)::Bool = true
Base.iswritable(::InputBuffer)::Bool = false

function Base.eof(b::InputBuffer)::Bool
    b.pos === b.size
end

function Base.position(b::InputBuffer)::Int64
    b.pos
end

function Base.bytesavailable(b::InputBuffer)::Int64
    b.size-b.pos
end

# Seek Operations
# ---------------

function Base.seek(b::InputBuffer, n::Integer)::InputBuffer
    b.pos = clamp(n, 0, b.size)
    b
end

function Base.seekend(b::InputBuffer)::InputBuffer
    b.pos = b.size
    b
end

# Read Functions
# --------------

function Base.read(b::InputBuffer, ::Type{UInt8})::UInt8
    x = peek(b)
    b.pos += 1
    x
end

# needed for `peek(b, Char)` to work
function Base.peek(b::InputBuffer, ::Type{UInt8})::UInt8
    eof(b) && throw(EOFError())
    b.data[firstindex(b.data) + b.pos]
end

function Base.skip(b::InputBuffer, n::Integer)::InputBuffer
    b.pos += clamp(n, -b.pos, b.size - b.pos)
    b
end

function Base.read(b::InputBuffer, nb::Integer = typemax(Int))::Vector{UInt8}
    signbit(nb) && throw(ArgumentError("negative nbytes"))
    nr::Int64 = min(nb, bytesavailable(b))
    out = Vector{UInt8}(undef, nr)
    copyto!(out, Int64(1), b.data, Int64(b.pos+firstindex(b.data)), nr)
    b.pos += nr
    out
end
function Base.readbytes!(b::InputBuffer, out::AbstractArray{UInt8}, nb=length(out))::Int64
    signbit(nb) && throw(ArgumentError("negative nbytes"))
    nr::Int64 = min(nb, bytesavailable(b))
    if nr > length(out)
        resize!(out, nr)
    end
    copyto!(out, Int64(firstindex(out)), b.data, Int64(b.pos+firstindex(b.data)), nr)
    b.pos += nr
    return nr
end
Base.readavailable(b::InputBuffer) = read(b)

const ByteVector = Union{
    Vector{UInt8},
    Base.CodeUnits{UInt8, String},
    typeof(view(codeunits("abc"), :)),
    typeof(view(codeunits("abc"), 1:2)),
    typeof(view(zeros(UInt8, 3), :)),
    typeof(view(zeros(UInt8, 3), 1:2))
}

# Using @noinline to hopefully prevent strange TBAA issues based on where p comes from
@noinline function Base.unsafe_read(b::InputBuffer, p::Ptr{UInt8}, n::UInt)::Nothing
    nb::Int64 = min(n, bytesavailable(b))
    temp = Vector{UInt8}(undef, nb)
    copyto!(temp, Int64(1), b.data, Int64(b.pos+firstindex(b.data)), nb)
    cconv_temp = Base.cconvert(Ptr{UInt8}, temp)
    GC.@preserve cconv_temp unsafe_copyto!(p, Base.unsafe_convert(Ptr{UInt8}, cconv_temp), nb)
    b.pos += nb
    nb < n && throw(EOFError())
    nothing
end
@noinline function Base.unsafe_read(b::InputBuffer{<:ByteVector}, p::Ptr{UInt8}, n::UInt)::Nothing
    nb::Int64 = min(n, bytesavailable(b))
    cconv_data = Base.cconvert(Ptr{UInt8}, b.data)
    GC.@preserve cconv_data unsafe_copyto!(p, Base.unsafe_convert(Ptr{UInt8}, cconv_data) + b.pos, nb)
    b.pos += nb
    nb < n && throw(EOFError())
    nothing
end

# TODO Benchmark to see if the following are worth implementing
# Base.copyline
# Base.copyuntil

end