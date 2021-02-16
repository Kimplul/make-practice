# Makefile built for flexibility as practice
# At the start of each macro's comment section, I have a short example of how to
# call it, as well as a comment about whether the macro is inteded for interal
# or external use.
#
# Example:
# $(call name-of-macro,$(argument_0),$(argument_1),...)

# Initial configuration values

# If there exists a separate configure stage, place the produced configuration
# into config.mk (or change the variable to some other file). This file will be
# read before any other, and preferably would be used to set global flags or
# something similar.
configure	:= config.mk

# Into which directory should the output of this Makefile be placed
build_dir 	:= build

# List of items that should be removed when running `make clean`.
cleanup		:=

# File that is used to store information about items to be removed. If you run
# `make`, the build directory is generated. After that, if you run `make tags`,
# a tags file will be generated. To remove both of these files at the same time,
# a list of items to be removed needs to be stored somewhere outside of the
# Makefile. This is that list.
#
# If you want to keep your tags file, see make-tags.
clean_file	:= cleanup

# Global flags for C and C++. These are just my personal preferences, change as
# you see fit.
CFLAGS = -Wall -Werror -Wextra
CXXFLAGS = -Wall -Werror -Wextra

# Default rule, has to come before all other rules to be default.
all:

# $(call make-depend $(source-file),$(object-file),$(depend-file),$(flags))
#
# Generate a dependency file for a given source/object file combo. To some
# extent the $(object-file) parameter is unnecessary, as we could just as well
# infer it from the source file, but in the future there may come situation
# where it's not possible.
#
# Mildly unfortunate that we have to always check if the directory exists,
# as rules loaded with sources are always run before anything in the main
# Makefile. I would've preferred to generate the whole source tree at once at
# the start of a `make` invocation, but this would've been impossible without an
# external Makefile just for that purpose. This does work though.
#
# The C++-compiler is used in this case, as I'm not sure how C++20 with `import`
# and modules will work with this method. I'm assuming the C++-compiler will
# handle them alright, but I suppose we'll see. A full description of the flags
# and their meaning can be found here:
#
# https://gcc.gnu.org/onlinedocs/gcc/Preprocessor-Options.html#Preprocessor-Options
#
# In short, -MM means generate file dependency info in a format that make can
# read, and -MP adds phony targets, which eliminate certain issues that arise
# when adding or removing files from the source tree. More info can be found in 
# 'Managing Projects with GNU Make, 3rd Edition' by Robert Mecklenburg, on p.
# 149 and onward.
define make-depend
@echo "Generating dependencies for $1"
if [ ! -d $(dir $3) ];				\
then						\
	mkdir -p $(dir $3);			\
fi

echo -n "$3 " > $2 &&				\
	$(CXX) -MM 				\
	-MP					\
	$4					\
	$(TARGET_ARCH)				\
	$1 >> $2
endef

# $(call generate-tags,$(flags),$(file),$(c_or_cxx_flags)),internal
#
# I like using Vim, and tags for the files I'm working is almost a
# must at this point. This script generates ctags for all files that are
# included in the project, as well as the libraries that they use. I did not
# come up with this script, I'll add credits as soon as I find out where I got
# it from.
#
# C++ needs --extras=+q, c requires that it is left out, otherwise we end up
# with loads of anonymous structs etc., which is why I has to split this
# function in twine. Both languages can still share a common tags file.
define generate-tags
	gcc -M $1 $2	 	|\
	sed -e 's/[\\ ]/\n/g' 	|\
	sed -e '/^$$/d'		|\
	sed -e '/\.o:[ \t]*$$/d'|\
	ctags -L - -a --fields=+iaS $3;
endef

# $(call generate-cxx-tags,$(program),$(source)), internal
#
# Generate C tags with the above macro
define generate-c-tags
	$(call generate-tags,\
		$(CFLAGS) $($1_$2_flags_internal) $($1_flags_internal),$2,--c-kinds=+p)
endef

# $(call generate-cxx-tags,$(program),$(source)), internal
#
# Generate C++ tags with the above macro
define generate-cxx-tags
	$(call generate-tags,\
		$(CXXFLAGS) $($1_$2_flags_internal) $($1_flags_internal),$2,--c++-kinds=+p)
endef

# $(call make-tags), internal
#
# Entry point for creating the tags. In short, the programs and their associated
# source files are looped through and depending on if the file is a C or C++
# file, sent to the respective tag generation script.
#
# At the end the generated tag file is marked for removal when `make clean` in
# run. I prefer to pretty much nuke the whole repo back to the starting
# position, and don't see removing the tag file at the same time as an issue,
# but if this annoys you, just remove the call to add-to-cleanup.
define make-tags
$(foreach program,$(notdir $(programs)),\
	$(foreach source_file,$($(program)_sources_internal),\
		$(if $(filter .c,$(suffix $2)),\
		$(call generate-c-tags,$(program),$(source_file)),\
		$(call generate-cxx-tags,$(program),$(source_file)))))

$(call add-to-cleanup,tags)
endef

# $(call add-to-cleanup,$(item)), external
#
# This macro is used to inform the framework that some file is to be removed
# when `make clean` is run. One example of when this comes in handy is in
# src/source.mk, line 59.
define add-to-cleanup
	$(shell echo $1 >> $(clean_file))
endef

# $(call sort-cleanfile), internal
#
# Used for erasing possible duplicates in the cleanfile. 'sort' is arguably not
# the most fitting name, but 'clean-cleanfile' sounded a bit ridiculous.
#
# Awk is a great language, and is the second fastest way to do this particular
# task. The quickest one, according to my testing, was Perl, by about 2-3 times.
# The difference between the two for a 500 Mib file was only approx. two seconds.
# Perl is pretty much ubiquitous, but on the off chance that someone only has
# coreutils installed, I went with awk, even though it is a bit slower.
define sort-cleanfile
	$(shell awk '!seen[$$0]++' $(clean_file) > /tmp/$(clean_file);\
		mv /tmp/$(clean_file) $(clean_file))
endef

# $(call add-single-rule,$(program),$(file),$(flags))
define add-single-rule
$(eval local_object := $(addprefix $(build_dir)/$1/,$(subst $(suffix $2),.o,$2)))
$(eval local_compiler := $(if $(filter .c,$(suffix $2)),CC,CXX))
$(eval substitution := $(subst .,_,$1))
$(eval global_flags_internal := $$(if $$(filter .c,$$(suffix $2)),CFLAGS,CXXFLAGS))

$1_$2_defined := true
$1_$2_flags_internal := $3


$(local_object): $2
	$$($(local_compiler)) $$($(global_flags_internal)) $$($1_flags_internal)\
		$$($1_$2_flags_internal) $4 -c $2 -o $(local_object)

$(eval local_dependency := $(subst .o,.d,$(local_object)))
$(eval dependencies += $(local_dependency))

$(local_dependency): $2
	@$$(call make-depend,\
		$$^,$$@,$(addprefix $(build_dir)/$1/,$(subst $(suffix $2),.d,$2)),\
		$$($(global_flags_internal)) $$($1_flags_internal)\
		$$($1_$2_flags_internal))
endef

define add-to-flags
$1_$2_flags_internal += $3
endef

# $(call add-rules,$(program),$(file),$(flags))
define add-rules
$(if $($1_$2_defined),\
	$(call add-to-flags,$1,$2,$3),\
	$(call add-single-rule,$1,$2,$3))
endef

# $(call call-add-entry,$(program),$(local_sources),$(include_dir),$(local_flags))
define call-add-entry
vpath % $3

$1_sources_internal := $$(sort $$($1_sources_internal) $(addprefix $3/,$2))
$1_objects_internal := $$(sort $$($1_objects_internal) \
	$(subst .c,.o,$(subst .cpp,.o,$(addprefix $(build_dir)/$1/$3/,$2))))

$(foreach source,$(addprefix $3/,$2),\
	$(eval $(call add-rules,$1,$(source),$4)))
endef

# $(call call-add-program,$(program),$(linker_flags_internal),$(global_flags_internal))
define call-add-program
$1 := $(build_dir)/$1/$1
$1_flags_internal := $3
programs += $$($1)

$$($1): $$($1_objects_internal)
ifeq ($4,)
	$(CXX) $$^ -o $$@ $2
else
	$(AR) rcs $$@ $$^
endif
endef

# $(call add-entry,$(program),$(local_sources_internal),$(dir_of_sources_internal),$(flags))
define add-entry
$(eval $(call call-add-entry,$1,$2,$3,$4))
endef

# $(call add-progran,$(program),$(linker_flags),$(global_flags),$(library))
define add-program
$(eval $(call call-add-program,$1,$2,$3,$4))
endef

define prepare-cleanup
$(call add-to-cleanup,$(build_dir))
$(call add-to-cleanup,$(clean_file))
$(call sort-cleanfile)
endef

define prepare-makefile
$(foreach program,$(programs),\
	$(eval $(program)_sources_internal := $(sort $($(program)_sources_internal)))\
	$(eval $(program)_objects_internal := $(sort $($(program)_sources_internal))))
$(foreach rule,$(programs),$(eval $(notdir $(rule)): $(rule)))
$(call prepare-cleanup)
endef

-include $(configure)

programs :=
dependencies :=
include src/source.mk
include $(dependencies)

all: $(programs)

clean:
	xargs $(RM) -r < $(clean_file)

debug: CFLAGS += -DDEBUG -g
debug: CXXFLAGS += -DDEBUG -g
debug: all

lint: CFLAGS += -fsyntax-only
lint: CXXFLAGS += -fsyntax-only
lint: $(foreach t,$(notdir $(programs)),$($(t)_objects_internal))

.PHONY: tags
tags:
	@$(call make-tags)

$(call prepare-makefile)
