module SnapTests
using ArgCheck
import DeepDiffs

export matchsnap

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
    @argcheck on_snap_does_not_exist in (:ask, :save, :error)

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
        println("$snap does not exit. Current value is:")
        println(value)
        choice = ask_stdin("Save current value? (y=yes, f=return false, e=error, t=return true)", ["y", "f", "e", "t"])
        if choice == "y"
            save(snap, value)
            load(snap, value)
        elseif choice == "f"
            return false
        elseif choice == "t"
            return true
        elseif choice == "e"
            error("User error after non existing snap")
        else
            error("Unreachable")
        end
    elseif on_snap_does_not_exist === :save
        @info "$snap does not exist, saveing $value"
        save(snap, value)
        load(snap, value)
    else
        error("Unreachable")
    end

    ispass = false
    try
        ispass = cmp(snap_value, value)
    catch err
        if on_cmp_error === :replace
            renderdiff(snap, snap_value, value)
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

    if ispass 
        return ispass
    elseif (on_cmp_false === :return)
        renderdiff(snap, snap_value, value)
        return ispass
    elseif on_cmp_false === :ask
        renderdiff(snap, snap_value, value)
        choice = ask_stdin("Replace snap by current value? (y=yes, f=return false, e=error, t=return true)", ["y", "f", "e", "t"])
        if choice == "y"
            save(snap, value)
            snap_value = load(snap, value)
            ispass = cmp(snap_value, value)::Bool
        elseif choice == "f"
            return false
        elseif choice == "t"
            return true
        elseif choice == "e"
            error("User error after false comparison")
        else
            error("Unreachable")
        end
    elseif on_cmp_false === :replace
        @info("Replacing snap after false comparison")
        save(snap, value)
        snap_value = load(snap, value)
        ispass = cmp(snap_value, value)::Bool
    else
        error("Unreachable")
    end
    return ispass
end

function ask_stdin(question::AbstractString, choices)
    for choice in choices
        @argcheck choice == lowercase(strip(choice))
    end
    println(question)
    while true
        reply = readline()
        isempty(reply) && continue
        reply = lowercase(strip(reply))
        if reply in choices
            return reply
        else
            println("Got reply $(repr(reply)) but must be in $choices")
        end
    end
end

################################################################################
#### Customization
################################################################################
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
function renderdiff(snap, snap_value, value)
    println(DeepDiffs.deepdiff(snap_value, value))
end

end
