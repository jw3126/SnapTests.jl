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
    @test matchsnap(path1, value1)
    @test isfile(path1)
    @test matchsnap(path2, value2, on_snap_does_not_exist=:save)
    @test isfile(path2)
    @test matchsnap(path1, value1)
    @test !matchsnap(path1, value2)
    @test matchsnap(Returns(true), path1, value2)
    @test !matchsnap(Returns(false), path1, value1)
    @test matchsnap(path2, value2)
    @test matchsnap(path1, value1, on_snap_does_not_exist=:error)
    @test !matchsnap(path1, value2, on_snap_does_not_exist=:error)
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
