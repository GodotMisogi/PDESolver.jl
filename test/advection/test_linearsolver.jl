# tests for the LinearSolver module

function test_linearsolver()


  fname = "input_vals_linear.jl"
  mesh, sbp, eqn, opts = run_advection(fname)

  facts("----- Testing Linear Solver -----") do
    test_dense(mesh, sbp, eqn, opts)
    test_sparsedirect(mesh, sbp, eqn, opts)
    test_petscmat(mesh, sbp, eqn, opts)
  end


end

function test_dense(mesh, sbp, eqn, opts)

  pc = PCNone(mesh, sbp, eqn, opts)
  lo = DenseLO(pc, mesh, sbp, eqn, opts)
  ls = StandardLinearSolver(pc, lo, eqn.comm)

  ctx_residual = (evalResidual,)
  t = 0.0
  calcLinearOperator(ls, mesh, sbp, eqn, opts, ctx_residual, t)
  rand!(lo.A)
  for i=1:mesh.numDof
    lo.A[i, i] = 5  # make non-singular
  end

  A_orig = copy(lo.A)
  b = rand(mesh.numDof)

  # test product
  c = lo.A*b
  c2 = zeros(c)
  applyLinearOperator(ls.lo, mesh, sbp, eqn, opts, ctx_residual, t, b, c2)
  @fact norm(c - c2) --> roughly(0.0, atol=1e-12)

  # test transpose product
  c = lo.A.'*b
  applyLinearOperatorTranspose(ls.lo, mesh, sbp, eqn, opts, ctx_residual, t, b, c2)
  @fact norm(c - c2) --> roughly(0.0, atol=1e-12)

  # test solve
  x = lo.A\b
  x2 = zeros(x)
  linearSolve(ls, b, x2)
  @fact norm(x2 - x) --> roughly(0.0, atol=1e-12)

  # test transpose solve
  x = A_orig.'\b
  x2 = zeros(x)
  linearSolveTranspose(ls, b, x2)
  @fact norm(x2 - x) --> roughly(0.0, atol=1e-12)


  
  # test product (again)
  c = A_orig*b
  c2 = zeros(c)
  @fact_throws applyLinearOperator(ls.lo, mesh, sbp, eqn, opts, ctx_residual, t, b, c2)
  #=
  @fact norm(c - c2) --> roughly(0.0, atol=1e-12)
  println("c = \n", c)
  println("c2 = \n", c2)
  println("diff = \n", c2 - c)
  println("ipiv = \n", ls.lo.ipiv)
  =#
  

  # transpose product throws
  @fact_throws applyLinearOperatorTranspose(ls.lo, mesh, sbp, eqn, opts, ctx_residual, t, b, c2)

  # test that the factorization is not performed again

  x = A_orig\b
  x3 = zeros(x2)
  linearSolve(ls, b, x3)
  @fact norm(x3 - x) --> roughly(0.0, atol=1e-12)
  @fact ls.lo.nfactorizations --> 1
  @fact ls.lo.nsolves --> 2

  free(ls)

  return nothing
end



function test_sparsedirect(mesh, sbp, eqn, opts)

  # test sparse direct solve
  println("testing sparse direct linear solver")
  pc = PCNone(mesh, sbp, eqn, opts)
  lo = SparseDirectLO(pc, mesh, sbp, eqn, opts)
  ls = StandardLinearSolver(pc, lo, eqn.comm)

  ctx_residual = (evalResidual,)
  t = 0.0
  calcLinearOperator(ls, mesh, sbp, eqn, opts, ctx_residual, t)
  rand!(lo.A.nzval)
  for i=1:mesh.numDof
    lo.A[i, i] = 5  # make non-singular
  end

  A_orig = copy(lo.A)
  b = rand(mesh.numDof)

  # test product
  c = lo.A*b
  c2 = zeros(c)
  applyLinearOperator(ls.lo, mesh, sbp, eqn, opts, ctx_residual, t, b, c2)
  @fact norm(c - c2) --> roughly(0.0, atol=1e-12)

  # test transpose product
  c = A_orig.'*b
  applyLinearOperatorTranspose(ls.lo, mesh, sbp, eqn, opts, ctx_residual, t, b, c2)
  @fact norm(c - c2) --> roughly(0.0, atol=1e-12)

  # test solve
  x = factorize(lo.A)\b
  x2 = zeros(x)
  linearSolve(ls, b, x2)
  @fact norm(x2 - x) --> roughly(0.0, atol=1e-12)
  println("finished testing solve")

  # test transpose solve
  x = A_orig.'\b
  x2 = zeros(x)
  linearSolveTranspose(ls, b, x2)
  @fact norm(x2 - x) --> roughly(0.0, atol=1e-12)
  println("finished testing solve")


  
  # test product (again)
  c = lo.A*b
  c2 = zeros(c)
  applyLinearOperator(ls.lo, mesh, sbp, eqn, opts, ctx_residual, t, b, c2)
  @fact norm(c - c2) --> roughly(0.0, atol=1e-12)

  # test transpose product (again)
  c = A_orig.'*b
  applyLinearOperatorTranspose(ls.lo, mesh, sbp, eqn, opts, ctx_residual, t, b, c2)
  @fact norm(c - c2) --> roughly(0.0, atol=1e-12)

  setTolerances(ls, 1e-16, 1e-16, -1, -1)
  # test solve (again)
  x = factorize(lo.A)\b
  x2 = zeros(x)
  linearSolve(ls, b, x2)
  @fact norm(x2 - x) --> roughly(0.0, atol=1e-12)
  @fact ls.lo.nfactorizations --> 1
  @fact ls.lo.nsolves --> 2
  println("finished testing solve")

  # test transpose solve
  x = lo.A.'\b
  x2 = zeros(x)
  linearSolveTranspose(ls, b, x2)
  @fact norm(x2 - x) --> roughly(0.0, atol=1e-12)
  @fact ls.lo.nfactorizations --> 1
  @fact ls.lo.ntsolves --> 2
  println("finished testing solve")


  free(ls)

  return nothing
end

function test_petscmat(mesh, sbp, eqn, opts)

  if PetscInitialized() == 0
    PetscInitialize()
  end
  PetscSetOptions(opts["petsc_options"])

  vals = rand(mesh.numDof, mesh.numDof)
  for i=1:mesh.numDof
    vals[i, i] = 5  # make nearly diagonally dominant
  end

  pc = PetscMatPC(mesh, sbp, eqn, opts)
  lo = PetscMatLO(pc, mesh, sbp, eqn, opts)
  ls = StandardLinearSolver(pc, lo, eqn.comm)
  ctx_residual = (evalResidual,)
  t = 0.0

  # for testing
  MatSetOption(lo.A, PETSc.MAT_NEW_NONZERO_ALLOCATION_ERR, PETSC_FALSE)

  calcLinearOperator(ls, mesh, sbp, eqn, opts, ctx_residual, t)
  idx = collect(PetscInt, 1:mesh.numDof)
  idy = copy(idx)
  set_values1!(lo.A, idx, idy, vals, PETSC_ADD_VALUES)

  b = rand(mesh.numDof)

  # test product
  c = vals*b
  c2 = zeros(c)
  applyLinearOperator(ls.lo, mesh, sbp, eqn, opts, ctx_residual, t, b, c2)
  @fact norm(c - c2) --> roughly(0.0, atol=1e-12)

  # test transpose product
  c = vals.'*b
  applyLinearOperatorTranspose(ls.lo, mesh, sbp, eqn, opts, ctx_residual, t, b, c2)
  @fact norm(c - c2) --> roughly(0.0, atol=1e-12)

  # test solve
  x = vals\b
  x2 = zeros(x)
  linearSolve(ls, b, x2)
  @fact norm(x2 - x) --> roughly(0.0, atol=1e-12)
  println("finished testing solve")

  # test transpose solve
  x = vals.'\b
  x2 = zeros(x)
  linearSolveTranspose(ls, b, x2)
  @fact norm(x2 - x) --> roughly(0.0, atol=1e-12)
  println("finished testing solve")


 free(ls)

  return nothing
end

add_func1!(AdvectionTests, test_linearsolver, [TAG_TMP, TAG_SHORTTEST])


