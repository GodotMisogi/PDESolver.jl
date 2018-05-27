# options checking specific to the Euler Equations

"""
  This function checks the options in the options dictionary after default
  values have been supplied and throws exceptions if unsupported/incompatable
  options are specified

  Inputs:
    opts: options dictionary

  Outputs:
    none
"""
function checkOptions(opts)

  if opts["physics"] != PhysicsName
    error("physics not specified as $PhysicsName, are you lost?")
  end

  if opts["use_staggered_grid"]
    error("staggered grids not supported for physics $PhysicsName")
  end

  get(opts, "calc_jac_explicit", false)


  return nothing
end
