#include("new_file2.jl")  # creates arg_dict
include("../tools/misc.jl")
@doc """
### read_input

  This function reads a file which must declare a dictionary of options.
  See the documention on input variables for valid keywords.  This function
  returns the dictionary after doing some sanity checks

  Arguments:
    * fname : name of file to read
"""->
function read_input(fname::AbstractString)

println("pwd = ", pwd())

include(joinpath(pwd(), fname))  # include file in the users pwd()

# take action based on the dictionary

if haskey(arg_dict, "var1")
  global DB_LEVEL =  arg_dict["var1"]
else
  global DB_LEVEL = 0
end

# record fname in dictionary
arg_dict["fname"] = fname

# supply default values if not given 
# get() = get!(dictionary, key, default)
gamma = get!(arg_dict, "gamma", 1.4)
gamma_1 = gamma - 1
R = get!(arg_dict, "R", 287.058)
cv = R/gamma_1

Ma = get!(arg_dict, "Ma", -1.0)
Re = get!(arg_dict, "Re", -1.0)
aoa = get!(arg_dict, "aoa", -1.0)*pi/180
arg_dict["aoa"] = aoa*pi/180  # convert to radians
rho_free = get!(arg_dict, "rho_free", -1)
E_free = get!(arg_dict, "E_free", -1)


# debugging options
writeflux = get!(arg_dict, "writeflux", false)
writeboundary = get!(arg_dict, "writeboundary", false)
get!(arg_dict, "writeq", false)
get!(arg_dict, "write_edge_vertnums", false)
get!(arg_dict, "write_face_vertnums", false)
get!(arg_dict, "write_boundarynums", false)
get!(arg_dict, "write_dxidx", false)
get!(arg_dict, "write_coords", false)

# testing options
get!(arg_dict, "solve", true)

# write complete dictionary to file
fname = "arg_dict_output.txt"
rmfile(fname)
f = open(fname, "a+")
arg_keys = keys(arg_dict)

for key_i in arg_keys
  println(f, key_i, " => ", arg_dict[key_i])
end
close(f)


# do some sanity checks here
# deal with boundary conditions
# "numBC" must be dictionary key whose value is the number of boundary conditions
# for each boundary condition there must be keys BCi and BCi_name for i=1:numBC
numBC = arg_dict["numBC"]

#=
# sort all the BC arrays
for i=1:numBC
  key_i = string("BC", i)
  println("edge nums before sort = ", arg_dict[key_i])
  sort!(arg_dict[key_i])
  println("edge nums after sort = ", arg_dict[key_i])
  enum_key_i = string("BC", i, "_name")
  println("arg_dict[enum_key_i] = ", arg_dict[enum_key_i])
end

# check for repeated edge numbers
# this isn't cache friendly
for i=1:numBC
key_i = string("BC", i)
vals = arg_dict[key_i]

  for j=1:length(vals)
    val_j = vals[j]
    println("val_j = ", val_j)

    # check this value against all previous one
    for k=1:(i-1)
      key_k = string("BC", k)
      println("key_k = ", key_k)
      println("arg_dict[key_k] = ", arg_dict[key_k])
      index = findfirst(arg_dict[key_k], val_j)
      if index != 0
	println("Error: cannot apply more than one boundary condition to a model entity")
	println("  Model entity ", val_j, " from BC", i, " is repeated at index ", index, " of BC", k)
      end
    end
  end
end

# check fo repeated edge numbers within each array

for i=1:numBC
 key_i = string("BC", i)
 vals = arg_dict[key_i]

 if vals != unique(vals)
   println("Error: cannot apply more than one boundary condition to a model entity")
   println("BC", i, " has a repeated value")
 end
end

=#

return arg_dict

end  # end function


macro do_db(expr1)
  println("entered macro do_db")
#  println("expr1 = ", expr1)
#  println("typeof(expr1) = ", typeof(expr1))
  if DB_LEVEL < 2
    println("at compile time, in DB_Level < 2")
    return quote
            println("runtime expression")
             expr1
    end
  else
    return nothing
  end
end


