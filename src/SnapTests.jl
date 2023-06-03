module SnapTests
using ArgCheck
import DeepDiffs

function matchsnap(snap, value; kw...)
    cmp = cmpfun(snap, value)
    matchsnap(cmp, snap, value; kw...)
end

function matchsnap(cmp, snap, value; 
        on_snap_does_not_exist=:save,
        on_cmp_error=:error,
        on_cmp_false=:return,
        on_load_error=:error,
    )
    @argcheck on_load_error in (:error, :replace)
    @argcheck on_cmp_error in (:error, :replace)
    @argcheck on_cmp_false in (:ask, :replace, :return)
    @argcheck on_snap_does_not_exist in (:save, :error)

    snap_value = if exists(snap, value)
        try
            load(snap, value)
        catch err
            if on_load_error === :error
                rethrow()
            elseif on_load_error === :replace
                @info("Replacing snap after load error",
                    error=err,
                )
                save(snap, value)
                load(snap, value)
            end
        end
    elseif on_snap_does_not_exist === :error
        error("$snap does not exist.")
    elseif on_snap_does_not_exist === :ask
        error("TODO")
    elseif on_snap_does_not_exist === :save
        @info "$snap does not exist, saveing $value"
        save(snap, value)
        load(snap, value) # sanity check that reload works
    else
        error("Unreachable")
    end
    ispass = false
    try
        ispass = cmp(snap_value, value)::Bool
    catch err
        if on_cmp_error === :replace
            # TODO diff
            @info("Replacing snap after cmp error",
                error=err,
            )
            save(snap, value)
            snap_value = load(snap, value)
            ispass = cmp(snap_value, value)::Bool
        elseif on_cmp_error === :error
            rethrow()
        else
            error("Unreachable")
        end
    end
    @assert ispass isa Bool

    if (!ispass) 
        if on_cmp_false === :return
            return ispass
        elseif on_cmp_false === :ask
            error("TODO")
        elseif on_cmp_false === :replace
            @info("Replacing snap after false comparison",
            )
            save(snap, value)
            snap_value = load(snap, value)
            ispass = cmp(snap_value, value)::Bool
        end
    end
    return ispass
end

function exists(snap::AbstractString, value)
    if isfile(snap)
        return true
    elseif ispath(snap)
        error("$snap is a path but not a file.")
    else
        return false
    end
end
function save(snap::AbstractString, value)
    mkpath(dirname(snap))
    write(snap, value)
end
function load(snap::AbstractString, value)
    read(snap, typeof(value))
end
function cmpfun(snap, value)
    isequal
end
function diff(snap, snap_value, value)
    DeepDiffs.deepdiff(snap_value, value)
end

end
