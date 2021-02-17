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


# $(call add-to-cleanup,$(item)), external
#
# This macro is used to inform the framework that some file is to be removed
# when `make clean` is run. One example of when this comes in handy is in
# src/source.mk, line 59.
define add-to-cleanup
	$(shell echo $1 >> $(clean_file))
endef

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

# $(call generate-headers,$(flags),$(file),$(c_or_cxx_flags)),internal
#
# I like using Vim, and tags for the files I'm working is almost a
# must at this point. This script generates ctags for all files that are
# included in the project, as well as the libraries that they use. I did not
# come up with this script, I found it here:
#
# https://www.topbug.net/blog/2012/03/17/generate-ctags-files-for-c-slash-c-plus-plus-source-files-and-all-of-their-included-header-files/
define generate-headers
	gcc -M $1 $2	 	|\
	sed -e 's/[\\ ]/\n/g' 	|\
	sed -e '/^$$/d'	-e '/\.o:[ \t]*$$/d'
endef

# $(call generate-c-headers,$(flags),$(source)), internal
#
# Generate C tags with the above macro
define generate-c-headers
	$(call generate-headers,\
		$(CFLAGS) $($1_$2_flags_internal) $($1_flags_internal),$2)
endef

# $(call generate-cxx-tags,$(flags),$(source)), internal
#
# Generate C++ tags with the above macro
define generate-cxx-headers
	$(call generate-headers,\
		$(CXXFLAGS) $($1_$2_flags_internal) $($1_flags_internal),$2)
endef


# $(call make-tags), internal
#
# Entry point for creating the tags. In short, the programs and their associated
# source files are looped through and depending on if the file is a C or C++
# file, sent to the respective header extraction script.
#
# In long, C headers are different from C++ headers, so we have to treat them
# separately. This implementation creates a couple local variables that are
# meant to store the list of headers for C and C++ files respectively. Each
# source file is looped through, and the headers are stored in their respective
# variables. Once all headers are accounted for, they're passed to ctags. Some
# projects might not use C or C++, so one list may be empty. The if-statements
# at the end of the macro is to guard from 'No input file specified'-errors from
# ctags. Note the call to $(sort), in this case I'm using it to remove duplicates.
# There are different methods to remove duplicates in a list in make, but I haven't seen
# any test data that would show which one would be the quickest. Sorting does
# add some overhead, but implementing the duplicate removal as a macro would
# probably be slower than just sorting the list, since the sorting is done
# straight in C, whereas any other implementation would have to be interpreted.
#
# Duplicate removal could also be implemented as running the list through awk like
# in sort-cleanfile, but again, I'm not sure if it's worth it. More testing is needed.
#
# At the end the generated tag file is marked for removal when `make clean` in
# run. I prefer to pretty much nuke the whole repo back to the starting
# position, and don't see removing the tag file at the same time as an issue,
# but if this annoys you, just remove the call to add-to-cleanup.
define make-tags
$(eval c_header_files := )
$(eval cxx_header_files := )
$(foreach program,$(notdir $(programs)),\
	$(foreach source_file,$($(program)_sources_internal),\
		$(if $(filter .c,$(suffix $(source_file))),\
		$(eval c_header_files += $(shell \
			$(call generate-c-headers,$(program),$(source_file)))),\
		$(eval cxx_header_files += $(shell \
			$(call generate-cxx-headers,$(program),$(source_file)))))))

$(if $(cxx_header_files),\
	ctags -a --c++-kinds=+p --extras=+q --fields=+iaS $(sort $(cxx_header_files)))
$(if $(c_header_files),\
	ctags -a --c-kinds=+p --fields=+iaS $(sort $(c_header_files)))

$(call add-to-cleanup,tags)
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
endef

-include $(configure)

programs :=
dependencies :=
include src/source.mk
include $(dependencies)

all: $(programs)
	$(call prepare-cleanup)

clean:
	$(call prepare-cleanup)
	xargs $(RM) -r -- < $(clean_file)

debug: CFLAGS += -DDEBUG -g
debug: CXXFLAGS += -DDEBUG -g
debug: all

lint: CFLAGS += -fsyntax-only
lint: CXXFLAGS += -fsyntax-only
lint: $(foreach t,$(notdir $(programs)),$($(t)_objects_internal))
	$(call prepare-cleanup)

.PHONY: tags
tags:
	@$(call make-tags)
	$(call prepare-cleanup)

$(call prepare-makefile)
