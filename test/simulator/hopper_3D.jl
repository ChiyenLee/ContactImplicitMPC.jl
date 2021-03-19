@testset "Simulator: Hopper (3D)" begin
    # Reference trajectory
    model = ContactControl.get_model("hopper_3D", surf = "flat")
    q, u, γ, b, h = ContactControl.get_gait("hopper_3D", "vertical")

    # time
    T = length(u)

    @test (maximum([norm(ContactControl.dynamics(model,
    	h, q[t], q[t+1], u[t],
    	zeros(model.dim.w), γ[t], b[t], q[t+2]), Inf) for t = 1:T]) < 1.0e-5)

    # initial conditions
    q0 = SVector{model.dim.q}(q[1])
    q1 = SVector{model.dim.q}(q[2])

    # simulator
    sim = ContactControl.simulator(model, q0, q1, h, T,
        p = ContactControl.open_loop_policy([SVector{model.dim.u}(ut) for ut in u], h),
        r! = model.res.r, rz! = model.res.rz, rθ! = model.res.rθ,
        rz = model.spa.rz_sp,
        rθ = model.spa.rθ_sp,
        ip_opts = ContactControl.InteriorPointOptions(
    		r_tol = 1.0e-8, κ_tol = 1.0e-5, κ_init = 1.0e-4, solver = :mgs_solver),
        sim_opts = ContactControl.SimulatorOptions(warmstart = true))

    # simulate
    @time status = ContactControl.simulate!(sim, verbose = false)
    @test status
    @test norm(q[end] - sim.traj.q[end], Inf) < 1.0e-3
end
