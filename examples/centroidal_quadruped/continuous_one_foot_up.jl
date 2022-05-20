# PREAMBLE

# PKG_SETUP

# ## Setup

using ContactImplicitMPC
using LinearAlgebra
using Quaternions

# ## Visualizer
vis = ContactImplicitMPC.Visualizer()
ContactImplicitMPC.open(vis)

@show Threads.nthreads()

# include("continuous_policy.jl")
include("continuous_policy_v2.jl")

# ## Simulation
s = get_simulation("centroidal_quadruped", "flat_3D_lc", "flat")
model = s.model
env = s.env

# ## Reference Trajectory
ref_traj = deepcopy(get_trajectory(s.model, s.env,
	# joinpath(@__DIR__, "reference/one_foot_up_heavy_feet.jld2"),
	joinpath(@__DIR__, "reference/one_foot_up.jld2"),
    load_type = :split_traj_alt));


H = ref_traj.H
h = ref_traj.h

# ## MPC setup
N_sample = 5
H_mpc = 10
h_sim = h / N_sample
H_sim = 1000

κ_mpc = 2.0e-4

v0 = 0.0
obj = TrackingVelocityObjective(model, env, H_mpc,
    v = [Diagonal(1e-3 * [[1,1,1]; 1e+2*[1,1,1]; 1*fill([1,1,1], 4)...]) for t = 1:H_mpc],
	q = [relative_state_cost(1*[1e-2,1e-2,1], 3e-2*[1,1,1], 1e-0*[0.2,0.2,1]) for t = 1:H_mpc],
	u = [Diagonal(3e-4 * vcat(fill([1e1,1e1,1], 4)...)) for t = 1:H_mpc],
	v_target = [1/ref_traj.h * [v0;0;0; 0;0;0; v0;0;0; v0;0;0; v0;0;0; v0;0;0] for t = 1:H_mpc],)

p = ci_mpc_policy(ref_traj, s, obj,
    H_mpc = H_mpc,
    N_sample = N_sample,
    κ_mpc = κ_mpc,
	mode = :configuration,
	ip_opts = InteriorPointOptions(
					undercut = 5.0,
					κ_tol = κ_mpc,
					r_tol = 1.0e-4, # TODO maybe relax this parameter
					diff_sol = true,
					solver = :empty_solver,
					max_time = 1e5),
    n_opts = NewtonOptions(
        r_tol = 3e-5,
        max_time=10.0e-1,
		solver=:ldl_solver,
        threads=false,
        verbose=false,
        max_iter = 5),
    mpc_opts = CIMPCOptions(
		# live_plotting=true
		));

# ## Disturbances
w = [[0.0,0.0,0.0] for i=1:H_sim/N_sample]
d = open_loop_disturbances(w, N_sample)

# ## Initial conditions
q1_sim, v1_sim = initial_conditions(ref_traj);

# ## Simulator
sim = simulator(s, H_sim, h=h_sim, policy=p, dist=d);


using BenchmarkTools
# ## Simulate
q1_sim0 = deepcopy(q1_sim)
# RoboDojo.simulate!(sim, q1_sim0, v1_sim)
q1_sim0[1] = 0.0
q1_sim0[4] = 0.0
q1_sim0[5] = 0.0
q1_sim0[6] = 0.0
q1_sim0[7] += 0.01
q1_sim0[8] += 0.01
q1_sim0[10] -= 0.01
q1_sim0[11] -= 0.01
q1_sim0[13] += 0.05
q1_sim0[14] -= 0.02 
q1_sim0[16] -= 0.01
q1_sim0[17] += 0.02
q1_sim0[9] = 0
RoboDojo.set_state!(sim, q1_sim0, v1_sim, 1)
simulate!(sim,clock_time_noise=1.0e-3)

# ## Visualize
set_light!(vis)
set_floor!(vis, grid=true)
set_background!(vis)
anim = visualize!(vis, model, sim.traj.q; Δt=h_sim)

# # ## Timing result
# # Julia is [JIT-ed](https://en.wikipedia.org/wiki/Just-in-time_compilation) so re-run the MPC setup through Simulate for correct timing results.
process!(sim.stats, N_sample) # Time budget
H_sim * h_sim / sum(sim.stats.policy_time) # Speed ratio
plot(sim.stats.policy_time, xlabel="timestep", ylabel="mpc time (s)",
	ylims=[-0.001, 0.03],
	label="", linetype=:steppost)

u_mat = hcat(sim.traj.u...)
q_mat = hcat(sim.traj.q...)
plot!(u_mat[3,:]./sim.h)
plot(q_mat[1,:], q_mat[2,:])
q_mat[16:18,end]