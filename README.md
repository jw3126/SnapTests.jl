# SnapTests

[![Build Status](https://github.com/jw3126/SnapTests.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jw3126/SnapTests.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/jw3126/SnapTests.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/jw3126/SnapTests.jl)

Minimalistic package for testing values against data stored on disk.

# Usage

```julia
using Test
using SnapTests

path = "hello1.txt"
write(path, "hello world")
@test matchsnap(path, "hello world")
@test matchsnap(path, "hi world!") # fail with a diff
@test matchsnap("does_not_exist", "hi world!") # ask for path creation

SnapTests.on_cmp_false = :ask     # ask to update data on disk if test fails
SnapTests.on_cmp_false = :replace # silently replace data on disk if test fails
SnapTests.on_cmp_false = :return  # default, matchsnap will just return false

# Customization
# Lets customize test so that instead of loading from disk, stuff gets looked up from a database

enterprise_db = Dict()
struct Lookup
    key::Symbol
end
SnapTests.exists(l::Lookup, value) = haskey(enterprise_db, l.key)
SnapTests.load(l::Lookup, value) = enterprise_db[l.key]
SnapTests.save(l::Lookup, value) = (enterprise_db[l.key] = value)

@test matchsnap(Lookup(:key1), 1)
@test matchsnap(Lookup(:key2), 2)
@test matchsnap(Lookup(:key2), 2)
@test matchsnap(Lookup(:key2), 3) # fails
```

# Tooling
One drawback of writing values to a file instead of hard coding them in a test is 
that reading the test is less self contained.

To alleviate this, there are ways for various editors to quickly peek the contents of a file.

## Neovim
Using [telescope](https://github.com/nvim-telescope/telescope.nvim) one can bind the following to some keys:
```lua
require('telescope.builtin').find_files({ default_text=vim.fn.expand('<cfile>')})"
```


# Alternatives

* [ReferenceTests.jl](https://github.com/JuliaTesting/ReferenceTests.jl) 
  Compared to this package many more awesome features. But also heavier dependencies
  and hard to customize, especially if FileIO does not cover your use case.
* [SnapshotTests.jl](https://github.com/mattwigway/SnapshotTests.jl)

