# AbstractPC type of Petsc matrix-explicit

"""
  [`AbstractPC`](@ref) implementation for Petsc matrix-explicit preconditioners.

  Methods in NonlinearSolvers that want to use a Petsc matrix-explicit
  preconditioner are encouraged to use composition, ie. create their own
  [`AbstractPC`](@ref) type and include a PetscMatPC as a field.  This allows
  the nonlinear method to use the functions defined on PetscMatPC as a building.

  **Field**

   * pc: a Petsc PC object
   * Ap: a PetscMat object used to calculate the preconditioner
"""
type PetscMatPC <: AbstractPetscMatPC
  pc::PC  # Petsc PC object
  Ap::PetscMat  # Petsc Mat object
  xtmp::PetscVec  # reusable temporary vector
  btmp::PetscVec
  is_assembled::Array{Bool, 1}  # is Ap assembled
  is_setup::Bool  # is PC already set up
  is_finalized::Bool

  # MPI stuff
  comm::MPI.Comm
  myrank::Int
  commsize::Int
end


function PetscMatPC(mesh::AbstractMesh, sbp::AbstractSBP,
                    eqn::AbstractSolutionData, opts::Dict)

  pc = createPetscPC(mesh, sbp, eqn, opts)
  Ap = createPetscMat(mesh, sbp, eqn, opts)
  xtmp = createPetscVec(mesh, sbp, eqn, opts)
  btmp = createPetscVec(mesh, sbp, eqn, opts)
  is_assembled = Bool[false]
  is_setup = false
  is_finalized = false

  comm = eqn.comm
  myrank = eqn.myrank
  commsize = eqn.commsize

  return PetscMatPC(pc, Ap, xtmp, btmp, is_assembled, is_setup, is_finalized,
                    comm, myrank, commsize)
end

function free(pc::PetscMatPC)

  if !pc.is_finalized
    if pc.pc.pobj != C_NULL
      PetscDestroy(pc.pc)
      pc.pc.pobj = C_NULL
    end

    if pc.Ap.pobj != C_NULL
      PetscDestroy(pc.Ap)
      pc.Ap.pobj = C_NULL
    end

    if pc.xtmp.pobj != C_NULL
      PetscDestroy(pc.xtmp)
      pc.xtmp.pobj = C_NULL
    end

    if pc.btmp.pobj != C_NULL
      PetscDestroy(pc.btmp)
      pc.btmp.pobj = C_NULL
    end
  end

  pc.is_finalized = true

  return nothing
end




function calcPC(pc::PetscMatPC, mesh::AbstractMesh, sbp::AbstractSBP,
                eqn::AbstractSolutionData, opts::Dict, ctx_residual, t)

  # compute the jacobian here
#  physicsJac(mesh, sbp, eqn, opts, pc.Ap, ctx_residual, t)
 
  # don't setup the PC here because PC built on top of this one might
  # modify Ap after calling this function
  setIsAssembled(pc, false)
  pc.is_setup = false

  return nothing
end


function applyPC(pc::AbstractPetscMatPC, mesh::AbstractMesh, sbp::AbstractSBP,
                 eqn::AbstractSolutionData, opts::Dict, t, b::AbstractVector, 
                 x::AbstractVector)

  pc2 = getBasePC(pc)

  # assemble matrix (if needed)
  assemblePetscData(pc2, b, pc.btmp)

  if !pc2.is_setup
    setupPC(pc2)
  end

  # call Petsc PCApply
  PetscPCApply(pc2.pc, pc2.btmp, pc2.xtmp)

  # copy back to x
  xtmp, x_ptr = PetscVecGetArrayRead(pc2.xtmp)
  copy!(x, xtmp)
  PetscVecRestoreArrayRead(pc2.xtmp, x_ptr)

  return nothing
end


function applyPCTranspose(pc::AbstractPetscMatPC, mesh::AbstractMesh,
                 sbp::AbstractSBP,
                 eqn::AbstractSolutionData, opts::Dict, t,
                 b::AbstractVector, x::AbstractVector)


  pc2 = getBasePC(pc)
  @assert pc2 <: PetscMatPC

  if !PCApplyTransposeExists(pc2.pc)
    ptype = PCGetType(pc2.pc)
    throw(ErrorException("PCApplyTranspose not defined for PC $ptype"))
  end

  # assemble matrix (if needed)
  assemblePetscData(pc2, b, pc2.btmp)

  if !pc2.is_setup
    setupPC(pc2)
  end

  # call Petsc PCApplyTranspose
  PetscPCApplyTranspose(pc2.pc, pc2.btmp, pc2.xtmp)

  # copy back to x
  xtmp, x_ptr = PetscVecGetArrayRead(pc2.xtmp)
  copy!(x, xtmp)
  PetscVecRestoreArrayRead(pc2.xtmp, x_ptr)

  return nothing
end


"""
  This internal function is used to setup the PC, including setting the flag.
  Users only need to do this if they did not call [`setupPC`](@ref)

  The matrix pc.Ap must be assembled before this function is called.

  **Inputs**

   * pc: PetscMatPC object
"""
function setupPC(pc::PetscMatPC)

  PCSetUp(pc.pc)
  # this is potentially bad because Petsc will *never* recompute the 
  # preconditioner on its own.  Using higher level functionality like TS
  # or Petsc nonlinear solvers likely won't work in this case
  PCSetReusePreconditioner(pc.pc, PETSC_TRUE)
  pc.is_setup = true

  return nothing
end

function assemblePetscData(pc::PetscMatPC, b::AbstractVector, b_petsc::PetscVec)

  myrank = pc.myrank

  if !getIsAssembled(pc)
    PetscMatAssemblyBegin(lo2.A, PETSC_MAT_FINAL_ASSEMBLY)
  end

  # copy values into the vector
  btmp, b_ptr = PetscVecGetArray(b_petsc)
  copy!(btmp, b)
  PetscVecRestoreArray(b_petsc, b_ptr)

  if !getIsAssembled(pc)
    PetscMatAssemblyEnd(lo2.A, PETSC_MAT_FINAL_ASSEMBLY)
    setIsAssembled(pc, true)
    matinfo = PetscMatGetInfo(lo2.A, PETSc.MAT_LOCAL)
    if matinfo.mallocs > 0.5  # if any mallocs
      println(BSTDERR, "Warning: non-zero number of mallocs for A on process $myrank: $(matinfo.mallocs) mallocs")
    end
  end

  return nothing
end


"""
  Internal function for recording whether pc.Ap is assembled or not
"""
function setIsAssembled(pc::PetscMatPC, val::Bool)

  pc.is_assembled[1] = val

  return nothing
end

"""
  Internal function for retrieving whether pc.Ap is assembled or not.
"""
function getIsAssembled(pc::PetscMatPC)

  return pc.is_assembled[1]
end


function getBasePC(pc::PetscMatPC)

  # this is the bottom of the recursion tree
  return pc
end
