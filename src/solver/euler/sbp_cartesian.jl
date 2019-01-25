# functions for applying SBP operators in Cartesian directions (rather than
# parametric directions).  These functions should eventually be migrated into
# SummationByParts.jl


#------------------------------------------------------------------------------
# Functions for computing [Dx * w, Dy * w, Dz * w]

"""
  Computes Qx^T * w in all Cartesian directions.

  **Inputs**

   * sbp: the SBP operator
   * w: `numDofPerNode` x `numNodesPerElement` array of values
   * dxidx: `dim` x `dim` x `numNodesPerElement` array containing the metrics
   * op: a UnaryFunctor that determines if values are added or subtracted to
         `wx`

  **Inputs/Outputs**

   * wxi: temporary array, `numDofPerNode` x `numNodesPerElement` x `dim`
   * wx: array updates with the result, same size as `wxi`.
"""
function applyQxTransposed(sbp, w::AbstractMatrix, dxidx::Abstract3DArray,
                             wxi::Abstract3DArray, wx::Abstract3DArray,
                             op::SummationByParts.UnaryFunctor=SummationByParts.Add())

  # The idea is to compute dw/dxi first, and then use dxi/dx to rotate those
  # arrays to be d/dx

  # compute dw/dxi
  numDofPerNode, numNodesPerElement, dim = size(wx)
  for d=1:dim
    smallmatmat!(w, sview(sbp.Q, :, :, d), sview(wxi, :, :, d))
  end

  # dw/dx = dw/dxi * dxi/dx + dw/dy * dy/dxi
  @simd for d1=1:dim
    @simd for i=1:numNodesPerElement
      @simd for d2=1:dim
        @simd for j=1:numDofPerNode
          wx[j, i, d1] += op(wxi[j, i, d2]*dxidx[d2, d1, i])
        end
      end
    end
  end

  return nothing
end

"""
  Computes Dx * w in all Cartian directions.  See [`applyQxTranspose`](@ref)
  for most of the arguments.  Note that the user is responsible for zeroing out
  `wx` if required.

  **Inputs**

   * sbp
   * w
   * dxidx
   * jac: determinant of the mapping Jacobian, length `numNodesPerElement`.
          This is required because `dxidx` contains a factor of `1/|J|`
   * op

  **Inputs/Outputs**

   * wxi
   * wx
"""
function applyDx(sbp, w::AbstractMatrix, dxidx::Abstract3DArray,
                 jac::AbstractVector,
                 wxi::Abstract3DArray, wx::Abstract3DArray,
                 op::SummationByParts.UnaryFunctor=SummationByParts.Add())

  numDofPerNode, numNodesPerElement, dim = size(wx)
  fill!(wxi, 0)
  for d=1:dim
    differentiateElement!(sbp, d, w, sview(wxi, :, :, d))
  end

  @simd for d1=1:dim
    @simd for j=1:numNodesPerElement
      @simd for d2=1:dim
        fac = jac[j]*dxidx[d2, d1, j]
        @simd for k=1:numDofPerNode
          wx[k, j, d1] += op(wxi[k, j, d2] * fac)
        end
      end
    end
  end

  return nothing
end

"""
  Computes Qx * w in all Cartesian directions.  See [`applyQxTranspose`](@ref)
  for arguments.  Note that the user must zero out `wx` if required.
"""
function applyQx(sbp, w::AbstractMatrix, dxidx::Abstract3DArray,
                 wxi::Abstract3DArray, wx::Abstract3DArray,
                 op::SummationByParts.UnaryFunctor=SummationByParts.Add())

  numDofPerNode, numNodesPerElement, dim = size(wx)
  fill!(wxi, 0)
  for d=1:dim
    weakDifferentiateElement!(sbp, d, w, sview(wxi, :, :, d))
  end

  @simd for d1=1:dim
    @simd for j=1:numNodesPerElement
      @simd for d2=1:dim
        @simd for k=1:numDofPerNode
          wx[k, j, d1] += op(wxi[k, j, d2] * dxidx[d2, d1, j])
        end
      end
    end
  end

  return nothing
end


#------------------------------------------------------------------------------
# Functions that apply the operators to different vectors in each direction and
# sums the result.
# Eg. given wx, wy, wz, compute w = Dx * wx + Dy * wy + Dz * wz

"""
  Performs  res += Qx^T * w[:, :, 1] + Qy^T * w[:, :, 2] (and the z contribution
  in 3D.

  Unlike the other method, `w` is a 3D array and `wx` is a a 2D array

  **Inputs**

   * sbp
   * w: `numDofPerNode` x `numNodesPerElement` x `dim` containing the values
        for each dimension.
   * dxidx: the metric terms, same as other method
   * op: a UnaryFunctor that determines if values are added or subtracted to
         `wx`


  **Inputs/Outputs**

   * wxi: work array, same as other method
   * wx: array to be updated with the result, `numDofPerNode` x
         `numNodesPerElement`.
  
"""
function applyQxTransposed(sbp, w::Abstract3DArray, dxidx::Abstract3DArray,
                             wxi::Abstract3DArray, wx::AbstractMatrix,
                             op::SummationByParts.UnaryFunctor=SummationByParts.Add())


  numDofPerNode, numNodesPerElement, dim = size(wxi)
  for d1=1:dim  # compute Q_d * w_d
    for d2=1:dim
      smallmatmat!(ro_sview(w, :, :, d1), ro_sview(sbp.Q, :, :, d2), sview(wxi, :, :, d2))
    end

    @simd for d2=1:dim
      @simd for j=1:numNodesPerElement
        @simd for k=1:numDofPerNode
          wx[k, j] += op(dxidx[d2, d1, j]*wxi[k, j, d2])
        end
      end
    end

  end  # end d1

  return nothing
end


"""
  Like [`applyQxTransposed`](@ref), but applies D instead of Q^T.  See
  that function for details.  Note that the user must zero out `wx` if
  required.

  **Inputs**

   * sbp
   * w
   * dxidx
   * jac: determinant of the mapping Jacobian, length `numNodesPerElement`.
   * op

  **Inputs/Outputs**

   * wxi
   * wx
"""
function applyDx(sbp, w::Abstract3DArray, dxidx::Abstract3DArray,
                 jac::AbstractVector,
                 wxi::Abstract3DArray, wx::AbstractMatrix,
                 op::SummationByParts.UnaryFunctor=SummationByParts.Add())

  numDofPerNode, numNodesPerElement, dim = size(w)

  @simd for d1=1:dim
    fill!(wxi, 0)
    for d2=1:dim
      differentiateElement!(sbp, d2, sview(w, :, :, d1), sview(wxi, :, :, d2))
    end

    @simd for j=1:numNodesPerElement
      @simd for d2=1:dim
        fac = jac[j]*dxidx[d2, d1, j]
        @simd for k=1:numDofPerNode
          wx[k, j] += op(wxi[k, j, d2] * fac)
        end
      end
    end
  end

  return nothing
end


"""
  Like [`applyQxTransposed`](@ref), but applies Q instead of Q^T.  See
  that function for details.  Note that the user must zero out `wx` if
  required.
"""
function applyQx(sbp, w::Abstract3DArray, dxidx::Abstract3DArray,
                 wxi::Abstract3DArray, wx::AbstractMatrix,
                 op::SummationByParts.UnaryFunctor=SummationByParts.Add())

  numDofPerNode, numNodesPerElement, dim = size(w)

  @simd for d1=1:dim
    fill!(wxi, 0)
    for d2=1:dim
      weakDifferentiateElement!(sbp, d2, sview(w, :, :, d1), sview(wxi, :, :, d2))
    end

    @simd for d2=1:dim
      @simd for j=1:numNodesPerElement
        @simd for k=1:numDofPerNode
          wx[k, j] += op(wxi[k, j, d2] * dxidx[d2, d1, j])
        end
      end
    end
  end

  return nothing
end


