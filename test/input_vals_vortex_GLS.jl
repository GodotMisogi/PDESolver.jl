# this user supplied file creates a dictionary of arguments
# if a key is repeated, the last use of the key is used
# it is a little bit dangerous letting the user run arbitrary code
# as part of the solver
# now that this file is read inside a function, it is better encapsulated

arg_dict = Dict{ASCIIString, Any} (
"run_type" => 5,
"jac_type" => 2,	
"order" => 1,
"dimensions" => 2,
"Q_transpose" => true, # Weak differentiate option in eval volume integrals
"IC_name" => "ICIsentropicVortex",
#"numBC" => 2,
"numBC" => 1,
#"BC1" => [ 7, 13],
"BC1" => [0],
"BC1_name" => "isentropicVortexBC", # "allOnesBC", 
"delta_t" => 0.001, # default 0.005
"t_max" => 500000.000,
"smb_name" => "SRCMESHES/Test1el.smb",
#"dmg_name" => "SRCMESHES/vortex.dmg",
"dmg_name" => ".null",
"res_abstol" => 1e-10,
"res_reltol" => 1e-9,
"step_tol" => 1e-10,
"itermax" => 30,
"writeq" => false,
"step_tol" => 1e-10,
"itermax" => 30,
"use_edgestab" => false,
"edgestab_gamma" => -0.01,
"use_GLS" => true,
"use_filter" => false,
#"use_res_filter" => true,
#"filter_name" => "raisedCosineFilter",
"use_dissipation" => false,
"dissipation_name" => "damp1",
"dissipation_const" => 12.00,
"writeq" => false,
# "perturb_ic" => true,
#"perturb_mag" => 0.001,
#"write_sparsity" => true,
#"write_jac" => true,
"write_edge_vertnums" => false,
"write_face_vertnums" => false,
"write_qic" => false,
"writeboundary" => false,
"write_res" => false,
"print_cond" => false,
#"write_counts" => true,
"write_vis" => true,
"solve" => false,
)
