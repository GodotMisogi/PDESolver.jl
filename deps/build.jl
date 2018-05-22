# download and build all non metadata dependences
include("build_funcs.jl")

"""
  This function install all of PDESolvers dependencies (currently PDESolver
  itself does not need to be built).

  Environmental variables:
    PDESOLVER_INSTALL_DEPS_MANUAL: install all dependencies manually (ie. using 
                                   the particular commit stored in this file.
                                   Note that if the package is already
                                   installed, this does not do anything

    PDESOLVER_FORCE_DEP_INSTALL_ALL: download and install all dependencies,
          checking out the version stored in this file, even if the package
          is already installed

    PDESOLVER_FORCE_DEP_INSTALL_pkg_name: where pkg_name is replaced with the
          name of a dependency, forces the installation of only that dependency.

    PDESOLVER_BUNDLE_DEPS: download packages to a specified directory, do not
                           install

    PDESOLVER_PKGDIR: the specified directory for PDESOLVER_BUNDLE_DEPS

    PDESOLVER_UNBUNDLE_DEPS: install PDESolver, using the packages in
                             PDESOLVER_PKGDIR rather than downloading from the
                             internet

    TODO: add a bundling mode that copies the currently installed packages to
          a directory, rather than downloading them from the internet
"""
function installPDESolver()

  f = open("install.log", "w")
  #------------------------------------------------------------------------------
  # these packages are always installed manually
  #-----------------------------------------------------------------------------
  # [pkg_name, git url, commit identified]
  std_pkgs = [
              "MPI" "https://github.com/JaredCrean2/MPI.jl.git" "e256e63656f61d3cae48a82a9b50f4cd031f4716"
              "ODLCommonTools" "https://github.com/OptimalDesignLab/ODLCommonTools.jl.git" "master";
              "SummationByParts" "https://github.com/OptimalDesignLab/SummationByParts.jl.git" "jcwork";
              "PumiInterface" "https://github.com/OptimalDesignLab/PumiInterface.jl.git" "master";
              "PETSc2" "https://github.com/OptimalDesignLab/PETSc2.jl.git" "v0.4"
              ]


  # manually install MPI until the package matures
  # handle Petsc specially until we are using the new version
  petsc_git = "https://github.com/JaredCrean2/Petsc.git"

  pkg_dict = Pkg.installed()  # get dictionary of installed package names to version numbers

  # force installation to a specific commit hash even if package is already present
  # or would normally be install via the REQUIRE file

  global const FORCE_INSTALL_ALL = haskey(ENV, "PDESOLVER_FORCE_DEP_INSTALL_ALL")

  # figure out the package directory
  if haskey(ENV, "PDESOLVER_PKGDIR")
    pkgdir = ENV["PDESOLVER_PKGDIR"]
  else
    pkgdir = Pkg.dir()
  end

  println(f, "PDESOLVER_BUNDLE_DEPS = ", haskey(ENV, "PDESOLVER_BUNDLE_DEPS"))
  println(f, "PDESOLVER_PKGDIR = ", haskey(ENV, "PDESOLVER_PKGDIR"))

  println(f, "\n---Installing non METADATA packages---\n")
  for i=1:size(std_pkgs, 1)
    pkg_name = std_pkgs[i, 1]
    git_url = std_pkgs[i, 2]
    git_commit = std_pkgs[i, 3]
    if haskey(ENV, "PDESOLVER_BUNDLE_DEPS")
      bundle_pkg(pkgdir, pkg_name, git_url, git_commit, f)
    elseif haskey(ENV, "PDESOLVER_UNBUNDLE_DEPS")
      unbundle_pkg(pkgdir, pkg_name, f)
    else  # do regular install
      install_pkg(pkgdir, pkg_name, git_url, git_commit, pkg_dict, f)
    end
  end

  println(f, "\n---Finished installing non METADATA packages---\n")
  #------------------------------------------------------------------------------
  # these packages are not always installed manually
  # this section provides a backup mechanism if the regular version resolution
  # mechanism fails
  #------------------------------------------------------------------------------

  # array of [pkg_name, commit_hash]
  pkg_list = ["Compat" "https://github.com/JuliaLang/Compat.jl.git" "fa0053b241fee05dcc8d1840f0015dfeb2450bf4";
              "URIParser" "https://github.com/JuliaWeb/URIParser.jl.git" "1c4c5f2af17e57617c018ad060f0ec3c9dc5946b";
              "FactCheck" "https://github.com/JuliaLang/FactCheck.jl.git" "e3739d5fdf0e54bc1e74957c060c693cd8ce9cd6";
              "ArrayViews" "https://github.com/JuliaLang/ArrayViews.jl.git" "93e80390aeedb1dbcd90281b6dff7f760f430bc8";
              "SHA" "https://github.com/staticfloat/SHA.jl.git" "90144b2c9e6dd41582901ca0b311215b6bfb3f10";
              "BinDeps" "https://github.com/JuliaLang/BinDeps.jl.git" "ce03a36a969eedc5641aff1c6d7f8f886a17cc98";
              "Debug" "https://github.com/toivoh/Debug.jl.git" "0e733093cd71c67bd40ac1295e54153c3db0c751";
#              "MPI" "https://github.com/JuliaParallel/MPI.jl.git" "c546ee896f314340dc61e8bf7ab71f979c57d73c";
              ]
              
  
    println(f, "\n---Considering manual package installations---\n")
    for i=1:size(pkg_list, 1)

      pkg_name = pkg_list[i, 1]
      git_url = pkg_list[i, 2]
      git_commit = pkg_list[i, 3]

      if haskey(ENV, "PDESOLVER_INSTALL_DEPS_MANUAL") || haskey(ENV, "PDESOLVER_FORCE_DEP_INSTALL_$pkg_name") || FORCE_INSTALL_ALL

        install_pkg(pkgdir, pkg_name, git_url, git_commit, pkg_dict, f, force=true)
      end
      if haskey(ENV, "PDESOLVER_BUNDLE_DEPS")
        bundle_pkg(pkgdir, pkg_name, git_url, git_commit, f)
      elseif haskey(ENV, "PDESOLVER_UNBUNDLE_DEPS")
        unbundle_pkg(pkgdir, pkg_name, f)
      end

    end

    println(f, "\n---Finished manual package installations---\n")

  close(f)

  # generate the known_keys dictonary
  if !haskey(ENV, "PDESOLVER_BUNDLE_DEPS")
    start_dir = pwd()
    input_path = joinpath(Pkg.dir("PDESolver"), "src/input")
    cd(input_path)
    include(joinpath(input_path, "extract_keys.jl"))
    cd(start_dir)
  end

end  # end function


# run the installation
installPDESolver()
