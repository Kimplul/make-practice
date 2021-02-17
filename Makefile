#% Makefile built for flexibility as a toy project
#%
#% At the start of each macro's comment section, I have a short example of how to
#% call it, as well as a comment about whether the macro is inteded for interal
#% or external use.
#%
#% Example:
#% $(call name-of-macro,$(argument_0),$(argument_1),...)
#% 
#% Lines beginning with #% are explanations and rambling about the
#% implementation about different macros and variables. They can safely be
#% removed with `grep -v ^#%`.

#% Initial configuration values

#% If there exists a separate configure stage, place the produced configuration
#% into config.mk (or change the variable to some other file). This file will be
#% read before any other, and preferably would be used to set global flags or
#% something similar.
configure	:= config.mk

#% Into which directory should the output of this Makefile be placed
build_dir 	:= build

#% File that is used to store information about items to be removed. If you run
#% `make`, the build directory is generated. After that, if you run `make tags`,
#% a tags file will be generated. To remove both of these files at the same time,
#% a list of items to be removed needs to be stored somewhere outside of the
#% Makefile. This is that list.
#%
#% If you want to keep your tags file, see make-tags.
clean_file	:= cleanup

#% Global flags for C and C++. These are just my personal preferences, change as
#% you see fit.
CFLAGS = -Wall -Werror -Wextra
CXXFLAGS = -Wall -Werror -Wextra

#% Default rule, has to come before all other rules to be default.
.PHONY: all
all:


# $(call add-to-cleanup,$(item)), external
#% 
#% One of the three APi calls.
#%
#% This macro is used to inform the framework that some file is to be removed
#% when `make clean` is run. One example of when this comes in handy is in
#% src/source.mk, line 59.
#%
#% The argument is:
#
# $(item)	- Item to be cleaned when `make clean` is run.
define add-to-cleanup
	$(shell echo $1 >> $(clean_file))
endef

# $(call make-depend $(source-file),$(object-file),$(depend-file),$(flags))
#% 
#% Generate a dependency file for a given source/object file combo. To some
#% extent the $(object-file) parameter is unnecessary, as we could just as well
#% infer it from the source file, but in the future there may come situation
#% where it's not possible.
#%
#% Mildly unfortunate that we have to always check if the directory exists,
#% as rules loaded with sources are always run before anything in the main
#% Makefile. I would've preferred to generate the whole source tree at once at
#% the start of a `make` invocation, but this would've been impossible without an
#% external Makefile just for that purpose. This does work though.
#%
#% The C++-compiler is used in this case, as I'm not sure how C++20 with `import`
#% and modules will work with this method. I'm assuming the C++-compiler will
#% handle them alright, but I suppose we'll see. A full description of the flags
#% and their meaning can be found here:
#%
#% https://gcc.gnu.org/onlinedocs/gcc/Preprocessor-Options.html#Preprocessor-Options
#%
#% In short, -MM means generate file dependency info in a format that make can
#% read, and -MP adds phony targets, which eliminate certain issues that arise
#% when adding or removing files from the source tree. More info can be found in 
#% 'Managing Projects with GNU Make, 3rd Edition' by Robert Mecklenburg, on p.
#% 149 and onward.
define make-depend
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
#%
#% I like using Vim, and tags for the files I'm working is almost a
#% must at this point. This script generates a list of all files that are
#% included in the project, as well as the libraries that they use. I did not
#% come up with this script, I found it here:
#%
#% https://www.topbug.net/blog/2012/03/17/generate-ctags-files-for-c-slash-c-plus-plus-source-files-and-all-of-their-included-header-files/
define generate-headers
	$(CXX) -M $1 $2	 	|\
	sed -e 's/[\\ ]/\n/g' 	|\
	sed -e '/^$$/d'	-e '/\.o:[ \t]*$$/d'
endef

# $(call generate-c-headers,$(target),$(source)), internal
#%
#% Generate a list of C files associated with this project.
define generate-c-headers
	$(shell $(call generate-headers,\
		$(CFLAGS) $($1_$2_flags_internal) $($1_flags_internal),$2))
endef

# $(call generate-cxx-tags,$(target),$(source)), internal
#%
#% Generate a list of C++ files associated with this project.
define generate-cxx-headers
	$(shell $(call generate-headers,\
		$(CXXFLAGS) $($1_$2_flags_internal) $($1_flags_internal),$2))
endef


# $(call make-tags,$(c_header_files),$(cxx_header_files)), internal
#%
#% Entry point for creating the tags. In short, for the given source files and
#% their arguments, pass them to ctags, which will generate a tags file that can
#% then be read from Vim or Emacs.
#%
#% In long, C headers are different from C++ headers, so we have to treat them
#% separately. This implementation takes two arguments, that should
#% store the list of headers for C and C++ files respectively. 
#% Some projects might not use C or C++, so one list may be empty. The if-statements
#% at the end of the macro is to guard from 'No input file specified'-errors from ctags.
#%
#% At the end the generated tag file is marked for removal when `make clean` in
#% run. I prefer to pretty much nuke the whole repo back to the starting
#% position, and don't see removing the tag file at the same time as an issue,
#% but if this annoys you, just remove the call to add-to-cleanup.
define make-tags
$(if $1,\
	ctags -a --c-kinds=+p --fields=+iaS $1)
$(if $2,\
	ctags -a --c++-kinds=+p --extras=+q --fields=+iaS $2)

$(call add-to-cleanup,tags)
endef

# $(call sort-cleanfile), internal
#% 
#% Used for erasing possible duplicates in the cleanfile. 'sort' is arguably not
#% the most fitting name, but 'clean-cleanfile' sounded a bit ridiculous.
#%
#% Awk is a great language, and is the second fastest way to do this particular
#% task. The quickest one, according to my testing, was Perl, by about 2-3 times.
#% The difference between the two for a 500 Mib file was only approx. two seconds.
#% Perl is pretty much ubiquitous, but on the off chance that someone only has
#% coreutils installed, I went with awk, even though it is a bit slower.
define sort-cleanfile
	$(shell awk '!seen[$$0]++' $(clean_file) > /tmp/$(clean_file);\
		mv /tmp/$(clean_file) $(clean_file))
endef

# $(call add-single-rule,$(target),$(file),$(flags)), internal
#%
#% Now we're getting into the core of this Makefile. This macro sets up rules for
#% the different files associated with a binary. The litany of evals at the start
#% are variables that are set up at parse time, essentially just to make writing
#% the rest of the macro easier. Everything could also be purely functionally
#% implemented, make is messy enough as is.
#%
#% local_object is the output file for the specified file. Note that $(suffix) in
#% this context only works for singular files, that caught me a bit off guard.
#%
#% local_compiler stores the string representation of whichever compiler the user
#% wants to use. It can even be changed at runtime, similar to $(CFLAGS), if that
#% need for whatever reason ever arises.
#%
#% global_flags_internal stores whether the file uses CFLAGS or CXXFLAGS,
#% obviously depending on if the file is C or C++.
#%
#% $1_$2_defined is a flag that informs the framework that a rule for this
#% target/source file combination. This allows us to add individual flags to
#% source files by calling $(add-entry) multiple times with the same files
#% without having to redefine rules, which would cause make to spit out
#% warnings.
#%
#% $1_$2_flags_internal is a variable that hold the flags to be used for this
#% particular target/file combination. At some point I considered only checking
#% if $1_$2_flags_internal was defined, instead of $1_$2_defined, but quickly
#% realized that some files might not use any flags at all, and as such, we need
#% a separate $1_$2_defined variable.
#%
#% $(local_object): $2 is the actual rule that is used for compiling the source
#% file into the object file. local_compiler and global_flags_internal are
#% expanded only at runtime, so that they can be modified at runtime. The rules
#% debug and lint utilize this feature.
#%
#% $(local_object).tags: $2 is the rule for generating a list of header files
#% for this file. Having this as a separate target enables us to generate tags
#% when files are updated, and saves some time compared to always running
#% through all files in the project. It does add some parsing time, but it's a
#% miniscule amount, and I consider it a good sacrifice. Note that we have to
#% touch a file by the name $(local_object).tags, as otherwise make would always
#% assume that the source files are newer than the target, and generate a header
#% list for all files. This file is stored in the output directory, so in theory
#% it could lead to unnecessary files in a (.deb|.rpm|.whatever) package, but you
#% would preferably run `make clean && make` before trying to package anything,
#% so I don't consider this a serious issue. As mentioned previously, C and
#% C++ files have to be handled slightly differently, so we chech if the file is
#% C or C++ and call their respective generators.
#%
#% The last bit is about generating dependencies. Dependencies are essentialy
#% files that tell make which files to recompile if one is changed. For example,
#% header files are usually included in several other files, and a change to a
#% header file should be reflected in every other file that includes it. The
#% method used here is modified from 'Managing Projects with GNU Make, 3rd
#% Edition'.
define add-single-rule
$(eval local_object := $(addprefix $(build_dir)/$1/,$(subst $(suffix $2),.o,$2)))
$(eval local_compiler := $(if $(filter .c,$(suffix $2)),CC,CXX))
$(eval global_flags_internal := $$(if $$(filter .c,$$(suffix $2)),CFLAGS,CXXFLAGS))

$1_$2_defined := true
$1_$2_flags_internal := $3

$(local_object): $2
	$$($(local_compiler)) $$($(global_flags_internal)) $$($1_flags_internal)\
		$$($1_$2_flags_internal) $4 -c $2 -o $(local_object)

$(local_object).tags: $2
	@echo Generating tags for $2
	@touch $(local_object).tags
	@$(if $(filter .c,$(suffix $2)),\
		$$(eval c_header_files += $$(call generate-c-headers,$1,$2)),\
		$$(eval cxx_header_files += $$(call generate-cxx-headers,$1,$2)))

$(eval local_dependency := $(subst .o,.d,$(local_object)))
$(eval dependencies += $(local_dependency))

$(local_dependency): $2
	@echo Generating dependencies for $2
	@$$(call make-depend,\
		$$^,$$@,$(addprefix $(build_dir)/$1/,$(subst $(suffix $2),.d,$2)),\
		$$($(global_flags_internal)) $$($1_flags_internal)\
		$$($1_$2_flags_internal))
endef

# $(call add-to-flags,$(target),$(file),$(flags)), internal
#%
#% This macro is expanded if there already exists a rule for the specified
#% target/source file combo. Called from add-rules.
define add-to-flags
$1_$2_flags_internal += $3
endef

# $(call add-rules,$(target),$(file),$(flags)), internal
#%
#% This macro checks whether the specified target/source file combo already has
#% a rule, and either adds a new rule or adds flags to the existing rule.
define add-rules
$(if $($1_$2_defined),\
	$(call add-to-flags,$1,$2,$3),\
	$(call add-single-rule,$1,$2,$3))
endef

# $(call call-add-entry,$(target),$(local_sources),$(include_dir),$(local_flags)), internal
#%
#% This macro is responsible for splitting the given list of source files into
#% individual files, for which rules can be generated. Also creates the
#% variables $1_sources_internal and $1_objects_internal if they don't exist,
#% and appends the respective sources and objects to them. At this point the
#% variables may contain duplicates. At the moment only $1_objects_internal is
#% used for generating tags files, but $1_sources_internal is still kept around
#% in case there comes a situation where we need to figure out if a certain
#% object file originally was a C or C++ file. A previous implementation of tag
#% generation used $1_sources_internal for this purpose.
#%
#% Adding the current directory to vpath is probably not strictly necessary, but
#% if you happen to have custom rules for preprocessors or something similar,
#% make might not be able to find them if we skip vpath. Depends on how your rules
#% are written, but this way is at least somewhat robust.
#%
#% At the end of the macro, the different rules for the sources are expanded and
#% evaluated.
define call-add-entry
vpath % $3

$$(if $$($1_sources_internal),,$$(eval $1_sources_internal := ))
$$(if $$($1_objects_internal),,$$(eval $1_objects_internal := ))

$1_sources_internal += $(addprefix $3/,$2)
$1_objects_internal += $(subst .c,.o,$(subst .cpp,.o,$(addprefix $(build_dir)/$1/$3/,$2)))

$(foreach source,$(addprefix $3/,$2),\
	$(eval $(call add-rules,$1,$(source),$4)))
endef

# $(call call-add-target,$(target),$(linker_flags),$(global_flags),$(library)), internal
#%
#% Set up final linking rules. First we define a variable by the name of
#% whatever target we're creating, and we set its value to the output file that
#% we want to generate. Note that this makefile places binaries in folders named
#% after the targets, this is because it makes separating build rules for
#% different targets massively. Some projects place their targets in the
#% top directory of their $(build_dir), but ar gets confused if there is a
#% folder by the same name as the library that's its trying to create, which
#% isn't preferable.
#%
#% Note that there isn't an explicit way to specify if a target should be
#% linked to another inside the same project. One way to do it would be to call
#% $(add-target,LIBRARY) first, and $(add-target,PROGRAM) afterwards and set
#% the linking flags as usual. This Makefile uses order-only-prerequisites, so 
#% the first target to be added will always be compiled first, as such ensuring
#% that the library exists before linking to it. You could also manually compile
#% the library first by running something like `make LIBRARY && make`, if the
#% previous method for some reason isn't possible.
#%
#% The libraries can either be of shared or static type, anything else will be
#% compiled as an executable.
define call-add-target
$1 := $(build_dir)/$1/$1
$1_flags_internal := $3
targets += $$($1)

$$($1): $$($1_objects_internal)
ifeq ($(strip $4),static)
	$(AR) rcs $$@ $$^
else ifeq ($(strip $4),shared)
	$(CXX) -shared $$^ -o $$@ $2
else 
	$(CXX) $$^ -o $$@ $2
endif
endef

# $(call add-entry,$(target),$(local_sources),$(dir),$(flags)), external
#%
#% One of the three API calls. This is just a beautifying wrapper for call-add-entry, which
#% does the hard lifting. The sole purpose of this macro is to avoid having to
#% write $(eval $(call call-add-entry,...)).
#% 
#% Note that you can call this macro on files already listed for a target to
#% append flags to their compilation, see
#% examples in src/source.mk and src/secondbin/source.mk.
#%
#% The arguments are:
#
# $(target)		- The target that the rest of the arguments should apply to.
#
# $(local_sources) 	- List of source files to be added to $(target).
# 			  Note that the files should preferably be in
# 			  basename format, i.e. file.c instead of
# 			  path/to/file.c. You can get clever with using paths,
# 			  but for simplicity's sake, don't.
#
# $(dir)		- Directory from which the sources are added. This is
# 			  important, as . If you have many targets in the
# 			  same project, it's not unheard of to have 
# 			  several main.* files. Arguably not great practice, but
# 			  it is what it is.
#
# $(flags)		- Flags that should be applied to the listed files.
define add-entry
$(eval $(call call-add-entry,$1,$2,$3,$4))
endef

# $(call add-progran,$(target),$(linker_flags),$(global_flags),$(library)),
# external
#%
#% Second external public API call. As with call-add-entry, purely cosmetics.
#%
#% This macro should only be called once per target, and one call per target.
#%
#% The arguments are:
#% $(target)		- The target that should be created. Note that this is
#% 			  not a list, just a singular name. make won't stop you
#% 			  from prividing a list, but it's undefined behaviour,
#% 			  and should be avoided.
#%
#% $(linker_flags)	- Flags that should be passed to the linker, if
#% 			  applicable.
#%
#% $(global_flags)	- Global flags that should be added to all files that
#% 			  are being compiled under this target. The same
#% 			  behaviour could be achieved with add-entry, but this
#% 			  is more convenient.
#%
#% $(library)		- Flag if this 'target' should actually be compiled
#% 			  into a library. Valid values are 'shared' and
#% 			  'static', anything else (including no value) will be
#% 			  treated as a typical executable.
define add-target
$(eval $(call call-add-target,$1,$2,$3,$4))
endef

# $(call prepare-clenup), internal
#%
#% This macro prepares the repo for cleanup. It adds the output directory to the
#% cleaning list, as well as the list itself. Lastly it calls sort-cleanfile,
#% which removes any duplicates from the cleaning list.
#%
#% See the 'clean' rule near the bottom of this file for more information about
#% why duplicates are removed.
define prepare-cleanup
$(call add-to-cleanup,$(build_dir))
$(call add-to-cleanup,$(clean_file))
$(call sort-cleanfile)
endef

# $(call prepare-tags), internal
#% 
#% As the name suggests, prepares the generation of tags. Essentially it just
#% creates two simplfy expanded variables, and gives the 'tags' rule a list of
#% files to scan for tags.
#%
#% $(c_header_files) and $(cxx_header_files) could just as well be defined at
#% the top of the line with the other global variables, but since they are only
#% used when creating tags, I felt it was more appropriate to create them along
#% with the tags.
define prepare-tags
$(eval c_header_files := )
$(eval cxx_header_files := )
$(foreach target,$(notdir $(targets)),\
	$(foreach object,$($(target)_objects_internal),\
	$(object).tags))
endef

# $(call prepare-lint), internal
#%
#% Generates a list of files that should be linted. In practice this just skips
#% the linking rules for each target.
#%
#% Note that make has built in $(LINT) rules, but they use a target called lint
#% that's not installed by default on (almost?) any platforms, which is why
#% we're linting in a more manual manner.
define prepare-lint
$(foreach target,$(notdir $(targets)),\
	$(foreach object,$($(target)_objects_internal),$(object)))
endef

# $(call prepare-makefile), internal
#%
#% This macro is run last in the parsing stage, and is responsible for removing
#% duplicates found in the target sources and objects, so they can be safely
#% used in the execution phase. Also create shorthand rules for the different
#% targets. For example, in this project, we can run `make exec` to only compile
#% the target exec.
#%
#% Note that the actual rule to compile exec is in the form
#% 'build/exec/exec: $(something)', which is why we have to create new rules
#% (last line of this macro) in the form 'exec: build/exec/exec' for example.
define prepare-makefile
$(foreach target,$(notdir $(targets)),\
	$(eval $(target)_sources_internal := $(sort $($(target)_sources_internal)))\
	$(eval $(target)_objects_internal := $(sort $($(target)_objects_internal))))
$(foreach rule,$(targets),$(eval $(notdir $(rule)): $(rule)))
endef

#% Include a configure file if there is one. This include statement must come
#% before any other, as include statements are processed in order.
-include $(configure)

#% Variable that will contain all targets, must be defined as a simple variable
#% before including any source files.
targets :=

#% Variable that wil contain all dependency files. Similarly to $(targets), this
#% variable must be defined as a sinple variable before including any source
#% files.
dependencies :=

#% Here is the fun part. With one simple include, we use everything we've
#% written to generate rules based on files included from this file. Definitely
#% take a look inside src/source.mk, as the smaller source.mk files still have
#% a fair bit of responsibility on their shoulders.
include src/source.mk

#% Having generated all necessary rules inside the previous include statement,
#% we can load all dependencies into memory. If there are no dependency files,
#% they will be generated.
#%
#% Note that in some cases dependencies will be generated when cleaning,
#% and I found that to be somewhat annoying, so I added a simple check for not
#% including dependencies when running debug.
ifneq ($(MAKECMDGOALS),debug)
include $(dependencies)
endif

#% Our first 'real' rule: all. This is the default rule, and will be executed
#% when calling just `make`. Note the pipe symbol that is used to indicate that
#% the targets listed should be built in the order they appear. This is crucial
#% for reasons listed in call-add-target.
all: | $(targets)

#% The 'clean' rule. This rule will hopefully remove all files generated by
#% make.
#%
#% In this Makefile I chose to use a file as a makeshift database for files and
#% folders that should be removed. Currently this Makefile is set up so that
#% items can be written over and over to the cleaning file, which can lead to
#% duplicates in the file. This is most probably not an issue, since at least
#% GNU coreutils rm 8.32 just happily ignores any and all duplicates. That being
#% said, I don't know if this is a matter of implementation or something that's
#% mentioned in the POSIX standard. I should look it up, but for now I'm going
#% by the assumption that some other rm might throw an error if it encounters a
#% file it has already deleted, so we remove any duplicates from the file by
#% calling prepare-cleanup.
#%
#% I sincerely doubt the cleanfile will ever grow large enough to cause any kind
#% of noticable slowdown, but in case that does happen, you can always add
#% prepare-cleanup to the end of 'all' or any rule, really.
clean:
	$(call prepare-cleanup)
	xargs $(RM) -r -- < $(clean_file)

#% 'debug' rule. This rule essentially just add the a couple flags to CFLAGS and
#% CXXFLAGS, after which it just defers the execution over to 'all'. This is why
#% we had to expand $(global_flags_internal) in the sort of funny looking way,
#% as otherwise these new flags wouldn't be appended to the compilation phase.
#%
#% Note that to compile all files again with the debug flags, you will have to
#% run `make clean` before calling `make debug`, otherwise only the changed
#% files will be compiled with debug information.
debug: CFLAGS += -DDEBUG -g
debug: CXXFLAGS += -DDEBUG -g
debug: all

#% 'lint': very similar to debug, except in this case tell the compiler to only
#% check the syntax of the files. No output files are produces, and the the linking
#% phase is also skipped. I doubt the order-only-prerequisites (the pipe symbol, |)
#% is strictly necessary, but just to be on the safe side I made lint behave the
#% same way as 'all' does.
#%
#% I've set up a separate command in Vim, which allows me to quickly lint the
#% files I've recently changed:
#% 	command Lint make lint
#%
#% This command just lints the files when I call :Lint, and still
#% allows me to build the project as normal with :make from inside Vim. Pretty nifty :D
#%
#% The same note about 'debug' applies here, but I sincerely doubt you would ever
#% want to lint every single file in the project.
lint: CFLAGS += -fsyntax-only
lint: CXXFLAGS += -fsyntax-only
lint: | $(call prepare-lint)

#% 'tags', run this rule when you want tags. If there already is a tags file,
#% the files that have been changed since tags was last run will be scanned for
#% changes and appended to the existing file. Otherwise a new file will be
#% generated from all source files. Again, not sure if order-only is necessary,
#% but to be on the safe side, it is included.
tags: | $(call prepare-tags)
	@$(call make-tags,$(sort $(c_header_files)),$(sort $(cxx_header_files)))

#% And finally, prepare the file for the execution phase.
$(call prepare-makefile)
