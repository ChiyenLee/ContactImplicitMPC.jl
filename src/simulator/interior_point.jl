# check that inequality constraints are satisfied
inequality_check(x, idx_ineq) = any(view(x, idx_ineq) .<= 0.0) ? true : false

"""
    residual templates
    # residual
    function r!(r, z, θ, κ)
        @warn "residual not defined"
        nothing
    end

    # residual Jacobian wrt z
    function rz!(rz, z, θ, κ)
        @warn "residual Jacobian wrt z not defined"
        nothing
    end

    # residual Jacobian wrt θ
    function rθ!(rθ, z, θ, κ)
        @warn "residual Jacobian wrt θ not defined"
        nothing
    end
"""
struct InteriorPoint{T}
    z::Vector{T}               # current point
    z̄::Vector{T}               # candidate point
    r::Vector{T}               # residual
    r_norm::T                  # residual norm
    r̄::Vector{T}               # candidate residual
    r̄_norm::T                  # candidate residual norm
    rz#::SparseMatrixCSC{T,Int} # residual Jacobian wrt z
    rθ#::SparseMatrixCSC{T,Int} # residual Jacobian wrt θ
    Δ::Vector{T}               # search direction
    idx_ineq::Vector{Int}      # indices for inequality constraints
    z̄_ineq                     # variables subject to inequality constraints
    δz::SparseMatrixCSC{T,Int} # solution gradients
    θ::Vector{T}               # problem data
    κ::Vector{T}               # barrier parameter
end

function interior_point(num_var::Int, num_data::Int, idx_ineq::Vector{Int};
        rz = spzeros(num_var, num_var),
        rθ = spzeros(num_var, num_data)) where T

    InteriorPoint(
        zeros(num_var),
        zeros(num_var),
        zeros(num_var),
        0.0,
        zeros(num_var),
        0.0,
        rz,
        rθ,
        zeros(num_var),
        idx_ineq,
        view(zeros(num_var), idx_ineq),
        spzeros(num_var, num_data),
        zeros(num_data),
        zeros(1))
end

# interior-point solver options
@with_kw mutable struct InteriorPointOptions{T}
    r_tol::T = 1.0e-5
    κ_tol::T = 1.0e-5
    κ_init::T = 1.0
    κ_scale::T = 0.1
    max_iter::Int = 100
    max_ls::Int = 50
    diff_sol::Bool = false
end

# interior point solver
function interior_point!(ip::InteriorPoint{T};
    opts = InteriorPointOptions{T}()) where T

    # options
    r_tol = opts.r_tol
    κ_tol = opts.κ_tol
    κ_init = opts.κ_init
    κ_scale = opts.κ_scale
    max_iter = opts.max_iter
    max_ls = opts.max_ls
    diff_sol = opts.diff_sol

    # unpack pre-allocated data
    z = ip.z
    z̄ = ip.z̄
    r = ip.r
    r_norm = ip.r_norm
    r̄ = ip.r̄
    r̄_norm = ip.r̄_norm
    rz = ip.rz
    Δ = ip.Δ
    idx_ineq = ip.idx_ineq
    # ip.z̄_ineq .= view(ip.z̄, ip.idx_ineq)
    # z̄_ineq = ip.z̄_ineq
    θ = ip.θ
    κ = ip.κ

    # initialize barrier parameter
    κ[1] = κ_init

    # compute residual, residual Jacobian
    r!(r, z, θ, κ[1])
    r_norm = norm(r, Inf)

    for k = 1:10
        for i = 1:max_iter
            # check for converged residual
            if r_norm < r_tol
                continue
            end

            # compute residual Jacobian
            rz!(rz, z, θ, κ[1])

            # compute step
            # Δ .= r
            # info = LAPACK.getrf!(Array(rz))
            # LAPACK.getrs!('N', info[1], info[2], Δ)
            Δ .= rz \ r
            # Δ .= lu(rz) \ r

            # initialize step length
            α = 1.0

            # candidate point
            z̄ .= z - α * Δ

            # check inequality constraints
            iter = 0
            while inequality_check(z̄, idx_ineq)
                α = 0.5 * α
                z̄ .= z - α * Δ
                iter += 1
                if iter > max_ls
                    @error "backtracking line search fail"
                    return false
                end
            end

            # reduce norm of residual
            r!(r̄, z̄, θ, κ[1])
            r̄_norm = norm(r̄, Inf)

            while r̄_norm^2.0 >= (1.0 - 0.001 * α) * r_norm^2.0
                α = 0.5 * α
                z̄ .= z - α * Δ
                r!(r̄, z̄, θ, κ[1])
                r̄_norm = norm(r̄, Inf)

                iter += 1
                if iter > max_ls
                    @error "line search fail"
                    return false
                end
            end

            # update
            z .= z̄
            r .= r̄
            r_norm = r̄_norm
        end

        if κ[1] < κ_tol
            return true
        else
            # update barrier parameter
            κ[1] *= κ_scale

            # update residual
            r!(r, z, θ, κ[1])
            r_norm = norm(r, Inf)
        end
    end

    diff_sol && differentiate_solution!(data)

    return true
end

function interior_point!(ip::InteriorPoint{T}, z::Vector{T}, θ::Vector{T};
    opts = InteriorPointOptions{T}()) where T
    ip.z .= z
    ip.θ .= θ
    interior_point!(ip, opts = opts)
end

function differentiate_solution!(ip::InteriorPoint)
    z = ip.z
    θ = ip.θ
    rz = ip.rz
    rθ = ip.rθ
    δz = ip.δz
    κ = ip.κ

    rz!(rz, z, θ, κ[1]) # maybe not needed
    rθ!(rθ, z, θ, κ[1])

    δz .= -1.0 * rz \ Array(rθ) # TODO: fix
    nothing
end
