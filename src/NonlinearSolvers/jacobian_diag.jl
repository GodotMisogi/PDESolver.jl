# get the diagonal block of the jacobian



#------------------------------------------------------------------------------
# Block diagonal matrix type

"""
  A special array type for holding a block-diagonal matrix
"""
immutable DiagJac{T} <: AbstractArray{T, 2}
  A::Array{T, 3}
end

"""
  Outer constructor for [`DiagJac`](@ref).

  **Inputs**

   * T: element type of the matrix
   * blocksize: the blocksize of the diagonal blocks
   * nblock: number of blocks.

   The size of the matrix is `blocksize`*`nblock`.
   Only square block are supported at this time

"""
function DiagJac{T}(::Type{T}, blocksize::Integer, nblock::Integer)

  A = zeros(T, blocksize, blocksize, nblock)

  return DiagJac{T}(A)
end

import Base: length, size, getindex, setindex!, show

"""
  Returns the length of the array *as if it were a dense matrix*
"""
function length(A::DiagJac)

  blocksize, blocksize, nblock = size(A.A)
  n = blocksize*nblock
  return n*n
end

function size(A::DiagJac)

  blocksize, blocksize, nblock = size(A.A)

  n = blocksize*nblock
  return (n, n)
end

"""
  Internal function for computing the indices in the 3D array

  **Inputs**

   * A : DaigJac
   * i: first index
   * j: second index

  **Outputs**

   * i2: first index in 3D array
   * j2: second index in 3D array
   * i2block: 3rd index in 3D array
"""
function computeIndex(A::DiagJac, i::Integer, j::Integer)
# internal function for computing indices

  blocksize, blocksize, nblock = size(A.A)

  i2 = ((i-1) % blocksize ) + 1
  i2block = div(i-1, blocksize) + 1

  j2 = ((j-1) % blocksize) + 1
  j2block = div(j-1, blocksize) + 1

  @assert i2block <= nblock
  @assert i2block > 0
  @assert j2block <= nblock
  @assert j2block > 0

  @assert i2 > 0
  @assert i2 <= blocksize
  @assert j2 > 0
  @assert j2 <= blocksize

  @assert i2block == j2block

  return i2, j2, i2block
end


"""
  Indexing using non-block indices
"""
function getindex(A::DiagJac, i::Integer, j::Integer)

  i2, j2, i2block = computeIndex(A, i, j)
  return A.A[i2, j2, i2block]
end

"""
  Indexing using non-block indices
"""
function setindex!(A::DiagJac, v, i::Integer, j::Integer)

  i2, j2, i2block = computeIndex(A, i, j)
  return A.A[i2, j2, i2block] = v
end

function show(io::IO, A::DiagJac)

  m, n = size(A)
  println("DiagJac: $m x $n block diagonal matrix with block size: $(size( A.A, 1)), number of blocks: $(size(A.A, 3))")
  for i=1:size(A.A, 3)
    println("block ", i, " = ")
    println(A.A[:, :, i])
  end

  return nothing
end

"""
  Matrix-vector multiplication function for [`DiagJac`](@ref)

  **Inputs**

   * A: a `DiagJac`
   * x: vector to multiply against

  **Inputs/Outputs**

   * b: vector to be overwritten with the result
"""
function diagMatVec(A::DiagJac, mesh::AbstractDGMesh, x::AbstractVector, b::AbstractVector)

  blocksize, blocksize, nblock = size(A.A)

  @assert blocksize == mesh.numDofPerNode*mesh.numNodesPerElement

  # work arrays
  xblock = zeros(eltype(x), blocksize)
  bblock = zeros(eltype(b), blocksize)
  for i=1:nblock
    
    # gather dofs in x
    idx = 1
    for j=1:mesh.numNodesPerElement
      for k=1:mesh.numDofPerNode
        xblock[idx] = x[mesh.dofs[k, j, i]]
        idx += 1
      end
    end
    Ablock = sview(A.A, :, :, i)
    smallmatvec!(Ablock, xblock, bblock)

    # scatter to b
    idx = 1
    for j=1:mesh.numNodesPerElement
      for k=1:mesh.numDofPerNode
        b[mesh.dofs[k, j, i]] = bblock[idx]
        idx += 1
      end
    end

  end  # end loop i

  return nothing
end
#------------------------------------------------------------------------------
# New AssembleElementData type for getting the diagonal only

type AssembleDiagJacData{T} <: AssembleElementData
  A::DiagJac{T}
end

function AssembleDiagJacData{T}(mesh, sbp, eqn, opts, jac::DiagJac{T})

  return AssembleDiagJacData{T}(jac)
end

"""
  Assembles the block diagonal part of the volume integral contribution only.
  The off diagonal part of `jac` is never touched.
"""
function assembleElement{T}(helper::AssembleDiagJacData, mesh::AbstractMesh,
                            elnum::Integer, jac::AbstractArray{T, 4})

  # depending on how dofs were assigned, this might not result in helper.A
  # having the same layout as the real Jacobian.  Need to make sure the
  # mat-vec function selects the correct indices to multiply against

  for q=1:mesh.numNodesPerElement
    for p=1:mesh.numNodesPerElement

      # get values
      @simd for j=1:mesh.numDofPerNode
        @simd for i=1:mesh.numDofPerNode
          i1 = i + (p-1)*mesh.numDofPerNode
          j1 = j + (q-1)*mesh.numDofPerNode
          helper.A.A[i1, j1, elnum] += real(jac[i, j, p, q])
        end
      end

    end  # end loop p
  end  # end loop q



  return nothing
end

function assembleInterface{T}(helper::AssembleDiagJacData,
                              sbpface::DenseFace,
                              mesh::AbstractMesh, iface::Interface,
                              jacLL::AbstractArray{T, 4},
                              jacLR::AbstractArray{T, 4},
                              jacRL::AbstractArray{T, 4},
                              jacRR::AbstractArray{T, 4})

  numNodesPerElement = size(jacLL, 4)
  numDofPerNode = size(jacLL, 1)

  permL = sview(sbpface.perm, :, iface.faceL)
  permR = sview(sbpface.perm, :, iface.faceR)

  for q=1:sbpface.stencilsize
    qL = sbpface.perm[q, iface.faceL]
    qR = sbpface.perm[q, iface.faceR]

    for p=1:sbpface.stencilsize
      pL = sbpface.perm[p, iface.faceL]
      pR = sbpface.perm[p, iface.faceR]

      # put values into 2 x 2 block matrix
      @simd for j=1:numDofPerNode
        @simd for i=1:numDofPerNode
          i1 = i + (pL-1)*mesh.numDofPerNode
          j1 = j + (qL-1)*mesh.numDofPerNode
          i2 = i + (pR-1)*mesh.numDofPerNode
          j2 = j + (qR-1)*mesh.numDofPerNode
          helper.A.A[i1, j1, iface.elementL] +=  jacLL[i, j, pL, qL]
          helper.A.A[i2, j2, iface.elementR] +=  jacRR[i, j, pR, qR]
        end
      end

    end # end loop p
  end  # end loop q

  return nothing
end

function assembleSharedFace{T}(helper::AssembleDiagJacData, sbpface::DenseFace,
                               mesh::AbstractMesh,
                               iface::Interface,
                               jacLL::AbstractArray{T, 4},
                               jacLR::AbstractArray{T, 4})

#    for p in permR # =1:numNodesPerElement
  for q=1:sbpface.stencilsize
    qL = sbpface.perm[q, iface.faceL]

    for p=1:sbpface.stencilsize
      pL = sbpface.perm[p, iface.faceL]

      # put values into 2 x 2 block matrix
      for j=1:mesh.numDofPerNode
        for i=1:mesh.numDofPerNode
          i1 = i + (pL-1)*mesh.numDofPerNode
          j1 = j + (qL-1)*mesh.numDofPerNode

          helper.A.A[i1, j1, face.elementL] += jacLL[i, j, pL, qL]
        end
      end

    end  # end loop p
  end


  return nothing
end

function assembleBoundary{T}(helper::AssembleDiagJacData, sbpface::DenseFace,
                               mesh::AbstractMesh,
                               bndry::Boundary,
                               jac::AbstractArray{T, 4})
  for q=1:sbpface.stencilsize
    qL = sbpface.perm[q, bndry.face]


    for p=1:sbpface.stencilsize
      pL = sbpface.perm[p, bndry.face]

      # get dofs for node p
      dof1 = mesh.dofs[1, pL, bndry.element]
      blockidx = div(dof1 - 1, mesh.numDofPerNode) + 1

      # get values
      for j=1:mesh.numDofPerNode
        for i=1:mesh.numDofPerNode
          i1 = i + (pL-1)*mesh.numDofPerNode
          j1 = j + (qL-1)*mesh.numDofPerNode

          helper.A.A[i1, j1, bndry.element] += jac[i, j, pL, qL]
        end
      end

    end  # end loop p
  end  # end loop q

  return nothing
end

#------------------------------------------------------------------------------
# apply the stabilization to the diagonal Jacobian

"""
  This function takes the block-diagonal Jacobian `A` and a solution
  vector `q_vec` and removes the unstable modes using
  [`removeUnstalbeModes!`](@ref).

  **Inputs**

   * q_vec: solution vector (the local part)

  **Inputs/Outputs**

   * A: a DiagJac containing the block diagonal Jacobian.  On exit, it will
        have the unstable modes removed.
"""
function filterDiagJac{T, T2}(A::DiagJac{T}, q_vec::AbstractVector{T2})

  blocksize, blocksize, nblock = size(A.A)
  T3 = promote_type(T, T2)

  @assert blocksize == mesh.numDofPerNode

  workvec = zeros(T3, mesh.numDofPerNode)  # work array for inner function
  Ablock = zeros(T, blocksize, blocksize)  # copy array into this to negate it

  for k=1:nblock
    # because the inner function assumes the residual is defined as
    # du/dt + R(u) = 0, but Ticon writes it as du/dt = R(u), we have to
    # multiply the Jacobian by -1 to make the unstable modes the negative
    # eigenvalues
    for j=1:blocksize
      for i=1:blocksize
        Ablock[i, j] = -A.A[i, j, k]
      end
    end

    blockidx = ((k-1)*blocksize + 1):(k*blocksize)
    u_k = sview(q_vec, blockidx)

    removeUnstableModes!(Ablock, u_k)

    # copy back
    for j=1:blocksize
      for i=1:blocksize
        A.A[i, j, k] = Ablock[i, j]
      end
    end

  end  # end loop k

  return nothing
end





"""
  modifies matrix `Jac` such that `u.'*sym(Jac)*u` is strictly positive

  **Inputs**

   * `u`: an given vector whose dimensions are consistent with `Jac`
   * `A`: a work vector needed by this function (overwritten).  The
          element type should be the "maximum" type of the element types
          of `u` and `Jac`

  **Inputs/Outputs**

   * `Jac`: matrix being modified
"""
function removeUnstableModes!{T}(Jac::AbstractMatrix,
                                 u::AbstractVector,
                                 A::AbstractVector{T})
  @assert( size(Jac,1) == size(Jac,2) == length(u) )
  n = size(Jac,1)
  # compute baseline product, 0.5*u.'*(Jac^T + Jac)*u
  prod = zero(T)
  for i = 1:n
    for j = 1:n
      prod += 0.5*(Jac[i,j] + Jac[j,i])*u[i]*u[j]
    end
  end
  if prod > 0
    # nothing to do
    return
  end
  # array A stores the entries in the contraint Jacobian
#  A = zeros(div(n*(n+1),2))
  for i = 1:n
    A[div(i*(i-1),2)+i] = u[i]*u[i]
    for j = 1:(i-1)
      A[div(i*(i-1),2)+j] = 2.0*u[i]*u[j]
    end
  end
  scale!(A, -prod/dot(A,A))
#  A *= -prod/dot(A,A)
  for i = 1:n
    Jac[i,i] += A[div(i*(i-1),2)+i]
    for j = 1:(i-1)
      Jac[i,j] += A[div(i*(i-1),2)+j]
      Jac[j,i] += A[div(i*(i-1),2)+j]
    end
  end

  return nothing
end
