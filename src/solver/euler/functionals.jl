# functional definitions

import PDESolver: createFunctional, _evalFunctional, _evalFunctionalDeriv_m,
                 _evalFunctionalDeriv_q
import ODLCommonTools: getParallelData, setupFunctional


#------------------------------------------------------------------------------
# Lift and drag

@doc """
###EulerEquationMod.BoundaryForceData

Composite data type for storing data pertaining to the boundaryForce. It holds
lift and drag values

"""->

mutable struct BoundaryForceData{Topt, fname} <: AbstractBoundaryFunctional{Topt}
  bcnums::Array{Int,1}

  # factors to multiply x, y, z momenta by, determines if lift or drag is
  # calculated
  facx::Topt
  facy::Topt
  facz::Topt

  # things needed for the calculation
  qg::Vector{Topt}
  euler_flux::Vector{Topt}
end

"""
  Constructor for BoundaryForceData{Topt, :lift}
"""
function LiftForceDataConstructor(::Type{Topt}, mesh, sbp, eqn, opts, bcnums) where Topt

  facx = 0
  facy = 0
  facz = 0

  qg = zeros(Topt, mesh.numDofPerNode)
  euler_flux = zeros(Topt, mesh.numDofPerNode)

  return BoundaryForceData{Topt, :lift}(bcnums, facx, facy, facz, qg,
                                        euler_flux)
end

"""
  Constructor for BoundaryForceData{Topt, :drag}
"""
function DragForceDataConstructor(::Type{Topt}, mesh, sbp, eqn, opts,
                             bcnums) where Topt

  facx = 0
  facy = 0
  facz = 0

  qg = zeros(Topt, mesh.numDofPerNode)
  euler_flux = zeros(Topt, mesh.numDofPerNode)

  return BoundaryForceData{Topt, :drag}(bcnums, facx, facy, facz, qg,
                                        euler_flux)
end


function setupFunctional(mesh::AbstractMesh, sbp, eqn::AbstractSolutionData,
                         opts::Dict, func::BoundaryForceData{Topt, :lift}) where {Topt}

  if mesh.dim == 2
    func.facx = -sin(eqn.params.aoa)
    func.facy =  cos(eqn.params.aoa)
  else
    func.facx = -sin(eqn.params.aoa)
    func.facy =  0
    func.facz =  cos(eqn.params.aoa)
  end

  return nothing
end

function setupFunctional(mesh::AbstractMesh, sbp, eqn::AbstractSolutionData,
                         opts::Dict, func::BoundaryForceData{Topt, :drag}) where {Topt}

  if mesh.dim == 2
    func.facx = cos(eqn.params.aoa)
    func.facy = sin(eqn.params.aoa)
  else
    func.facx = cos(eqn.params.aoa)
    func.facy = 0
    func.facz = sin(eqn.params.aoa)
  end

  return nothing
end


"""
  Functional for computing lift coefficient.  Uses the lift functional to
  compute the force and then divides by the (non-dimensional) dynamic pressure
  0.5*rho_free*Ma^2.  Note that this assumes the chord length (in 2d) is 1
"""
mutable struct LiftCoefficient{Topt} <: AbstractBoundaryFunctional{Topt}
  lift::BoundaryForceData{Topt, :lift}
  bcnums::Array{Int, 1}
end

"""
  Constructor for LiftCoefficient functional
"""
function LiftCoefficientConstructor(::Type{Topt}, mesh, sbp, eqn, opts,
                                    bcnums) where Topt

  lift = LiftForceDataConstructor(Topt, mesh, sbp, eqn, opts, bcnums)

  return LiftCoefficient{Topt}(lift, bcnums)
end


function setupFunctional(mesh::AbstractMesh, sbp, eqn::AbstractSolutionData,
                         opts::Dict, func::LiftCoefficient)

  setupFunctional(mesh, sbp, eqn, opts, func.lift)

end

#------------------------------------------------------------------------------
# other functionals


"""
  Type for computing the mass flow rate over a boundary (integral rho*u dot n
  dGamma)
"""
mutable struct MassFlowData{Topt} <: AbstractBoundaryFunctional{Topt}
  bcnums::Array{Int, 1}
end

"""
  Constructor for MassFlowData.  This needs to have a different name from
  the type so it can be put in a dictionary
"""
function MassFlowDataConstructor(::Type{Topt}, mesh, sbp, eqn, opts, 
                            bcnums) where Topt
  return MassFlowData{Topt}(bcnums)
end

"""
  Type for computing the entropy flux rate over a boundary (integral S * u_i dot n_i
  dGamma), where S is the entropy function (from the IR entropy variables).
"""
mutable struct EntropyFluxData{Topt} <: AbstractBoundaryFunctional{Topt}
  bcnums::Array{Int, 1}
end

"""
  Constructor for EntropyFlux.  This needs to have a different name from
  the type so it can be put in a dictionary
"""
function EntropyFluxConstructor(::Type{Topt}, mesh, sbp, eqn, opts, 
                            bcnums) where Topt
  return EntropyFluxData{Topt}(bcnums)
end

"""
  Functional that computes function `w^T d(u)`, where `w` are the entropy
  variables and `d(u)` is the entropy stable dissipation computed by
  [`ELFPenaltyFaceIntegral`](@ref).  Note that this is an integral
  over interior faces and not boundary faces
"""
mutable struct EntropyDissipationData{Topt} <: EntropyPenaltyFunctional{Topt}
  func::ELFPenaltyFaceIntegral
  func_sparseface::LFPenalty
  func_sparseface_revq::LFPenalty_revq
  func_sparseface_revm::LFPenalty_revm
end

"""
  Constructor for [`EntropyDissipationData`](@ref)

  This function takes `bcnums` as an argument for consistency with 
  the boundary functional constructors, but doesn't use it.
"""
function EntropyDissipationConstructor(::Type{Topt}, mesh, sbp, eqn, opts,
                                       bcnums) where Topt

  func = ELFPenaltyFaceIntegral(mesh, eqn)
  func_sparseface = LFPenalty()
  func_sparseface_revq = LFPenalty_revq()
  func_sparseface_revm = LFPenalty_revm()

  return EntropyDissipationData{Topt}(func, func_sparseface, func_sparseface_revq, func_sparseface_revm)
end


"""
  Returns the negative of [`EntropyDissipationData`](@ref).  That functional
  is always negative, so this one is always positive.
"""
mutable struct NegEntropyDissipationData{Topt} <: EntropyPenaltyFunctional{Topt}
  func::EntropyDissipationData{Topt}
end

"""
  Constructor for [`NegEntropyDissipationData`](@ref).  `bcnums` argument is
  unused.
"""
function NegEntropyDissipationConstructor(::Type{Topt}, mesh, sbp, eqn, opts,
                                       bcnums) where Topt

  func = EntropyDissipationConstructor(Topt, mesh, sbp, eqn, opts, bcnums)
  return NegEntropyDissipationData{Topt}(func)
end


"""
  Functional that computes function `w^T d(u)`, where `w` are the entropy
  variables and `d(u)` is the entropy stable dissipation computed by
  [`ELFPenaltyFaceIntegral`](@ref).  Note that this is an integral
  over interior faces and not boundary faces
"""
mutable struct EntropyJumpData{Topt} <: EntropyPenaltyFunctional{Topt}
  func::EntropyJumpPenaltyFaceIntegral
end

"""
  Constructor for [`EntropyDissipationData`](@ref)

  This function takes `bcnums` as an argument for consistency with 
  the boundary functional constructors, but doesn't use it.
"""
function EntropyJumpConstructor(::Type{Topt}, mesh, sbp, eqn, opts,
                                       bcnums) where Topt

  func = EntropyJumpPenaltyFaceIntegral(mesh, eqn)

  return EntropyJumpData{Topt}(func)
end


function getParallelData(obj::EntropyPenaltyFunctional)
  return PARALLEL_DATA_ELEMENT
end


"""
  Creates a functional object.

**Arguments**

 * `mesh` : Abstract PUMI mesh
 * `sbp`  : Summation-by-parts operator
 * `eqn`  : Euler equation object
 * `opts` : Options dictionary
 * `functional_name`: the name of the functional (in [`FunctionalDict`](@ref)
 * `functional_bcs`: the boundary condition numbers the functional is
                     computed on.
"""
function createFunctional(mesh::AbstractMesh, sbp::AbstractOperator,
                  eqn::EulerData{Tsol}, opts,
                  functional_name::AbstractString,
                  functional_bcs::Vector{I}) where {Tsol, I<:Integer}

  func_constructor = FunctionalDict[functional_name]
  objective = func_constructor(Tsol, mesh, sbp, eqn, opts, functional_bcs)

  return objective
end


"""
  Maps functional names to their outer constructors.

  All outer constructors must have the signature

  MyTypeNameConstructor{Topt}(::Type{Topt}, mesh, sbp, eqn, opts, bcnums)

  where MyTypeName is the name of the type, bcnums are the
  boundary conditions that the functional is
  defined on (Array{Int, 1}), 

  Currently only boundary functionals are supported.

  For non-boundary functionals
  the region numbers associated with the faces would also be needed.
  Consider:

                | -> edge 1
     face 1     |         face2   
                |
                |

  The mesh edges lying on geometric edge 1 have two possible parent elements,
  one of face 1 and one on face 2.  `geom_regions` picks between them.  This
  effectively determines the direction of the normal vector.

  Note that the outer constructor name is the type name with the suffix "Constructor"
"""
global const FunctionalDict = Dict{String, Function}(
"lift" => LiftForceDataConstructor,
"drag" => DragForceDataConstructor,
"massflow" => MassFlowDataConstructor,
"liftCoefficient" => LiftCoefficientConstructor,
"entropyflux" => EntropyFluxConstructor,
"entropydissipation" => EntropyDissipationConstructor,
"negentropydissipation" => NegEntropyDissipationConstructor,
"entropyjump" => EntropyJumpConstructor,
)


