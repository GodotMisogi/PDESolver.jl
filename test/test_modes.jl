
facts("--- Testing Sparse/Dense Jacobian ---") do

  resize!(ARGS, 1)
  ARGS[1] = "input_vals_vortex.jl"

#  ARGS[1] = "input_vals_vortex5.jl"
  include("../src/solver/euler/startup.jl")

  @fact calcNorm(eqn, eqn.res_vec) => less_than(1e-9)

  initializeTempVariables(mesh)
  println("testing jacobian vector product")
  # test jacobian vector product
  # load a new initial condition
  ICFunc = EulerEquationMod.ICDict["ICIsentropicVortex"]
  ICfunc(mesh, sbp, eqn, opts, eqn.q_vec)
  NonlinearSolvers.disassembleSolution(mesh, sbp, eqn, opts, eqn.q_vec)
  jac = SparseMatrixCSC(mesh.sparsity_bnds, typeof(real(eqn.res[1])))
  epsilon = 1e-20
  pert = complex(0, epsilon)
  NonlinearSolvers.calcJacobianSparse(mesh, sbp, eqn, opts, EulerEquationMod.evalEuler, Array(Float64, 0,0,0), pert, jac)

  newton_data = NonlinearSolvers.NewtonData(mesh, sbp, eqn, opts)
  v = ones(mesh.numDof)  # vector to multiply jacobian against
  result1 = jac*v
  result2 = zeros(mesh.numDof)
  NonlinearSolvers.calcJacVecProd(newton_data, mesh, sbp, eqn, opts, pert, EulerEquationMod.evalEuler, v, result2)

  # check the two products are equal
  for i=1:mesh.numDof
    @fact result1[i] => roughly(result2[i])
  end

#  results_all = hcat(result1, result2)
#  println("results_all = \n", results_all)

#  results_diff = result1 - result2
#  diff_norm = calcNorm(eqn, results_diff)
#  println("diff_norm = ", diff_norm)


  resize!(ARGS, 1)
  ARGS[1] = "input_vals_vortex2.jl"

  include("../src/solver/euler/startup.jl")

  @fact calcNorm(eqn, eqn.res_vec) => less_than(1e-9)

  resize!(ARGS, 1)
  ARGS[1] = "input_vals_vortex3.jl"

  include("../src/solver/euler/startup.jl")

  @fact calcNorm(eqn, eqn.res_vec) => less_than(1e-9)

  resize!(ARGS, 1)
  ARGS[1] = "input_vals_vortex4.jl"

  include("../src/solver/euler/startup.jl")

  @fact calcNorm(eqn, eqn.res_vec) => less_than(1e-9)

end
