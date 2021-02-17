# The second binary of this example project.
#
# Note that you would typically want to separate the different targets more
# cleanly than in this project, hopefully with src/binone and src/bintwo or
# something similar, but I'm just showing how flexible the framework
# is.

# Current directory. There are some more automated ways to get the current
# directory, but this is nice and simple enough for this project, and besides,
# optimal Makefile code is outside of the scope of this documentation.
current_dir := src/secondbin

# The source file that we want to compile.
#
# Note that we're using the same name as a file in one folder up. This is
# intentional, but luckily, due to how this file works, it's all good. Also note
# that we're using the same as one that's being used in another binary, but in
# this case we compile it with different flags.
local_sources := main.cpp ../code1/code1.c

# Notify the framework that we want to compile these two files
$(call add-entry,bin.a,$(local_sources),$(current_dir))

# Notify the framework that for this binary we want to use the flag -DTEST when
# compiling code1.c
$(call add-entry,bin.a,../code1/code1.c,$(current_dir),-I src/code1 -DTEST)

# Tell the framework that this binary should be compiled as a library. Note that
# since the library flag is last, we have to provide non-values to all other
# arguments besides the last one. Unfortunately a limitation of make itself.
$(call add-target,bin.a,,,static)
