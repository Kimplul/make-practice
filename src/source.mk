# Process subdirectories first. Not strictly necessary, but is probably the
# simplest method. If the different source.mk files need to communicate with
# eachother, you can define variables before including a file.
include src/secondbin/source.mk
include src/code1/source.mk
include src/code2/source.mk

# Prepare information about files in this directory
# Not strictly necessary, but a convenience.

# Current directory
current_dir 	:= src

# Source files in this directory we want to compile into exec
local_sources 	:= lib.c main.cpp
# Flags we want to add to lib.c and main.cpp
local_flags	:= -DALL

# Add lib.c and main.cpp to be compiled into the program exec,
# and also inform make which flags should be applied to both of them.
$(call add-entry,exec,$(local_sources),$(current_dir),$(local_flags))

# Add a flag to main.cpp, and only to main.cpp.
#
# Note that the current directory must be passed, as otherwise there's
# no way to know which main.cpp the flag should be added to. If you happen to
# have lots of different files that all require different flags, you can always
# wrap this call in a macro:
$(call add-entry,exec,main.cpp,$(current_dir),-DSINGLE_FLAG)

# Prepare exec itself

# Linker flags. In this example, -ldl is not necessary, but it's here for
# demonstration purposes.
exec_linker_flags 	:= -ldl

# Global flags, i.e. flags that should be passed to all files included in exec.
# In this example, all source files reference eachother through the syntax
# #include <file>, so we need to add all directories where our source files
# exist to the include flags. For this binary, we also want to include the extra
# flags found in config.mk.
exec_global_flags 	:= $(addprefix -I ,src src/code1 src/code2) $(EXTRA_FLAGS)

# Inform make that exec should be compiled with these settings. The linker flags
# are applied when linking, and the global flags are applied when compiling the
# source files that will be included into this binary.
$(call add-target,exec,$(linker_flags),$(exec_global_flags))

# The framework allows some custom rules, such as in this example running files
# through m4.
#
# DO NOT write rules for .o files, as that will most probably mess up the
# internal state of the framework. If you do, make will issue a warning. I
# sincerely hope you don't ignore warnings.
#
# Note that if you write rules, it is up to you to inform the framework of which
# files, if any, should be cleaned up.
%.c: %.m4
	$(call add-to-cleanup,$@)
	m4 $^ > $@
