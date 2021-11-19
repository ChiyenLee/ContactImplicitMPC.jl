include(joinpath(pwd(), "src/controller/newton_structure_solver/methods.jl"))

sim = get_simulation("flamingo", "flat_2D_lc", "flat")
model = sim.model
env = sim.env

ref_traj = deepcopy(ContactImplicitMPC.get_trajectory(model, flat_2D_lc,
    joinpath(module_dir(), "src/dynamics/flamingo/gaits/gait_forward_36_4.jld2"),
    load_type = :split_traj_alt))

H_mpc = 15
# obj_mpc = quadratic_objective(model, H_mpc,
#     q = [Diagonal(1e-1 * [3e2, 1e-6, 3e2, 1, 1, 1, 1, 0.1, 0.1]) for t = 1:H_mpc+2],
#     v = [0.0 * Diagonal([1e0,1,1e4,1,1,1,1,1e4,1e4]) for t = 1:H_mpc],
#     u = [Diagonal(3e-1 * [0.1; 0.1; 0.3; 0.3; ones(model.nu-6); 2; 2]) for t = 1:H_mpc-1])

obj_mpc = quadratic_objective(model, H_mpc,
    q = [Diagonal(0.1 * ones(model.nq)) for t = 1:H_mpc+2],
    v = [Diagonal(0.001 * ones(model.nq)) for t = 1:H_mpc],
    u = [Diagonal(0.01 * ones(model.nu)) for t = 1:H_mpc-1])

s = NewtonStructure(sim, H_mpc, ref_traj, obj_mpc, 1.0e-4)
ref_traj.θ
ip_opts = InteriorPointOptions(
			κ_init = 1.0e-4,
			κ_tol = 2.0 * 1.0e-4,
			r_tol = 1.0e-8,
			diff_sol = true,
			solver = :empty_solver)

im_traj = ImplicitTrajectory(ref_traj, sim,
	κ = 1.0e-4,
	mode = :configuration,
	opts=ip_opts)

initialize_trajectories!(s, ref_traj, warm_start_duals = false,
	ref_traj.q[1], ref_traj.q[2])

# compute residual
compute_residual!(s, s.u, s.qa, s.qb, s.ν1, s.ν2, s.H, im_traj, sim.model, sim.env, 1.0e-4)
@show r_norm = residual_norm(s, 1)

# factorize system
factorize!(s)

# solve system
ContactImplicitMPC.solve!(s)

# line search the step direction
α = 1.0
iter = 0
step!(s, α)

# compute candidate residual
compute_residual!(s, s.u_cand, s.qa_cand, s.qb_cand, s.ν1_cand, s.ν2_cand, s.H, im_traj, sim.model, sim.env, 1.0e-4)
residual_norm(s, 1)

newton_solve!(s, sim, im_traj, ref_traj, q0 = ref_traj.q[1], q1 = ref_traj.q[2], warm_start = false, κ = 1.0e-4)

# update!(im_traj, ref_traj_copy, sim, zeros(sim.model.nc), κ = 1.0e-4) #@@@ only keep the rotation stuff not the altitude update.
#
# stride = get_stride(sim.model, ref_traj_copy)
# rot_n_stride!(ref_traj_copy, stride)
