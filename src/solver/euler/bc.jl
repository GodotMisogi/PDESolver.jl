# Euler flux calculator used by isentropicVortexBC ONLY!!

export rho1Energy2BC, isentropicVortexBC


# this function no longer works
function rho1Energy2BC(q, x, dxidx, nrm)

  E1dq = zeros(Float64, 4)
  E2dq = zeros(Float64, 4)

  #=
  println("q: ",q)
  println("x: ",x)
  println("dxidx: ",dxidx)
  println("nrm: ",nrm)
  =#

  # getting qg
  qg = zeros(Float64, 4)
#  calcRho1Energy2(x, eqn, qg)
   calcRho1Energy2U3(x, eqn, qg)
  
#   println("qg: ",qg)

  # Declaring constants 
  d1_0 = 1.0
  d0_0 = 0.0
  d0_5 = 0.5
  tau = 1.0
  sgn = 1.0
  gamma = 1.4
  gami = gamma - 1
  sat_Vn = 0.025
  sat_Vl = 0.025

  # Begin main executuion
  nx = dxidx[1,1]*nrm[1] + dxidx[2,1]*nrm[2]
  ny = dxidx[1,2]*nrm[1] + dxidx[2,2]*nrm[2]

#  println("nrm: ",nrm)
#  println("nx: ",nx)
#  println("ny: ",ny)

  dA = sqrt(nx*nx + ny*ny)
  
  fac = d1_0/q[1]
#   println(typeof(fac))
#   println(typeof(q[4]))
  uL = q[2]*fac; vL = q[3]*fac;
  phi = d0_5*(uL*uL + vL*vL)

  HL = gamma*q[4]*fac - gami*phi
  
  fac = d1_0/qg[1]
  uR = qg[2]*fac; vR = qg[3]*fac;
  phi = d0_5*(uR*uR + vR*vR)
  HR = gamma*qg[4]*fac - gami*phi

  sqL = sqrt(q[1]); sqR = sqrt(qg[1])
  fac = d1_0/(sqL + sqR)
  u = (sqL*uL + sqR*uR)*fac
  v = (sqL*vL + sqR*vR)*fac
  
  H = (sqL*HL + sqR*HR)*fac
  phi = d0_5*(u*u + v*v)
  
  a = sqrt(gami*(H - phi))
  Un = u*nx + v*ny

  lambda1 = Un + dA*a
  lambda2 = Un - dA*a
  lambda3 = Un
  rhoA = abs(Un) + dA*a
  lambda1 = d0_5*(tau*max(abs(lambda1),sat_Vn *rhoA) + sgn*lambda1)
  lambda2 = d0_5*(tau*max(abs(lambda2),sat_Vn *rhoA) + sgn*lambda2)
  lambda3 = d0_5*(tau*max(abs(lambda3),sat_Vl *rhoA) + sgn*lambda3)

  dq1 = q[1] - qg[1] 
  dq2 = q[2] - qg[2]
  dq3 = q[3] - qg[3]
  dq4 = q[4] - qg[4]

  #-- diagonal matrix multiply
  sat = zeros(Float64, 4)
  sat[1] = lambda3*dq1
  sat[2] = lambda3*dq2
  sat[3] = lambda3*dq3
  sat[4] = lambda3*dq4

#   println("sat 1: ",sat)

  #-- get E1*dq
  E1dq[1] = phi*dq1 - u*dq2 - v*dq3 + dq3
  E1dq[2] = E1dq[1]*u
  E1dq[3] = E1dq[1]*v
  E1dq[4] = E1dq[1]*H

  #-- get E2*dq
  E2dq[1] = d0_0
  E2dq[2] = -Un*dq1 + nx*dq2 + ny*dq3
  E2dq[3] = E2dq[2]*ny
  E2dq[4] = E2dq[2]*Un
  E2dq[2] = E2dq[2]*nx

  #-- add to sat
  tmp1 = d0_5*(lambda1 + lambda2) - lambda3
  tmp2 = gami/(a*a)
  tmp3 = d1_0/(dA*dA)
  sat[:] = sat[:] + tmp1*(tmp2*E1dq[:] + tmp3*E2dq[:])
#   println("sat 2: ",sat)
  
  #-- get E3*dq
  E1dq[1] = -Un*dq1 + nx*dq2 + ny*dq3
  E1dq[2] = E1dq[1]*u
  E1dq[3] = E1dq[1]*v
  E1dq[4] = E1dq[1]*H

  #-- get E4*dq
  E2dq[1] = d0_0
  E2dq[2] = phi*dq1 - u*dq2 - v*dq3 + dq4
  E2dq[3] = E2dq[2]*ny
  E2dq[4] = E2dq[2]*Un
  E2dq[2] = E2dq[2]*nx

  #-- add to sat
  tmp1 = d0_5*(lambda1 - lambda2)/(dA*a)
  sat[:] = sat[:] + tmp1*(E1dq[:] + gami*E2dq[:])
#   println("sat 3: ",sat)
  
  returnval = sat + getEulerFlux(q, nx, ny)
#   println("returnval: ", returnval)
  return returnval

end # ends the function eulerRoeSAT

# Euler Roe Solver for boundary integrate
#function isentropicVortexBC{Tmsh, Tsbp, Tsol}(mesh::AbstractMesh{Tmsh}, sbp::SBPOperator{Tsbp}, eqn::EulerEquation{Tsol})
function isentropicVortexBC{T}(q::AbstractArray{T,1}, x::AbstractArray{T,1}, dxidx::AbstractArray{T,2}, nrm::AbstractArray{T,1}, flux::AbstractArray{T, 1}, mesh::AbstractMesh, eqn::EulerEquation)

  E1dq = zeros(Float64, 4)
  E2dq = zeros(Float64, 4)

  # getting qg
  qg = zeros(Float64, 4)
  calcIsentropicVortex(x, eqn, qg)
#  calcVortex(x, eqn, qg)

  # Declaring constants 
  d1_0 = 1.0
  d0_0 = 0.0
  d0_5 = 0.5
  tau = 1.0
  sgn = -1.0
  gamma = 1.4
  gami = gamma - 1
  sat_Vn = 0.025
  sat_Vl = 0.025

  # Begin main executuion
  nx = dxidx[1,1]*nrm[1] + dxidx[2,1]*nrm[2]
  ny = dxidx[1,2]*nrm[1] + dxidx[2,2]*nrm[2]

  dA = sqrt(nx*nx + ny*ny)
  
  fac = d1_0/q[1]
#   println(typeof(fac))
#   println(typeof(q[4]))
  uL = q[2]*fac; vL = q[3]*fac;
  phi = d0_5*(uL*uL + vL*vL)

  HL = gamma*q[4]*fac - gami*phi
  
  fac = d1_0/qg[1]
  uR = qg[2]*fac; vR = qg[3]*fac;
  phi = d0_5*(uR*uR + vR*vR)
  HR = gamma*qg[4]*fac - gami*phi

  sqL = sqrt(q[1]); sqR = sqrt(qg[1])
  fac = d1_0/(sqL + sqR)
  u = (sqL*uL + sqR*uR)*fac
  v = (sqL*vL + sqR*vR)*fac
  
  H = (sqL*HL + sqR*HR)*fac
  phi = d0_5*(u*u + v*v)
  
  a = sqrt(gami*(H - phi))
  Un = u*nx + v*ny

  lambda1 = Un + dA*a
  lambda2 = Un - dA*a
  lambda3 = Un
  rhoA = abs(Un) + dA*a
  lambda1 = d0_5*(tau*max(abs(lambda1),sat_Vn *rhoA) + sgn*lambda1)
  lambda2 = d0_5*(tau*max(abs(lambda2),sat_Vn *rhoA) + sgn*lambda2)
  lambda3 = d0_5*(tau*max(abs(lambda3),sat_Vl *rhoA) + sgn*lambda3)

  dq1 = q[1] - qg[1] 
  dq2 = q[2] - qg[2]
  dq3 = q[3] - qg[3]
  dq4 = q[4] - qg[4]

  #-- diagonal matrix multiply
  sat = zeros(Float64, 4)
  sat[1] = lambda3*dq1
  sat[2] = lambda3*dq2
  sat[3] = lambda3*dq3
  sat[4] = lambda3*dq4

  #-- get E1*dq
  E1dq[1] = phi*dq1 - u*dq2 - v*dq3 + dq4
  E1dq[2] = E1dq[1]*u
  E1dq[3] = E1dq[1]*v
  E1dq[4] = E1dq[1]*H

  #-- get E2*dq
  E2dq[1] = d0_0
  E2dq[2] = -Un*dq1 + nx*dq2 + ny*dq3
  E2dq[3] = E2dq[2]*ny
  E2dq[4] = E2dq[2]*Un
  E2dq[2] = E2dq[2]*nx

  #-- add to sat
  tmp1 = d0_5*(lambda1 + lambda2) - lambda3
  tmp2 = gami/(a*a)
  tmp3 = d1_0/(dA*dA)
  sat[:] = sat[:] + tmp1*(tmp2*E1dq[:] + tmp3*E2dq[:])
  
  #-- get E3*dq
  E1dq[1] = -Un*dq1 + nx*dq2 + ny*dq3
  E1dq[2] = E1dq[1]*u
  E1dq[3] = E1dq[1]*v
  E1dq[4] = E1dq[1]*H

  #-- get E4*dq
  E2dq[1] = d0_0
  E2dq[2] = phi*dq1 - u*dq2 - v*dq3 + dq4
  E2dq[3] = E2dq[2]*ny
  E2dq[4] = E2dq[2]*Un
  E2dq[2] = E2dq[2]*nx

  #-- add to sat
  tmp1 = d0_5*(lambda1 - lambda2)/(dA*a)
  sat[:] = sat[:] + tmp1*(E1dq[:] + gami*E2dq[:])

  euler_flux = zeros(4)
  calcEulerFlux(eqn, q, [nx, ny], euler_flux)

#  flux[:] = sat + getEulerFlux(q, nx, ny, eqn)
  flux[:] = -(sat + euler_flux)
 
#  return sat + getEulerFlux(q, nx, ny)
   return nothing

end # ends the function eulerRoeSAT


function isentropicVortexBC{Tmsh, Tsbp, Tsol}(mesh::AbstractMesh{Tmsh}, sbp::SBPOperator{Tsbp}, eqn::EulerEquation{Tsol})


#function isentropicVortexBC{Tmsh, Tsbp}(mesh::AbstractMesh{Tmsh}, sbp::SBPOperator{Tsbp}, q::AbstractArray, coords::AbstractArray, dxidx::AbstractArray, flux::AbstractArray)


  # q = conserv. vars (vec)
  # x = coords (vec)
  # dxidx = 2x2 matrix
  # nrm = vew(sbp.facenormal, :, bndry.face
  # flux = returned value
  E1dq = zeros(Tsol, 4)
  E2dq = zeros(Tsol, 4)
  sat = zeros(Tsol, 4)

  # getting qg
  qg = zeros(Tsol, 4)
  euler_flux = zeros(Tsol, 4)
#  calcIsentropicVortex(x, eqn, qg)
#  calcVortex(x, eqn, qg)

  # Declaring constants 
  d1_0 = 1.0
  d0_0 = 0.0
  d0_5 = 0.5
  tau = 1.0
  sgn = -1.0
  gamma = 1.4
  gami = gamma - 1
  sat_Vn = 0.025
  sat_Vl = 0.025

  for i=1:mesh.numBoundaryEdges
    bndry_i = mesh.bndryfaces[i]
    for j = 1:sbp.numfacenodes
      k = sbp.facenodes[j, bndry_i.face]

      q = unsafe_view(eqn.q, :, k, bndry_i.element)
      x = unsafe_view(mesh.coords, :, k, bndry_i.element)
      dxidx = unsafe_view(mesh.dxidx, :, :, k, bndry_i.element)
      nrm = unsafe_view(sbp.facenormal, :, bndry_i.face)
      #println("eqn.bndryflux = ", eqn.bndryflux)
      flux = unsafe_view(eqn.bndryflux, :, i, j)

      # Begin main executuion
      # get qg
      calcIsentropicVortex(x, eqn, qg)

      nx = dxidx[1,1]*nrm[1] + dxidx[2,1]*nrm[2]
      ny = dxidx[1,2]*nrm[1] + dxidx[2,2]*nrm[2]

      dA = sqrt(nx*nx + ny*ny)
      
      fac = d1_0/q[1]
    #   println(typeof(fac))
    #   println(typeof(q[4]))
      uL = q[2]*fac; vL = q[3]*fac;
      phi = d0_5*(uL*uL + vL*vL)

      HL = gamma*q[4]*fac - gami*phi
      
      fac = d1_0/qg[1]
      uR = qg[2]*fac; vR = qg[3]*fac;
      phi = d0_5*(uR*uR + vR*vR)
      HR = gamma*qg[4]*fac - gami*phi

      sqL = sqrt(q[1]); sqR = sqrt(qg[1])
      fac = d1_0/(sqL + sqR)
      u = (sqL*uL + sqR*uR)*fac
      v = (sqL*vL + sqR*vR)*fac
      
      H = (sqL*HL + sqR*HR)*fac
      phi = d0_5*(u*u + v*v)
      
      a = sqrt(gami*(H - phi))
      Un = u*nx + v*ny

      lambda1 = Un + dA*a
      lambda2 = Un - dA*a
      lambda3 = Un
      rhoA = abs(Un) + dA*a
      lambda1 = d0_5*(tau*max(abs(lambda1),sat_Vn *rhoA) + sgn*lambda1)
      lambda2 = d0_5*(tau*max(abs(lambda2),sat_Vn *rhoA) + sgn*lambda2)
      lambda3 = d0_5*(tau*max(abs(lambda3),sat_Vl *rhoA) + sgn*lambda3)

      dq1 = q[1] - qg[1] 
      dq2 = q[2] - qg[2]
      dq3 = q[3] - qg[3]
      dq4 = q[4] - qg[4]

      #-- diagonal matrix multiply
      sat[1] = lambda3*dq1
      sat[2] = lambda3*dq2
      sat[3] = lambda3*dq3
      sat[4] = lambda3*dq4

      #-- get E1*dq
      E1dq[1] = phi*dq1 - u*dq2 - v*dq3 + dq4
      E1dq[2] = E1dq[1]*u
      E1dq[3] = E1dq[1]*v
      E1dq[4] = E1dq[1]*H

      #-- get E2*dq
      E2dq[1] = d0_0
      E2dq[2] = -Un*dq1 + nx*dq2 + ny*dq3
      E2dq[3] = E2dq[2]*ny
      E2dq[4] = E2dq[2]*Un
      E2dq[2] = E2dq[2]*nx

      #-- add to sat
      tmp1 = d0_5*(lambda1 + lambda2) - lambda3
      tmp2 = gami/(a*a)
      tmp3 = d1_0/(dA*dA)
      sat[:] = sat[:] + tmp1*(tmp2*E1dq[:] + tmp3*E2dq[:])
      
      #-- get E3*dq
      E1dq[1] = -Un*dq1 + nx*dq2 + ny*dq3
      E1dq[2] = E1dq[1]*u
      E1dq[3] = E1dq[1]*v
      E1dq[4] = E1dq[1]*H

      #-- get E4*dq
      E2dq[1] = d0_0
      E2dq[2] = phi*dq1 - u*dq2 - v*dq3 + dq4
      E2dq[3] = E2dq[2]*ny
      E2dq[4] = E2dq[2]*Un
      E2dq[2] = E2dq[2]*nx

      #-- add to sat
      tmp1 = d0_5*(lambda1 - lambda2)/(dA*a)
      sat[:] = sat[:] + tmp1*(E1dq[:] + gami*E2dq[:])

      calcEulerFlux(eqn, q, [nx, ny], euler_flux)

    #  flux[:] = sat + calcEulerFlux(q, nx, ny, eqn)a
      # make flux negative until boundaryintegrate! supports -=
      flux = -(sat + euler_flux)
    end
  end
     
    #  return sat + getEulerFlux(q, nx, ny)
       return nothing

end # ends the function eulerRoeSAT

