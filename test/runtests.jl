using InputBuffers: InputBuffers, InputBuffer
using Test
using Aqua
using Random
using OffsetArrays: OffsetArray
using FillArrays: Zeros
using CRC32: crc32

@testset "InputBuffers.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(InputBuffers)
    end
    @testset "tests mostly copied from test/iobuffer.jl in Julia" begin
        @testset "Read/write readonly IOBuffer" begin
            io = InputBuffer(b"hamster\nguinea pig\nturtle")
            @test position(io) == 0
            @test readline(io) == "hamster"
            @test read(io, String) == "guinea pig\nturtle"
            @test_throws EOFError read(io,UInt8)
            seek(io,0)
            @test read(io,UInt8) == convert(UInt8, 'h')
            @test_throws Exception truncate(io,0)
            @test_throws Exception write(io,UInt8(0))
            @test_throws Exception write(io,UInt8[0])
            close(io)
        end
    
        @testset "issue 5453" begin
            io = InputBuffer(b"abcdef")
            a = Vector{UInt8}(undef, 1024)
            @test_throws EOFError read!(io,a)
            @test eof(io)
        end
    
        @test isempty(readlines(InputBuffer(b""), keep=true))
    
        @testset "issue #8193" begin
            io = InputBuffer(b"asdf")
            @test position(skip(io, -1)) == 0
            @test position(skip(io, 6)) == 4
            @test position(seek(io, -1)) == 0
            @test position(seek(io, 6)) == 4
        end
    
        @testset "issue #10658" begin
            io = InputBuffer(b"hello")
            @test position(skip(io, 4)) == 4
            @test position(skip(io, 10)) == 5
            @test position(skip(io, -2)) == 3
            @test position(skip(io, -3)) == 0
            @test position(skip(io, -3)) == 0
        end
    
        @testset "issue #53908" begin
            b = collect(0x01:0x05)
            sizehint!(b, 100)
            io = InputBuffer(b)
            @test position(skip(io, 4)) == 4
            @test position(skip(io, typemax(Int))) == 5
            @test position(skip(io, typemax(Int128))) == 5
            @test position(skip(io, typemax(Int32))) == 5
            @test position(skip(io, typemin(Int))) == 0
            @test position(skip(io, typemin(Int128))) == 0
            @test position(skip(io, typemin(Int32))) == 0
            @test position(skip(io, 4)) == 4
            @test position(skip(io, -2)) == 2
            @test position(skip(io, -2)) == 0
            @test position(seek(io, -2)) == 0
            @test position(seek(io, typemax(Int))) == 5
            @test position(seek(io, typemax(Int128))) == 5
            @test position(seek(io, typemax(Int32))) == 5
            @test position(seek(io, typemin(Int))) == 0
            @test position(seek(io, typemin(Int128))) == 0
            @test position(seek(io, typemin(Int32))) == 0
        end
    
        @testset "pr #11554" begin
            io  = InputBuffer(codeunits(SubString("***αhelloworldω***", 4, 16)))
            io2 = IOBuffer(Vector{UInt8}(b"goodnightmoon"), read=true, write=true)
        
            @test read(io, Char) == 'α'
            @test_throws Exception write(io,"!")
            @test_throws Exception write(io,'β')
            a = Vector{UInt8}(undef, 10)
            @test read!(io, a) === a
            @test String(a) == "helloworld"
            @test read(io, Char) == 'ω'
            @test_throws EOFError read(io,UInt8)
            skip(io, -3)
            @test read(io, String) == "dω"
            @test io.data == b"αhelloworldω"
            @test_throws Exception write(io,"!")
            seek(io, 2)
            seekend(io2)
            write(io2, io)
            @test read(io, String) == ""
            @test read(io2, String) == ""
            seek(io2, 0)
            @test read(io2, String) == "goodnightmoonhelloworldω"
        end
    
        @test flush(InputBuffer(UInt8[])) === nothing # should be a no-op
    
        @testset "skipchars" begin
            io = InputBuffer(b"")
            @test eof(skipchars(isspace, io))
        
            io = InputBuffer(b"   ")
            @test eof(skipchars(isspace, io))
        
            io = InputBuffer(b"#    \n     ")
            @test eof(skipchars(isspace, io, linecomment='#'))
        
            io = InputBuffer(b"      text")
            skipchars(isspace, io)
            @test String(readavailable(io)) == "text"
        
            io = InputBuffer(b"   # comment \n    text")
            skipchars(isspace, io, linecomment='#')
            @test String(readavailable(io)) == "text"
        
            for char in ['@','߷','࿊','𐋺']
                io = InputBuffer(codeunits("alphabeticalstuff$char"))
                @test !eof(skipchars(isletter, io))
                @test read(io, Char) == char
            end
        end
    
        @testset "peek(::GenericIOBuffer)" begin
            io = InputBuffer(codeunits("こんにちは"))
            @test peek(io) == 0xe3
            @test peek(io, Char) == 'こ'
            @test peek(io, Int32) == -476872221
            close(io)
        end
    end
    @testset "tests mostly copied from TranscodingStreams.jl" begin
        s = InputBuffer(b"")
        @test eof(s)
        @test read(s) == UInt8[]
    
        s = InputBuffer(b"foo")
        @test !eof(s)
        @test read(s) == b"foo"
        close(s)
    
        data = rand(UInt8, 100_000)
        s = InputBuffer(data)
        @test !eof(s)
        @test read(s) == data
        close(s)
    
        s = InputBuffer(b"")
        @test_throws EOFError read(s, UInt8)
        data = Vector{UInt8}(undef, 3)
        @test_throws EOFError GC.@preserve data unsafe_read(s, pointer(data), 3)
        close(s)
    
        s = InputBuffer(b"foobar")
        @test read(s, UInt8) === UInt8('f')
        data = Vector{UInt8}(undef, 5)
        GC.@preserve data unsafe_read(s, pointer(data), 5) === nothing
        @test data == b"oobar"
        close(s)
    
        stream = InputBuffer(b"foobarbaz")
        @test position(stream) === Int64(0)
        read(stream, UInt8)
        @test position(stream) === Int64(1)
        read(stream)
        @test position(stream) === Int64(9)
    
        data = collect(0x00:0x0f)
        stream = InputBuffer(data)
        @test !ismarked(stream)
        @test mark(stream) == 0
        @test ismarked(stream)
        @test [read(stream, UInt8) for _ in 1:3] == data[1:3]
        @test reset(stream) == 0
        @test_throws ArgumentError reset(stream)
        @test !ismarked(stream)
        @test [read(stream, UInt8) for _ in 1:3] == data[1:3]
        @test mark(stream) == 3
        @test ismarked(stream)
        @test unmark(stream)
        @test !ismarked(stream)
        @test !unmark(stream)
        @test mark(stream) == 3
        close(stream) # This is a no-op
        @test ismarked(stream)
    
        stream = InputBuffer(b"foobarbaz")
        @test stream == seek(stream, 2)
        @test read(stream, 3) == b"oba"
        seek(stream, 0)
        @test read(stream, 3) == b"foo"
        @test stream == seekstart(stream)
        @test read(stream, 3) == b"foo"
        @test stream == seekend(stream)
        @test eof(stream)
        close(stream)
    
        data = collect(0x00:0x0f)
        stream = InputBuffer(data)
        @test read(stream, UInt8) == data[1]
        skip(stream, 1)
        @test read(stream, UInt8) == data[3]
        skip(stream, 5)
        @test read(stream, UInt8) == data[9]
        skip(stream, 7)
        @test eof(stream)
        close(stream)

        @testset "readuntil" begin
            stream = InputBuffer(b"")
            data = readuntil(stream, 0x00)
            @test data isa Vector{UInt8}
            @test isempty(data)
    
            stream = InputBuffer(b"foo,bar")
            @test readuntil(stream, UInt8(',')) == b"foo"
            @test read(stream) == b"bar"
    
            stream = InputBuffer(b"foo,bar")
            @test readuntil(stream, UInt8(','), keep = false) == b"foo"
            @test read(stream) == b"bar"
    
            stream = InputBuffer(b"foo,bar")
            @test readuntil(stream, UInt8(','), keep = true) == b"foo,"
            @test read(stream) == b"bar"
        end
    end
    @testset "weird arrays" begin
        b = InputBuffer(OffsetArray(b"bar", -5:-3))
        @test position(b) == 0
        @test peek(b) === UInt8('b')
        @test position(b) == 0
        @test read(b, UInt8) === UInt8('b')
        @test position(b) == 1
        @test seekstart(b) === b
        @test position(b) == 0
        @test read(b, String) == "bar"
        @test position(b) == 3
        @test eof(b)
        @test seekend(b) === b
        @test position(b) == 3

        for len in (typemax(Int64), big(typemax(Int64)))
            b = InputBuffer(Zeros{UInt8}(len))
            @test position(b) == 0
            @test peek(b) === UInt8(0)
            @test position(b) == 0
            @test read(b, UInt8) === UInt8(0)
            @test position(b) == 1
            @test seekstart(b) === b
            @test position(b) == 0
            @test seekend(b) === b
            @test position(b) == len
        end
        @test_throws Exception InputBuffer(Zeros{UInt8}(typemax(UInt64)))

        # FastContiguousSubArray with non Int indexes
        for T in (BigInt, UInt64, Int64)
            b = InputBuffer(view(zeros(UInt8,1000), T(2):T(90)))
            @test read(b, UInt8) === UInt8(0)
            data = ones(UInt8, 5)
            GC.@preserve data unsafe_read(b, pointer(data), 5) === nothing
            @test data == zeros(UInt8, 5)
        end
    end
    @testset "closing is no-op" begin
        b = InputBuffer(b"foo")
        @test isnothing(close(b))
        @test isopen(b)
        @test isreadable(b)
        @test !iswritable(b)
    end
    @testset "crc32" begin
        for trial in 1:100
            data = rand(UInt8, rand(0:1000000))
            h = crc32(data)
            @test h == crc32(InputBuffer(data))
        end
    end
    @testset "readbytes!" begin
        # grow output
        b = InputBuffer(b"foo")
        out = UInt8[]
        @test readbytes!(b, out, 10) == 3
        @test position(b) == 3
        @test out == b"foo"

        # don't shrink output
        b = InputBuffer(b"foo")
        out = zeros(UInt8, 10)
        @test readbytes!(b, out) == 3
        @test position(b) == 3
        @test out == [b"foo"; zeros(UInt8, 7);]

        b = InputBuffer(b"foo")
        out = zeros(UInt8, 10)
        @test readbytes!(b, out, 3) == 3
        @test position(b) == 3
        @test out == [b"foo"; zeros(UInt8, 7);]

        # don't read all
        b = InputBuffer(b"foo")
        out = zeros(UInt8, 10)
        @test readbytes!(b, out, 2) == 2
        @test position(b) == 2
        @test out == [b"fo"; zeros(UInt8, 8);]

        # read zero
        b = InputBuffer(b"foo")
        out = zeros(UInt8, 10)
        @test readbytes!(b, out, 0) == 0
        @test position(b) == 0
        @test out == [zeros(UInt8, 10);]

        b = InputBuffer(b"foo")
        seekend(b)
        out = zeros(UInt8, 10)
        @test readbytes!(b, out) == 0
        @test position(b) == 3
        @test out == [zeros(UInt8, 10);]

        b = InputBuffer(b"")
        out = zeros(UInt8, 10)
        @test readbytes!(b, out) == 0
        @test position(b) == 0
        @test out == [zeros(UInt8, 10);]

        b = InputBuffer(b"foo")
        out = zeros(UInt8, 0)
        @test readbytes!(b, out, 0) == 0
        @test position(b) == 0
        @test out == zeros(UInt8, 0)
    end
    @testset "parent" begin
        data = b"foo"
        b = InputBuffer(data)
        @test data === parent(b)
    end
end
