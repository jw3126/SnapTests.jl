module SnapTests
using ArgCheck
import DeepDiffs

export matchsnap

function matchsnap(snap, value; kw...)
    cmp = cmpfun(snap, value)
    matchsnap(cmp, snap, value; kw...)
end

const ALLOWED_ON_LOAD_ERROR          = (:error, :replace, :return_true, :return_false)
const ALLOWED_ON_CMP_ERROR           = (:error, :replace, :return_true, :return_false)
const ALLOWED_ON_CMP_FALSE           = (:ask, :replace, :return, :return_true, :return_false)
const ALLOWED_ON_SNAP_DOES_NOT_EXIST = (:ask, :save, :error, :return_true, :return_false)

"""
Allowed values: $ALLOWED_ON_SNAP_DOES_NOT_EXIST
"""
on_snap_does_not_exist::Symbol = :save

"""
Allowed values: $ALLOWED_ON_CMP_ERROR
"""
on_cmp_error::Symbol           = :error

"""
Allowed values: $ALLOWED_ON_CMP_FALSE
"""
on_cmp_false::Symbol           = :return

"""
Allowed values: $ALLOWED_ON_LOAD_ERROR
"""
on_load_error::Symbol          = :error

verbose::Bool                  = true

function matchsnap(cmp, snap, value; kw...)
    options = resolve_options(snap; kw...)
    (;on_cmp_error, on_cmp_false, on_load_error, on_snap_does_not_exist, verbose,
        load,
        save,
        exists,
        renderdiff,
    ) = options
    if on_load_error isa Symbol
        @argcheck on_load_error in ALLOWED_ON_LOAD_ERROR
    end
    if on_cmp_error isa Symbol
        @argcheck on_cmp_error in ALLOWED_ON_CMP_ERROR
    end
    if on_cmp_false isa Symbol
        @argcheck on_cmp_false in ALLOWED_ON_CMP_FALSE
    end
    if on_snap_does_not_exist isa Symbol
        @argcheck on_snap_does_not_exist in ALLOWED_ON_SNAP_DOES_NOT_EXIST
    end

    snap_value = if exists(snap, value)
        try
            load(snap, value)
        catch err
            if on_load_error === :error
                rethrow()
            elseif on_load_error === :return_true
                return true
            elseif on_load_error === :return_false
                return false
            elseif on_load_error === :replace
                if verbose
                    @info("Replacing snap after load error",
                        error=err,
                    )
                end
                save(snap, value)
                load(snap, value)
            else
                on_load_error(EventLoadError(snap, value, err))
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
        if verbose
            @info "$snap does not exist, saving $value"
        end
        save(snap, value)
        load(snap, value)
    elseif on_snap_does_not_exist === :return_true
        return true
    elseif on_snap_does_not_exist === :return_false
        return false
    else
        error("Unreachable")
    end

    ispass = false
    try
        ispass = cmp(snap_value, value)
    catch err
        if on_cmp_error === :replace
            if verbose
                renderdiff(snap, snap_value, value)
                @info("Replacing snap after cmp error",
                    error=err,
                )
            end
            save(snap, value)
            snap_value = load(snap, value)
            ispass = cmp(snap_value, value)::Bool
        elseif on_cmp_error === :error
            rethrow()
        elseif on_cmp_error === :return_true
            return true
        elseif on_cmp_error === :return_false
            return false
        else
            error("Unreachable")
        end
    end
    @assert ispass isa Bool

    if ispass 
        return ispass
    elseif (on_cmp_false === :return)
        if verbose
            renderdiff(snap, snap_value, value)
            @info "You might want to set `on_cmp_false` to one of $(ALLOWED_ON_CMP_FALSE)"
        end
        return ispass
    elseif (on_cmp_false === :return_true)
        return true
    elseif (on_cmp_false === :return_false)
        return false
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
        if verbose
            renderdiff(snap, snap_value, value)
            @info("Replacing snap after false comparison")
        end
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

function get_global_options()
    @argcheck on_load_error in ALLOWED_ON_LOAD_ERROR
    @argcheck on_cmp_error in ALLOWED_ON_CMP_ERROR
    @argcheck on_cmp_false in ALLOWED_ON_CMP_FALSE
    @argcheck on_snap_does_not_exist in ALLOWED_ON_SNAP_DOES_NOT_EXIST
    (;on_snap_does_not_exist,on_cmp_error,on_cmp_false,on_load_error,verbose,
        load,
        save,
        exists,
        renderdiff,
    )
end

function resolve_options(snap; kw...)::NamedTuple
    merge(get_global_options(), default_options(snap), (;kw...))
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
function default_options(snap)
    NamedTuple()
end

end
