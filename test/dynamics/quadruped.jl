@testset "Model Methods: Fast Base (Quadruped)" begin
	model = ContactControl.get_model("quadruped")

    # Setup variables
    T = Float64
    nq = model.dim.q
    q0s = rand(SizedVector{nq,T})
    q̇0s = rand(SizedVector{nq,T})

    # Testing fast methods
	@test norm(ContactControl.ϕ_fast(model, q0s) - ContactControl.ϕ_func(model, q0s), Inf) < 1.0e-8
    @test norm(ContactControl.M_fast(model, q0s) - ContactControl.M_func(model, q0s), Inf) < 1.0e-8
	@test norm(ContactControl.B_fast(model, q0s) - ContactControl.B_func(model, q0s), Inf) < 1.0e-8
    @test norm(ContactControl.A_fast(model, q0s) - ContactControl.A_func(model, q0s), Inf) < 1.0e-8
    @test norm(ContactControl.J_fast(model, q0s) - ContactControl.J_func(model, q0s), Inf) < 1.0e-8
    @test norm(ContactControl.C_fast(model, q0s, q̇0s) - ContactControl.C_func(model, q0s, q̇0s), Inf) < 1.0e-8

	h = 0.1
    nq = model.dim.q
    nu = model.dim.u
    nw = model.dim.w
    nc = model.dim.c
    nb = model.dim.b

    q0s = rand(SizedVector{nq,T})
    q1s = rand(SizedVector{nq,T})
    u1s = rand(SizedVector{nu,T})
    u1s = rand(SizedVector{nu,T})
    w1s = rand(SizedVector{nw,T})
    γ1s = rand(SizedVector{nc,T})
    b1s = rand(SizedVector{nb,T})
    q2s = rand(SizedVector{nq,T})

    ∇ys   = rand(SizedMatrix{nq,2nq + nu + nw + nc + nb + nq,T})
    ∇q0s  = rand(SizedMatrix{nq,nq,T})
    ∇q1s  = rand(SizedMatrix{nq,nq,T})
	∇u1s  = rand(SizedMatrix{nq,nu,T})
    ∇w1s  = rand(SizedMatrix{nq,nw,T})
    ∇γ1s  = rand(SizedMatrix{nq,nc,T})
    ∇b1s  = rand(SizedMatrix{nq,nb,T})
    ∇q2s  = rand(SizedMatrix{nq,nq,T})

    # Testing dynamics methods
    @test norm(ContactControl.d_fast(model, h, q0s, q1s, u1s, w1s, γ1s, b1s, q2s) -
        ContactControl.dynamics(model, h, q0s, q1s, u1s, w1s, γ1s, b1s, q2s), Inf) < 1.0e-8

    ContactControl.dq0_fast!(∇q0s, model, h, q0s, q1s, u1s, w1s, γ1s, b1s, q2s)
	fq0(x) = ContactControl.dynamics(model, h, x, q1s, u1s, w1s, γ1s, b1s, q2s)
    @test norm(∇q0s - ForwardDiff.jacobian(fq0, q0s), Inf) < 1.0e-8

    ContactControl.dq1_fast!(∇q1s, model, h, q0s, q1s, u1s, w1s, γ1s, b1s, q2s)
	fq1(x) = ContactControl.dynamics(model, h, q0s, x, u1s, w1s, γ1s, b1s, q2s)
    @test norm(∇q1s - ForwardDiff.jacobian(fq1, q1s), Inf) < 1.0e-8

	ContactControl.du1_fast!(∇u1s, model, h, q0s, q1s, u1s, w1s, γ1s, b1s, q2s)
	fu1(x) = ContactControl.dynamics(model, h, q0s, q1s, x, w1s, γ1s, b1s, q2s)
	@test norm(∇u1s - ForwardDiff.jacobian(fu1, u1s), Inf) < 1.0e-8

	ContactControl.dw1_fast!(∇w1s, model, h, q0s, q1s, u1s, w1s, γ1s, b1s, q2s)
	fw1(x) = ContactControl.dynamics(model, h, q0s, q1s, u1s, x, γ1s, b1s, q2s)
	@test norm(∇w1s - ForwardDiff.jacobian(fw1, w1s), Inf) < 1.0e-8

    ContactControl.dγ1_fast!(∇γ1s, model, h, q0s, q1s, u1s, w1s, γ1s, b1s, q2s)
	fγ1(x) = ContactControl.dynamics(model, h, q0s, q1s, u1s, w1s, x, b1s, q2s)
    @test norm(∇γ1s - ForwardDiff.jacobian(fγ1, γ1s), Inf) < 1.0e-8

    ContactControl.db1_fast!(∇b1s, model, h, q0s, q1s, u1s, w1s, γ1s, b1s, q2s)
	fb1(x) = ContactControl.dynamics(model, h, q0s, q1s, u1s, w1s, γ1s, x, q2s)
    @test norm(∇b1s - ForwardDiff.jacobian(fb1, b1s), Inf) < 1.0e-8

    ContactControl.dq2_fast!(∇q2s, model, h, q0s, q1s, u1s, w1s, γ1s, b1s, q2s)
	fq2(x) = ContactControl.dynamics(model, h, q0s, q1s, u1s, w1s, γ1s, b1s, x)
    @test norm(∇q2s - ForwardDiff.jacobian(fq2, q2s), Inf) < 1.0e-8

    ContactControl.dy_fast!(∇ys, model, h, q0s, q1s, u1s, w1s, γ1s, b1s, q2s)
    @test norm(∇ys - [∇q0s ∇q1s ∇u1s ∇w1s ∇γ1s ∇b1s ∇q2s], Inf) < 1.0e-8

	nz = ContactControl.num_var(model)
    nθ = ContactControl.num_data(model)

    zs = rand(SizedVector{nz})
    θs = rand(SizedVector{nθ})
    κs = 1.0
    rs = rand(SizedVector{nz})

    # Testing residual methods
    ContactControl.r_fast!(rs, model, zs, θs, κs)
    @test norm(rs - ContactControl.residual(model, zs, θs, κs), Inf) < 1.0e-8

    ContactControl.rz_fast!(model.spa.rz_sp, model, zs, θs, κs)
	fz(x) = ContactControl.residual(model, x, θs, κs)
    @test norm(model.spa.rz_sp - ForwardDiff.jacobian(fz, zs), Inf) < 1.0e-8

	ContactControl.rθ_fast!(model.spa.rθ_sp, model, zs, θs, κs)
	fθ(x) = ContactControl.residual(model, zs, x, κs)
    @test norm(model.spa.rθ_sp - ForwardDiff.jacobian(fθ, θs), Inf) < 1.0e-8
end
