#using ArrayViews
# using input_vals_channel.jl

"""
  This function tests whether the mesh counted the number of mesh entities
  is correct.  It also checks the coordinates and mapping jacobian, which
  means it is dependent on the element ordering
"""
function test_lowlevel_mesh(mesh, sbp, eqn, opts)
  facts("--- Testing Mesh --- ") do

    @fact mesh.numVert --> 4
    @fact mesh.numEdge --> 5
    @fact mesh.numEl --> 2
    @fact mesh.order --> 1
    @fact mesh.numDof --> 16
    @fact mesh.numNodes --> 4
    @fact mesh.numDofPerNode --> 4
    @fact mesh.numBoundaryFaces --> 4
    @fact mesh.numInterfaces --> 1
    @fact mesh.numNodesPerElement --> 3
    @fact mesh.numNodesPerType --> [1, 0 , 0]

    @fact mesh.bndry_funcs[1] --> EulerEquationMod.Rho1E2U3BC()
    println("bndryfaces = ", mesh.bndryfaces)
    @fact mesh.bndryfaces[1].element --> 1
    @fact mesh.bndryfaces[1].face --> 3
    @fact mesh.bndryfaces[2].element --> 2
    @fact mesh.bndryfaces[2].face --> 1
    @fact mesh.bndryfaces[3].element --> 1
    @fact mesh.bndryfaces[3].face --> 2
    @fact mesh.bndryfaces[4].element --> 2
    @fact mesh.bndryfaces[4].face --> 2

    println("mesh.interfaces = ",  mesh.interfaces)
    @fact mesh.interfaces[1].elementL --> 1
    @fact mesh.interfaces[1].elementR --> 2
    @fact mesh.interfaces[1].faceL --> 1
    @fact mesh.interfaces[1].faceR --> 3


  #=
    @fact mesh.bndryfaces[1].element --> 1
    @fact mesh.bndryfaces[1].face --> 2
    @fact mesh.bndryfaces[2].element --> 2
    @fact mesh.bndryfaces[2].face --> 2
    @fact mesh.bndryfaces[3].element --> 1
    @fact mesh.bndryfaces[3].face --> 1
    @fact mesh.bndryfaces[4].element --> 2
    @fact mesh.bndryfaces[4].face --> 3

    @fact mesh.interfaces[1].elementL --> 2
    @fact mesh.interfaces[1].elementR --> 1
    @fact mesh.interfaces[1].faceL --> 1
    @fact mesh.interfaces[1].faceR --> 3
  =#
    @fact mesh.coords[:, :, 2] --> roughly([-1.0 1 1; -1 -1 1])
    @fact mesh.coords[:, :, 1] --> roughly([-1.0 1 -1; -1 1 1])

    @fact mesh.dxidx[:, :, 1, 2] --> roughly([1.0 -1; 0 1], atol=1e-14)

    @fact mesh.dxidx[:, :, 1, 2] --> roughly([1.0 -1; 0 1], atol=1e-14)
    @fact mesh.dxidx[:, :, 2, 2] --> roughly([1.0 -1; 0 1], atol=1e-14)
    @fact mesh.dxidx[:, :, 3, 2] --> roughly([1.0 -1; 0 1], atol=1e-14)

    @fact mesh.dxidx[:, :, 1, 1] --> roughly([1.0 0; -1 1], atol=1e-14)
    @fact mesh.dxidx[:, :, 2, 1] --> roughly([1.0 0; -1 1], atol=1e-14)
    @fact mesh.dxidx[:, :, 3, 1] --> roughly([1.0 0; -1 1], atol=1e-14)

    @fact mesh.jac --> roughly(ones(3,2))


  end
end # end function

#test_lowlevel_mesh(mesh, sbp, eqn, opts)
add_func2!(EulerTests, test_lowlevel_mesh, "input_vals_channel.jl")

"""
  This function tests calculation of quantities needed for using the
  entropy variables: conversion, A0, A1

"""
function test_lowlevel_entropyvars(mesh, sbp, eqn, opts)

  Tsol = eltype(eqn.q)
  Tres = eltype(eqn.res)
  Tmsh = eltype(mesh.dxidx)
  facts("--- Testing Euler Low Level Functions --- ") do
    opts["variable_type"] = :entropy
    eqn_e = EulerData_{Tsol, Tres, 2, Tmsh, opts["variable_type"]}(mesh, sbp, opts)

    e_params = eqn_e.params
    opts["variable_type"] = :conservative

    q = [1.0, 2.0, 3.0, 7.0]
    qg = deepcopy(q)
    aux_vars = [EulerEquationMod.calcPressure(eqn.params, q)]
    dxidx = mesh.dxidx[:, :, 1, 1]  # arbitrary
    dir = [1.0, 0.0]
    F = zeros(4)
    Fe = zeros(4)
    coords = [1.0,  0.0]

    flux_parametric = zeros(4,2)

    v = zeros(4)
    EulerEquationMod.convertToEntropy(eqn.params, q, v)
    v_analytic = [-2*4.99528104378295, 4., 6, -2*1]
    @fact v --> roughly(v_analytic)
    # test inplace operation
    q2 = copy(q)
    EulerEquationMod.convertToEntropy(eqn.params, q2, q2)
    @fact q2 --> v_analytic
    println("v = ", v)
    q_ret = zeros(4)
    EulerEquationMod.convertToConservative(e_params, v, q_ret)
    @fact q_ret --> roughly(q)
    
    # test inplace operation
    v2 = copy(v)
    EulerEquationMod.convertToConservative(e_params, v2, v2)
    @fact v2 --> roughly(q)

    v = zeros(4)
    vIR = zeros(4)
    EulerEquationMod.convertToEntropy(eqn.params, q, v)
    v_analytic = [-2*4.99528104378295, 4., 6, -2*1]
    @fact v --> roughly(v_analytic)
    # test inplace operation
    q2 = copy(q)
    EulerEquationMod.convertToEntropy(eqn.params, q2, q2)
    @fact q2 --> v_analytic

    # test IR variables
    EulerEquationMod.convertToIR(eqn.params, q, vIR)
    println("vIR = ", vIR)
    println("q2./params.gamma_1 = ", q2./eqn.params.gamma_1)
    diff = vIR - q2./eqn.params.gamma_1
    println("diff = ", diff)
    @fact norm(diff) --> roughly(0.0, atol=1e-12)

    # test inplace operation
    vIR2 = copy(q)
    EulerEquationMod.convertToIR(eqn.params, vIR2, vIR2)
    diff = vIR2 - q2./eqn.params.gamma_1
    @fact norm(diff) --> roughly(0.0, atol=1e-12)

    # convert back
    EulerEquationMod.convertToConservativeFromIR_(eqn.params, vIR2, vIR2)
    diff = q - vIR2
    @fact norm(diff) --> roughly(0.0, atol=1e-12)

    q_ret = zeros(4)
    EulerEquationMod.convertToConservative(e_params, v, q_ret)
    @fact q_ret --> roughly(q)
    
    # test inplace operation
    v2 = copy(v)
    EulerEquationMod.convertToConservative(e_params, v2, v2)
    @fact v2 --> roughly(q)


    # ------------------------------------------------------------------------
    # test matrices

    # test inv(A0)
    A0inv = zeros(4,4)
    A0inv2 = [170.4 -52 -78 24; 
              -52 18 24 -8; 
              -78 24 38 -12; 
              24 -8  -12 4]
    EulerEquationMod.calcA0Inv(e_params, v, A0inv)

    @fact A0inv --> roughly(A0inv2)

    # test A0
    A0 = zeros(4,4)
    A02 = inv(A0inv)
    EulerEquationMod.calcA0(e_params, v, A0)
   
    for i=1:16
      @fact A0[i] --> roughly(A02[i], atol=1e-10)
    end


    A0inv_c = zeros(4,4)
    EulerEquationMod.calcA0(eqn.params, q, A0inv_c)
    @fact A0inv_c --> eye(4)

    A0_c = zeros(4,4)
    EulerEquationMod.calcA0Inv(eqn.params, q, A0_c)
    @fact A0_c --> eye(4)

   # test calcIRA0
   A03 = scale(A0, eqn.params.gamma_1)
   A04_test = zeros(A02)
   A04_code = zeros(A02)
   EulerEquationMod.getIRA0(eqn.params, q, A04_code)
   q3 = zeros(Complex128, length(q))
   q4 = zeros(Complex128, length(q))

   q3[:] = q
   EulerEquationMod.convertToEntropy_(eqn.params, q3, q4)
   for i=1:length(q)
     h = 1e-20
     q4[i] += complex(0, h)
     EulerEquationMod.convertToConservative_(eqn.params, q4, q3)
     A04_test[:, i] = imag(q3)/h
     q4[i] -= complex(0, h)
   end
   scale!(A04_test, eqn.params.gamma_1)

   for i=1:length(A04_test)
     @fact A04_code[i] --> roughly(A04_test[i], atol=1e-13)
     @fact A04_code[i] --> roughly(A03[i], atol=1e-10)
   end


      # test A1
    A1 = zeros(4,4)
    q_tmp = ones(Tsol, 4)
    EulerEquationMod.calcA1(eqn.params, q_tmp, A1)
    @fact A1 --> roughly([0.0 1.0 0.0  0.0
                          -0.6 1.6 -0.4 0.4
                          -1.0 1.0 1.0 0.0
                          -0.6 0.6 -0.4 1.4])


    EulerEquationMod.calcA1(e_params, v, A1)
    fac = 0.3125
    A1_analytic = fac*[16 33.6 48 115.2;
                            33.6 73.6 100.8 248.32; 
                            48 100.8 147.2 355.2;
                            115.2 248.32 355.2 4*218.32]

    A1_diff = A1 - A1_analytic
    for i=1:16
      @fact A1[i] --> roughly(A1_analytic[i], atol=1e-10)
    end

    A2 = zeros(4,4)
    A2 = zeros(4,4)
    EulerEquationMod.calcA2(eqn.params, q_tmp, A2)
    @fact A2 --> roughly([0.0 0.0 1.0 0.0
                        -1.0 1.0 1.0 0.0
                        -0.6 -0.4 1.6 0.4
                        -0.6 -0.4 0.6 1.4])



    EulerEquationMod.calcA2(e_params, v, A2)
    A2_analytic = fac*[24. 48 73.6 172.8;
                            48 100.8 147.2 355.2; 
                            73.6 147.2 230.4 544.32;
                            172.8 355.2 544.32 1309.92]
    A2_diff = A2 - A2_analytic

    for i=1:16
      @fact A2[i] --> roughly(A2_analytic[i], atol=1e-10)
    end


    # check that checkDensity and checkPresure work
    @fact_throws EulerEquationMod.checkDensity(eqn)
    @fact_throws EulerEquationMod.checkPressure(eqn)

  end  # end facts block

  return nothing
end  # end function

#test_lowlevel_entropyvars(mesh, sbp, eqn, opts)
add_func2!(EulerTests, test_lowlevel_entropyvars, "input_vals_channel.jl", [TAG_ENTROPYVARS])

"""
  This function tests functions that are used to convert entire vectors/arrays
  of values between conservative and entropy variables
"""
function test_lowlevel_convert(mesh, sbp, eqn, opts)
  Tsol = eltype(eqn.q)
  Tres = eltype(eqn.res)
  Tmsh = eltype(mesh.dxidx)
  opts["variable_type"] = :entropy
  eqn_e = EulerData_{Tsol, Tres, 2, Tmsh, opts["variable_type"]}(mesh, sbp, opts)

  e_params = eqn_e.params
  opts["variable_type"] = :conservative
  #=
  q = [1.0, 2.0, 3.0, 7.0]
  qg = deepcopy(q)
  aux_vars = [EulerEquationMod.calcPressure(eqn.params, q)]
  dxidx = mesh.dxidx[:, :, 1, 1]  # arbitrary
  dir = [1.0, 0.0]
  F = zeros(4)
  Fe = zeros(4)
  coords = [1.0,  0.0]
  =#

  A0 = zeros(4,4)
  A0inv = zeros(4,4)

  facts("--- Testing convert Functions ---") do
    # for the case, the solution is uniform flow
    eqn.disassembleSolution(mesh, sbp, eqn, opts, eqn.q, eqn.q_vec)
    v_arr = copy(eqn.q)
    v2 = zeros(4)

    EulerEquationMod.convertToEntropy(eqn.params, eqn.q[:, 1, 1], v2)
    EulerEquationMod.convertToEntropy(mesh, sbp, eqn, opts, v_arr)
    # test conversion to entropy variables
    for i=1:mesh.numEl
      for j=1:mesh.numNodesPerElement
        @fact v_arr[:, j, i] --> v2
      end
    end

    eqn_e.q = v_arr # attach entropy variables to eqn_e

    v_vec = copy(eqn.q_vec)
    EulerEquationMod.convertToEntropy(mesh, sbp, eqn, opts, v_vec)
    for i=1:4:mesh.numDof
      @fact v_vec[i:(i+3)] --> v2
    end

    eqn_e.q_vec = v_vec
    v_arr2 = copy(v_arr)

    # test multiplying an entire array by A0inv
    EulerEquationMod.calcA0Inv(e_params, v_arr2[:, 1, 1], A0inv)
    v2 = A0inv*v_arr2[:, 1, 1]
    EulerEquationMod.matVecA0inv(mesh, sbp, eqn_e, opts, v_arr2)
    for i=1:mesh.numEl
      for j=1:mesh.numNodesPerElement
        @fact v_arr2[:, j, i] --> roughly(v2)
      end
    end

    v_arr3 = copy(v_arr)

    EulerEquationMod.calcA0(e_params, v_arr3[:, 1, 1], A0)
    v3 = A0*v_arr3[:, 1, 1]  # store original values
    EulerEquationMod.matVecA0(mesh, sbp, eqn_e, opts, v_arr3)
    for i=1:mesh.numEl
      for j=1:mesh.numNodesPerElement
        @fact v_arr3[:, j, i] --> roughly(v3)
      end
    end

    # now test converting back to conservative
    EulerEquationMod.convertToConservative(mesh, sbp, eqn_e, opts, v_arr)
    for i =1:mesh.numEl
      for j=1:mesh.numNodesPerElement
        @fact v_arr[:, j, i] --> roughly(eqn.q[:, j, i])
      end
    end

    EulerEquationMod.convertToConservative(mesh, sbp, eqn_e, opts, v_vec)
    for i=1:mesh.numDof
      @fact v_vec[i] --> roughly(eqn.q_vec[i])
    end



  end  # end facts block

  return nothing
end
     
#test_lowlevel_convert(mesh, sbp, eqn, opts)
add_func2!(EulerTests, test_lowlevel_convert, "input_vals_channel.jl", [TAG_ENTROPYVARS])



function test_lowlevel_eigsystem(mesh, sbp, eqn, opts)


  facts("--- Testing Eigensystem ---") do
    # compute flux jacobian in x and y directions
    params = eqn.params
    q = [1.0, 2.0, 3.0, 7.0]
    qc = convert(Array{Complex128}, q)
    aux_vars = Array(Complex128, 1)
    qg = deepcopy(q)
    dxidx = mesh.dxidx[:, :, 1, 1]  # arbitrary
    F = zeros(Complex128, 4)

    Ax = zeros(4,4)
    Ax3 = zeros(Ax)
    Ay = zeros(4,4)
    Ay3 = zeros(Ay)

    EulerEquationMod.calcA(params, q, Ax3)
    EulerEquationMod.calcB(params, q, Ay3)
    h = 1e-20
    pert = Complex128(0, h)
    for i=1:4
      qc[i] += pert
      dir = [1.0, 0.0]
      p = EulerEquationMod.calcPressure(params, qc)
      aux_vars[1] = p
      EulerEquationMod.calcEulerFlux(params, qc, aux_vars, dir, F)
      Ax[:, i] = imag(F)/h

      dir = [0.0, 1.0]
      EulerEquationMod.calcEulerFlux(params, qc, aux_vars, dir, F)
      Ay[:, i] = imag(F)/h

      qc[i] -= pert
    end

    println("Ax = \n", Ax)
    println("Ax3 = \n", Ax3)
    println("diff = \n", Ax - Ax3)

    # now compute Ax and and Ay from their eigensystem and compare
    Yx = zeros(4,4)
    Yy = zeros(4,4)
    Lambdax = zeros(4)
    Lambday = zeros(4)

    EulerEquationMod.calcEvecsx(params, q, Yx)
    EulerEquationMod.calcEvecsy(params, q, Yy)
    EulerEquationMod.calcEvalsx(params, q, Lambdax)
    EulerEquationMod.calcEvalsy(params, q, Lambday)

    Ax2 = Yx*diagm(Lambdax)*inv(Yx)
    Ay2 = Yy*diagm(Lambday)*inv(Yy)

    @fact Ax2 --> roughly(Ax, atol=1e-12)
    @fact Ay2 --> roughly(Ay, atol=1e-12)
    @fact Ax3 --> roughly(Ax, atol=1e-12)
    @fact Ay3 --> roughly(Ay, atol=1e-12)

    # check A0 = Y*S2*Y.'
    A0 = zeros(4,4)
    Sx = zeros(4)
    Sy = zeros(4)

    EulerEquationMod.getIRA0(params, q, A0)
    EulerEquationMod.calcEScalingx(params, q, Sx)
    EulerEquationMod.calcEScalingy(params, q, Sy)
    A02 = Yx*diagm(Sx)*Yx.'
    A03 = Yy*diagm(Sy)*Yy.'

    @fact A0 --> roughly(A02, atol=1e-12)
    @fact A0 --> roughly(A03, atol=1e-12) 

  end  # end facts block

  return nothing
end  # end function

#test_lowlevel_eigsystem()

add_func2!(EulerTests, test_lowlevel_eigsystem, "input_vals_channel.jl")


"""
  This function tests calculation of dependent quantities: pressure, speed of
  sound, Euler flux.
"""
function test_lowlevel_calc(mesh, sbp, eqn, opts)
    Tsol = eltype(eqn.q)
    Tres = eltype(eqn.res)
    Tmsh = eltype(mesh.dxidx)

   opts["variable_type"] = :entropy
   eqn_e = EulerData_{Tsol, Tres, 2, Tmsh, opts["variable_type"]}(mesh, sbp, opts)

   e_params = eqn_e.params
   opts["variable_type"] = :conservative
   
   q = [1.0, 2.0, 3.0, 7.0]
   v = zeros(q)
   EulerEquationMod.convertToEntropy(eqn.params, q, v)


  facts("--- Testing calc functions ---") do

    @fact EulerEquationMod.calcPressure(eqn.params, q) --> roughly(0.2)
    @fact EulerEquationMod.calcPressure(e_params, v) --> roughly(0.2)
    a_cons = EulerEquationMod.calcSpeedofSound(eqn.params, q)
    a_ent = EulerEquationMod.calcSpeedofSound(e_params, v)
    println("a_cosn = ", a_cons)
    println("a_ent = ", a_ent)
    @fact a_cons --> roughly(a_ent)
    EulerEquationMod.calcEulerFlux(eqn.params, q, aux_vars, dir, F)
    EulerEquationMod.calcEulerFlux(e_params, v, aux_vars, dir, Fe)
    @fact F --> roughly([2.0, 4.2, 6, 14.4], atol=1e-14)
    @fact Fe --> roughly(F)
  end

  return nothing
end

#test_lowlevel_convert(mesh, sbp, eqn, opts)
add_func2!(EulerTests, test_lowlevel_convert, "input_vals_channel.jl", [TAG_ENTROPYVARS])

"""
  Ths function tests calculation of boundary conditions and the Roe solver.
"""
function test_lowlevel_boundary(mesh, sbp, eqn, opts)

  q = [1.0, 2.0, 3.0, 7.0]
  qg = deepcopy(q)
  aux_vars = [EulerEquationMod.calcPressure(eqn.params, q)]
  dxidx = mesh.dxidx[:, :, 1, 1]  # arbitrary
  dir = [1.0, 0.0]
  F = zeros(4)
  Fe = zeros(4)
  coords = [1.0,  0.0]

  flux_parametric = zeros(4,2)

  v = zeros(4)
  EulerEquationMod.convertToEntropy(eqn.params, q, v)

  facts("--- Testing Boundary Function ---") do
#   println("q = ", q)

    nx = dxidx[1,1]*dir[1] + dxidx[2,1]*dir[2]
    ny = dxidx[1,2]*dir[1] + dxidx[2,2]*dir[2]
    nrm = [nx, ny]

    EulerEquationMod.calcEulerFlux(eqn.params, q, aux_vars, nrm, F)

    # calc Euler fluxs needed by Roe solver
    F_roe = zeros(4)

    nrm1 = [dxidx[1,1], dxidx[1,2]]
    EulerEquationMod.calcEulerFlux(eqn.params, q, aux_vars, nrm1, sview(flux_parametric, :, 1))
    nrm2 = [dxidx[2,1], dxidx[2,2]]
    EulerEquationMod.calcEulerFlux(eqn.params, q, aux_vars, nrm2, sview(flux_parametric, :, 2))

    EulerEquationMod.RoeSolver(eqn.params, q, qg, aux_vars, dxidx, dir, F_roe)
     println("roe 1")
    @fact F_roe --> roughly(F) 


    # test that roe flux = euler flux of BC functions
    EulerEquationMod.calcIsentropicVortex(coords, eqn.params, q)

    nrm1 = [dxidx[1,1], dxidx[1,2]]
    EulerEquationMod.calcEulerFlux(eqn.params, q, aux_vars, nrm1, sview(flux_parametric, :, 1))
    nrm2 = [dxidx[2,1], dxidx[2,2]]
    EulerEquationMod.calcEulerFlux(eqn.params, q, aux_vars, nrm2, sview(flux_parametric, :, 2))


     println("q = ", q)
    func1 = EulerEquationMod.isentropicVortexBC()
    EulerEquationMod.calcEulerFlux(eqn.params, q, aux_vars, nrm, F)
    func1(q, aux_vars, coords, dxidx, dir, F_roe, eqn.params)

     println("roe 2")
    @fact F_roe --> roughly(F) 

    q[3] = 0  # make flow parallel to wall
    func1 = EulerEquationMod.noPenetrationBC()
    nrm1 = [dxidx[1,1], dxidx[1,2]]
    EulerEquationMod.calcEulerFlux(eqn.params, q, aux_vars, nrm1, sview(flux_parametric, :, 1))
    nrm2 = [dxidx[2,1], dxidx[2,2]]
    EulerEquationMod.calcEulerFlux(eqn.params, q, aux_vars, nrm2, sview(flux_parametric, :, 2))


    EulerEquationMod.calcEulerFlux(eqn.params, q, aux_vars, nrm, F)
    func1(q, aux_vars, coords, dxidx, dir, F_roe, eqn.params)

     println("roe 3")
    @fact F_roe --> roughly(F) 

    EulerEquationMod.calcRho1Energy2U3(coords, eqn.params, q)
    func1 = EulerEquationMod.Rho1E2U3BC()
    nrm1 = [dxidx[1,1], dxidx[1,2]]
    EulerEquationMod.calcEulerFlux(eqn.params, q, aux_vars, nrm1, sview(flux_parametric, :, 1))
    nrm2 = [dxidx[2,1], dxidx[2,2]]
    EulerEquationMod.calcEulerFlux(eqn.params, q, aux_vars, nrm2, sview(flux_parametric, :, 2))


    EulerEquationMod.calcEulerFlux(eqn.params, q, aux_vars, nrm, F)
    func1(q, aux_vars, coords, dxidx, dir, F_roe, eqn.params)

    @fact F_roe --> roughly(F) 
  end  # end facts block

  return nothing
end

#test_lowlevel_boundary(mesh, sbp, eqn, opts)
add_func2!(EulerTests, test_lowlevel_boundary, "input_vals_channel.jl", [TAG_BC, TAG_FLUX])


"""
  This function tests things in commonfuncs.jl
"""
function test_lowlevel_commonfuncs(mesh, sbp, eqn, opts)

  coords = [1.0,  0.0]

  facts("--- Testing common functions ---") do

    F = zeros(4)
    EulerEquationMod.calcRho1Energy2(coords, eqn.params, F)
    @fact F[1] --> 1.0
    @fact F[4] --> 2.0

    fill!(F, 0.0)
    EulerEquationMod.calcRho1Energy2U3(coords, eqn.params, F)
    @fact F[1] --> roughly(1.0, atol=1e-4)
    @fact F[2] --> roughly(0.35355, atol=1e-4)
    @fact F[3] --> roughly(0.35355, atol=1e-4)
    @fact F[4] --> roughly(2.0, atol=1e-4)

    fill!(F, 0.0)
    EulerEquationMod.calcIsentropicVortex(coords, eqn.params, F)
    @fact F[1] --> roughly(2.000, atol=1e-4)
    @fact F[2] --> roughly(0.000, atol=1e-4)
    @fact F[3] --> roughly(-1.3435, atol=1e-4)
    @fact F[4] --> roughly(2.236960, atol=1e-4)


    level = EulerEquationMod.getPascalLevel(1)
    @fact level --> 1

    for i=2:3
      level = EulerEquationMod.getPascalLevel(i)
      @fact level --> 2
    end

    for i=4:6
      level = EulerEquationMod.getPascalLevel(i)
      @fact level --> 3
    end

    for i=7:10
      level = EulerEquationMod.getPascalLevel(i)
      @fact level --> 4
    end

    for i=11:15
      level = EulerEquationMod.getPascalLevel(i)
      @fact level --> 5
    end
  end  # end facts block
  
  return nothing
end

#test_lowlevel_commonfuncs(mesh, sbp, eqn, opts)
add_func2!(EulerTests, test_lowlevel_commonfuncs, "input_vals_channel.jl")

"""
  This functinon tests dataprep and some auxiliary functions
"""
function test_lowlevel_dataprep(mesh, sbp, eqn, opts)

  facts("--- Testing dataPrep ---") do
 
    # the input file loaded a uniform flow into q_vev
    EulerEquationMod.disassembleSolution(mesh, sbp, eqn, opts, eqn.q, eqn.q_vec)
    EulerEquationMod.dataPrep(mesh, sbp, eqn, opts)
    # test disassembleSolution
    for i=1:mesh.numEl
      for j=1:mesh.numNodesPerElement
        @fact eqn.q[:, j, i] --> roughly([1.0, 0.35355, 0.35355, 2.0], atol=1e-5)
      end
    end

    # testing arrToVecAssign
    q_vec_orig = copy(eqn.q_vec)
    EulerEquationMod.arrToVecAssign(mesh, sbp, eqn, opts, eqn.q, eqn.q_vec)
    for i = 1:mesh.numDof
      @fact eqn.q_vec[i] --> roughly(q_vec_orig[i], atol=1e-5)
    end


    #=
    for i=1:mesh.numEl
      println("i = ", i)
      for j=1:mesh.numNodesPerElement
        println("j = ", j)
        aux_vars_i = eqn.aux_vars[ :, j, i]
        println("aux_vars_i = ", aux_vars_i)
        p = EulerEquationMod.@getPressure(aux_vars_i)
        @fact p --> roughly(0.750001, atol=1e-5)
      end
    end
    =#

    # test calcEulerFlux
    for i=1:mesh.numNodesPerElement
       println("eq.flux_parametric[:, $i, 1, 1] = ", eqn.flux_parametric[:, i, 1, 1])
      @fact eqn.flux_parametric[:, i, 1, 2] --> roughly([0.0, -0.750001, 0.750001, 0.0], atol=1e-5)
    end

    for i=1:mesh.numNodesPerElement
      @fact eqn.flux_parametric[:, i, 2, 2] --> roughly([0.35355,  0.12499, 0.874999 ,0.972263], atol=1e-5)
    end

    for i=1:mesh.numNodesPerElement
      @fact eqn.flux_parametric[:, i, 1, 1] --> roughly([0.35355,  0.874999, 00.124998,.972263], atol=1e-5)
    end

    for i=1:mesh.numNodesPerElement
      @fact eqn.flux_parametric[:, i, 2, 1] --> roughly([0.0, 0.750001, -0.750001, 0.0], atol=1e-5)
    end


    # test getBCFluxes
    for j= 1:sbp.numfacenodes
      @fact eqn.bndryflux[:, j, 1] --> roughly([-0.35355, -0.874999, -0.124998, -0.972263], atol=1e-5)
    end

    for j= 1:sbp.numfacenodes
      @fact eqn.bndryflux[:, j, 2] --> roughly([-0.35355,  -0.124998, -0.874999, -0.972263], atol=1e-5)
    end

    for j= 1:sbp.numfacenodes
      @fact eqn.bndryflux[:, j, 3] --> roughly([0.35355,  0.124998, 0.874999, 0.972263], atol=1e-5)
    end

    for j= 1:sbp.numfacenodes
      @fact eqn.bndryflux[:, j, 4] --> roughly([0.35355, 0.874999, 0.124998, 0.972263], atol=1e-5)
    end
  end  # end facts block

  return nothing
end

#test_lowlevel_dataprep(mesh, sbp, eqn, opts)
add_func2!(EulerTests, test_lowlevel_dataprep, "input_vals_channel.jl", [TAG_FLUX])

"""
  This function tests evaluating volume and boundary integrals over the
  entire mesh.
"""
function test_lowlevel_integrals(mesh, sbp, eqn, opts)

  facts("--- Testing evalVolumeIntegrals ---")  do

    EulerEquationMod.evalVolumeIntegrals(mesh, sbp, eqn, opts)

    el1_res = [-0.35355  0  0.35355;
                -0.874999  0.750001  0.124998;
		-0.124998  -0.750001  0.874999;
		-0.972263  0  0.972263]
    el2_res = [-0.35355  0.35355 0;
                -0.124998  0.874999 -0.75001;
		-0.874999 0.124998 0.75001;
		-0.972263  0.972263 0]
 
    @fact eqn.res[:, :, 2] --> roughly(el1_res, atol=1e-4)
    @fact eqn.res[:, :, 1] --> roughly(el2_res, atol=1e-4)

  end  # end facts block


  facts("--- Testing evalBoundaryIntegrals ---") do
    fill!(eqn.res, 0.0)

    EulerEquationMod.evalBoundaryIntegrals( mesh, sbp, eqn)

    el1_res = [0.35355 0 -0.35355;
               0.124998 -0.750001 -0.874999;
	       0.874999 0.750001 -0.124998;
	       0.972263  0  -0.972263]
    el2_res = [0.35355 -0.35355 0;
               0.874999 -0.124998 0.750001;
	       0.124998  -0.874999  -0.750001;
	       0.972263  -0.972263  0]

    @fact eqn.res[:, :, 2] --> roughly(el1_res, atol=1e-5)
    @fact eqn.res[:, :, 1] --> roughly(el2_res, atol=1e-5)

  end  # end facts block

  facts("--- Testing evalEuler --- ")  do

    fill!(eqn.res_vec, 0.0)
    fill!(eqn.res, 0.0)
    EulerEquationMod.evalEuler(mesh, sbp, eqn, opts)

    # for uniform flow, residual is zero
    for i=1:mesh.numDof
      @fact eqn.res_vec[i] --> roughly(0.0, atol=1e-14)
    end

  end  # end facts block


#  context("--- Testing NonlinearSolvers --- ") do
#    jac = SparseMatrixCSC(mesh.sparsity_bnds, eltype(eqn.res_vec))
#
#  end

  return nothing
end

#test_lowlevel_integrals(mesh, sbp, eqn, opts)
add_func2!(EulerTests, test_lowlevel_integrals, "input_vals_channel.jl", [TAG_BC, TAG_FLUX])
