using SnapTests
using Test
using SnapTests: matchsnap

function testpath(args...)
    joinpath(@__DIR__, args...)
end

@testset "SnapTests.jl" begin
    dir = mktempdir()

    path1 = joinpath(dir, "snap1.txt")
    value1 = "value1"
    path2 = joinpath(dir, "snap2.txt")
    value2 = "value2"

    @test !ispath(path1)
    @test !ispath(path2)
    @test matchsnap(path1, value1, verbose=false)
    @test isfile(path1)
    @test matchsnap(path2, value2, on_snap_does_not_exist=:save, verbose=false)
    @test isfile(path2)
    @test matchsnap(path1, value1)
    @test !matchsnap(path1, value2, verbose=false)
    @test matchsnap(path1, value2, verbose=false, on_cmp_false=:return_true)
    @test !matchsnap(path1, value2, verbose=false, on_cmp_false=:return_false)
    @test !matchsnap(path1, value2, verbose=false, on_cmp_false=:return)

    cmp_error(x,y) = error()
    load_error(args...) = error()
    @test matchsnap(cmp_error, path1, value2, on_cmp_error=:return_true)
    @test !matchsnap(cmp_error, path1, value2, on_cmp_error=:return_false)
    @test_throws Exception matchsnap(cmp_error, path1, value2)

    @test matchsnap(path1, value2, load=load_error, on_load_error=:return_true)
    @test !matchsnap(path1, value2, load=load_error, on_load_error=:return_false)
    @test_throws Exception matchsnap(path1, value2, load=load_error)

    @test matchsnap(Returns(true), path1, value2)
    @test !matchsnap(Returns(false), path1, value1, verbose=false)
    @test matchsnap(path2, value2)
    @test matchsnap(path1, value1, on_snap_does_not_exist=:error)
    @test !matchsnap(path1, value2, on_snap_does_not_exist=:error, verbose=false)
    @test_throws "on_snap_does_not_exist in" matchsnap(path1, value1, on_snap_does_not_exist=:nonsense)
    @test_throws "on_cmp_error in" matchsnap(path1, value1, on_cmp_error=:nonsense)
    @test_throws "on_cmp_false in" matchsnap(path1, value1, on_cmp_false=:nonsense)
    # @test_throws ArgumentError 
end

struct Lookup
    dict
    key
end
function SnapTests.load(l::Lookup, value)
    l.dict[l.key]
end
function SnapTests.save(l::Lookup, value)
    l.dict[l.key] = value
end
function SnapTests.exists(l::Lookup, value)
    haskey(l.dict, l.key)
end
function SnapTests.default_options(l::Lookup)
    (;verbose=false)
end

@testset "Customization" begin
    d = Dict()
    @test matchsnap(Lookup(d, :key1), 1)
    @test d == Dict(:key1 => 1)
    @test !matchsnap(Lookup(d, :key1), 2)
    @test d == Dict(:key1 => 1)
    @test matchsnap(Lookup(d, :key1), 1, on_snap_does_not_exist=:error)
    @test matchsnap(Lookup(d, :key1), 1, on_snap_does_not_exist=:error, on_cmp_false=:replace)
    @test d == Dict(:key1 => 1)
    @test matchsnap(Lookup(d, :key2), 2)
    @test d == Dict(:key1 => 1, :key2 => 2)
    @test matchsnap(Lookup(d, :key2), 42, on_cmp_false=:replace)
    @test d == Dict(:key1 => 1, :key2 => 42)
end

@testset "Customization 2" begin
    d = Dict()
    options = (
        save = (key::Symbol, value) -> (d[key] = value;),
        load = (key::Symbol, value) -> d[key],
        exists = (key::Symbol,value) -> haskey(d, key),
    )
    @test matchsnap(:key1, 1; options...)
    @test d == Dict(:key1 => 1)
    @test !matchsnap(:key1, 2; options...)
    @test d == Dict(:key1 => 1)
    @test matchsnap(:key1, 1; on_snap_does_not_exist=:error, options...)
    @test matchsnap(:key1, 1; on_snap_does_not_exist=:error, on_cmp_false=:replace, options...)
    @test d == Dict(:key1 => 1)
    @test matchsnap(:key2, 2; options...)
    @test d == Dict(:key1 => 1, :key2 => 2)
    @test matchsnap(:key2, 42; on_cmp_false=:replace, options...)
    @test d == Dict(:key1 => 1, :key2 => 42)
end

mutable struct DB
    getindex
    haskey
    setindex!
end

Base.getindex(db::DB, key) = db.getindex(key)
Base.haskey(db::DB, key) = db.haskey(key)
Base.setindex!(db::DB, val, key) = db.setindex!(val, key)
function DB(dict::AbstractDict)
    getindex = key -> dict[key]
    haskey = key -> Base.haskey(dict, key)
    setindex! = (val, key) -> dict[key] = val
    DB(getindex, haskey, setindex!)
end

@testset "on load error" begin
    dict = Dict()
    db = DB(dict)
    @test matchsnap(Lookup(db, 1), 10)
    @test matchsnap(Lookup(db, 1), 10)
    db.haskey = Returns(true)
    @test matchsnap(Lookup(db, 1), 10)
    @test dict == Dict(1 => 10)
    @test_throws KeyError matchsnap(Lookup(db, 2), 10)
    @test matchsnap(Lookup(db, 2), 10, on_load_error=:replace)
    @test dict == Dict(1 => 10, 2=>10)
end
