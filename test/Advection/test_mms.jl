
#=
push!(LOAD_PATH, joinpath(Pkg.dir("PumiInterface"), "src"))
push!(LOAD_PATH, joinpath(Pkg.dir("PDESolver"), "src/solver/advection"))
push!(LOAD_PATH, joinpath(Pkg.dir("PDESolver"), "src/NonlinearSolvers"))

using PDESolver
#using Base.Test
using FactCheck
using ODLCommonTools
using PdePumiInterface  # common mesh interface - pumi
using SummationByParts  # SBP operators
using AdvectionEquationMod
using ForwardDiff
using NonlinearSolvers   # non-linear solvers
using ArrayViews

global const STARTUP_PATH = joinpath(Pkg.dir("PDESolver"), "src/solver/advection/startup_advection.jl")
=#

function make_input_mms(degree; dg=false, operator="SBPOmega")
  arg_dict["order"] = degree
  arg_dict["IC_name"] = "ICp$degree"
  arg_dict["BC1_name"] = string("p", degree, "BC")
  arg_dict["SRCname"] = "SRCp$degree"
  arg_dict["operator_type"] = operator

  if dg
    arg_dict["use_DG"] = true
    arg_dict["Flux_name"] = "LFFlux"
  else
    arg_dict["use_DG"] = false
  end

  fname = "input_vals_mms$degree.jl"
  rmfile(fname)
  f = open(fname, "w")
  print(f, "arg_dict = ")
  println(f, arg_dict)
  ARGS[1] = fname
  return fname
end

"""
  Test manufactured solutions, including cases that should be exact, for both
  gamma and omega operators.
"""
function test_mms()
  facts("----- Testing using manufactured polynomials -----") do

    println("  -----testing degree 1 polynomial -----")
    resize!(ARGS, 1)
    #TODO: uncomment when SBP is fixed
    
    ARGS[1] = "input_vals_mms.jl"
    include(STARTUP_PATH)
    #=
    fill!(eqn.res, 0.0)
    eqn.disassembleSolution(mesh, sbp, eqn, opts, eqn.q, eqn.q_vec)
    println("eqn.q_vec = ", eqn.q_vec)
    AdvectionEquationMod.evalAdvection(mesh, sbp, eqn, opts)
    eqn.assembleSolution(mesh, sbp, eqn, opts, eqn.res, eqn.res_vec)
    @fact eqn.res_vec --> roughly(zeros(mesh.numDof), atol=1e-12)
    =#
    println("testing DG")

    ARGS[1] = "input_vals_mms1.jl"
    fname = make_input_mms(1, dg=true)
    include(STARTUP_PATH)
    fill!(eqn.res, 0.0)
    eqn.disassembleSolution(mesh, sbp, eqn, opts, eqn.q, eqn.q_vec)
    AdvectionEquationMod.evalAdvection(mesh, sbp, eqn, opts)
    eqn.assembleSolution(mesh, sbp, eqn, opts, eqn.res, eqn.res_vec)
    @fact eqn.res_vec --> roughly(zeros(mesh.numDof), atol=1e-12)
    println("p1 dg test finished")

    fname = make_input_mms(1, dg=true, operator="SBPOmega")
    include(STARTUP_PATH)
    fill!(eqn.res, 0.0)
    eqn.disassembleSolution(mesh, sbp, eqn, opts, eqn.q, eqn.q_vec)
    AdvectionEquationMod.evalAdvection(mesh, sbp, eqn, opts)
    eqn.assembleSolution(mesh, sbp, eqn, opts, eqn.res, eqn.res_vec)
    @fact eqn.res_vec --> roughly(zeros(mesh.numDof), atol=1e-12)
    println("p1 dg test finished")

    println("  -----testing degree 2 polynomial -----")
    #=
    fname = make_input_mms(2)
    ARGS[1] = fname
    include(STARTUP_PATH)
    fill!(eqn.res, 0.0)
    eqn.disassembleSolution(mesh, sbp, eqn, opts, eqn.q, eqn.q_vec)
    AdvectionEquationMod.evalAdvection(mesh, sbp, eqn, opts)
    eqn.assembleSolution(mesh, sbp, eqn, opts, eqn.res, eqn.res_vec)
    @fact eqn.res_vec --> roughly(zeros(mesh.numDof), atol=1e-12)
    =#
    fname = make_input_mms(2, dg=true)
    include(STARTUP_PATH)
    fill!(eqn.res, 0.0)
    eqn.disassembleSolution(mesh, sbp, eqn, opts, eqn.q, eqn.q_vec)
    AdvectionEquationMod.evalAdvection(mesh, sbp, eqn, opts)
    eqn.assembleSolution(mesh, sbp, eqn, opts, eqn.res, eqn.res_vec)
    @fact eqn.res_vec --> roughly(zeros(mesh.numDof), atol=1e-12)



    println("  -----testing degree 3 polynomial -----")
    #=
    fname = make_input_mms(3)
    ARGS[1] = fname
    include(STARTUP_PATH)
    fill!(eqn.res, 0.0)
    eqn.disassembleSolution(mesh, sbp, eqn, opts, eqn.q, eqn.q_vec)
    AdvectionEquationMod.evalAdvection(mesh, sbp, eqn, opts)
    eqn.assembleSolution(mesh, sbp, eqn, opts, eqn.res, eqn.res_vec)
    @fact eqn.res_vec --> roughly(zeros(mesh.numDof), atol=1e-12)
    =#
    fname = make_input_mms(3, dg=true)
    include(STARTUP_PATH)
    fill!(eqn.res, 0.0)
    eqn.disassembleSolution(mesh, sbp, eqn, opts, eqn.q, eqn.q_vec)
    AdvectionEquationMod.evalAdvection(mesh, sbp, eqn, opts)
    eqn.assembleSolution(mesh, sbp, eqn, opts, eqn.res, eqn.res_vec)
    @fact eqn.res_vec --> roughly(zeros(mesh.numDof), atol=1e-12)



    println("  -----testing degree 4 polynomial -----")
    #=
    fname = make_input_mms(4)
    ARGS[1] = fname
    include(STARTUP_PATH)
    fill!(eqn.res, 0.0)
    eqn.disassembleSolution(mesh, sbp, eqn, opts, eqn.q, eqn.q_vec)
  #  println("eqn.q_vec = ", eqn.q_vec)
    AdvectionEquationMod.evalAdvection(mesh, sbp, eqn, opts)
    eqn.assembleSolution(mesh, sbp, eqn, opts, eqn.res, eqn.res_vec)
    @fact eqn.res_vec --> roughly(zeros(mesh.numDof), atol=1e-12)
    =#

    fname = make_input_mms(4, dg=true)
    include(STARTUP_PATH)
    fill!(eqn.res, 0.0)
    eqn.disassembleSolution(mesh, sbp, eqn, opts, eqn.q, eqn.q_vec)
    AdvectionEquationMod.evalAdvection(mesh, sbp, eqn, opts)
    eqn.assembleSolution(mesh, sbp, eqn, opts, eqn.res, eqn.res_vec)
    @fact eqn.res_vec --> roughly(zeros(mesh.numDof), atol=1e-12)

    println("\n  -----testing 3D -----")
    ARGS[1] = "input_vals_3d.jl"
    include(STARTUP_PATH)

    println("  -----testing degree 1 polynomial-----")

    make_input_mms(1, dg=true)
    include(STARTUP_PATH)
    fill!(eqn.res, 0.0)
    eqn.disassembleSolution(mesh, sbp, eqn, opts, eqn.q, eqn.q_vec)
    AdvectionEquationMod.evalAdvection(mesh, sbp, eqn, opts)
    eqn.assembleSolution(mesh, sbp, eqn, opts, eqn.res, eqn.res_vec)
    @fact eqn.res_vec --> roughly(zeros(mesh.numDof), atol=1e-12)

    make_input_mms(1, dg=true, operator="SBPGamma")
    include(STARTUP_PATH)
    fill!(eqn.res, 0.0)
    eqn.disassembleSolution(mesh, sbp, eqn, opts, eqn.q, eqn.q_vec)
    AdvectionEquationMod.evalAdvection(mesh, sbp, eqn, opts)
    eqn.assembleSolution(mesh, sbp, eqn, opts, eqn.res, eqn.res_vec)
    @fact eqn.res_vec --> roughly(zeros(mesh.numDof), atol=1e-12)



    println("  -----testing degree 2 polynomial-----")
    make_input_mms(2, dg=true)
    include(STARTUP_PATH)
    fill!(eqn.res, 0.0)
    eqn.disassembleSolution(mesh, sbp, eqn, opts, eqn.q, eqn.q_vec)
    AdvectionEquationMod.evalAdvection(mesh, sbp, eqn, opts)
    eqn.assembleSolution(mesh, sbp, eqn, opts, eqn.res, eqn.res_vec)
    for i=1:mesh.numDof
      @fact eqn.res_vec[i] --> roughly(0.0, atol=1e-12)
    end

    println("testing gamma")
    make_input_mms(2, dg=true, operator="SBPGamma")
    include(STARTUP_PATH)
    fill!(eqn.res, 0.0)
    eqn.disassembleSolution(mesh, sbp, eqn, opts, eqn.q, eqn.q_vec)
    AdvectionEquationMod.evalAdvection(mesh, sbp, eqn, opts)
    eqn.assembleSolution(mesh, sbp, eqn, opts, eqn.res, eqn.res_vec)
    for i=1:length(eqn.res_vec)
      @fact eqn.res_vec[i] --> roughly(0.0, atol=1e-11)
    end

    println("  ----- testing degree 3 polynomial-----")
    println("testing gamma")
    make_input_mms(3, dg=true, operator="SBPGamma")
    include(STARTUP_PATH)
    fill!(eqn.res, 0.0)
    eqn.disassembleSolution(mesh, sbp, eqn, opts, eqn.q, eqn.q_vec)
    AdvectionEquationMod.evalAdvection(mesh, sbp, eqn, opts)
    eqn.assembleSolution(mesh, sbp, eqn, opts, eqn.res, eqn.res_vec)
    for i=1:length(eqn.res_vec)
      @fact eqn.res_vec[i] --> roughly(0.0, atol=1e-11)
    end

    println("  ----- testing degree 4 polynomial-----")
    println("testing gamma")
    make_input_mms(4, dg=true, operator="SBPGamma")
    include(STARTUP_PATH)
    fill!(eqn.res, 0.0)
    eqn.disassembleSolution(mesh, sbp, eqn, opts, eqn.q, eqn.q_vec)
    AdvectionEquationMod.evalAdvection(mesh, sbp, eqn, opts)
    eqn.assembleSolution(mesh, sbp, eqn, opts, eqn.res, eqn.res_vec)
    for i=1:length(eqn.res_vec)
      @fact eqn.res_vec[i] --> roughly(0.0, atol=1e-9)
    end

  end  # end facts block

  return nothing
end  # end function

#test_mms()
add_func1!(AdvectionTests, test_mms)


