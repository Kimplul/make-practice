# Kiva template
configure	:= config.mk
build_dir 	:= build
cleanup		:=
clean_file	:= cleanup

CFLAGS = -Wall -Werror -Wextra
CXXFLAGS = -Wall -Werror -Wextra

all:

# $(call make-depend $(source-file),$(object-file),$(depend-file),$(flags))
# mildly unfortunate that we have to always check if the directory exists,
# as rules defined in "sources" are always run first
# but otherwise alright implementation
define make-depend
@echo "Generating dependencies for $1"
if [ ! -d $(dir $3) ];				\
then						\
	mkdir -p $(dir $3);			\
fi

echo -n "$3 " > $2 &&				\
	gcc -MM 				\
	-MP					\
	$4					\
	$(TARGET_ARCH)				\
	$1 >> $2
endef

# cpp needs --extras=+q, c requires that it is left out
define generate-tags
	gcc -M $1 $2	 	|\
	sed -e 's/[\\ ]/\n/g' 	|\
	sed -e '/^$$/d'		|\
	sed -e '/\.o:[ \t]*$$/d'|\
	ctags -L - -a --fields=+iaS $3;
endef

define generate-c-tags
	$(call generate-tags,\
		$(CFLAGS) $($1_$2_flags_internal) $($1_flags_internal),$2,--c-kinds=+p)
endef

define generate-cxx-tags
	$(call generate-tags,\
		$(CXXFLAGS) $($1_$2_flags_internal) $($1_flags_internal),$2,--c++-kinds=+p)
endef

define make-tags
$(foreach program,$(notdir $(programs)),\
	$(foreach source_file,$($(program)_sources_internal),\
		$(if $(filter .c,$(suffix $2)),\
		$(call generate-c-tags,$(program),$(source_file)),\
		$(call generate-cxx-tags,$(program),$(source_file)))
	)
)

$(call add-to-cleanup,tags)
endef

define add-to-cleanup
	$(shell echo $1 >> $(clean_file))
endef

define sort-cleanfile
	$(shell awk '!seen[$$0]++' $(clean_file) > /tmp/$(clean_file);\
		mv /tmp/$(clean_file) $(clean_file))
endef

# $(call add-single-rule,$(program),$(file),$(flags))
define add-single-rule
$(eval local_object := $(addprefix $(build_dir)/$1/,$(subst $(suffix $2),.o,$2)))
$(eval global_flags_internal := $(if $(filter .c,$(suffix $2)), $$(CFLAGS), $$(CXXFLAGS)))
$(eval local_compiler := $(if $(filter .c,$(suffix $2)), $$(CC), $$(CXX)))
$(eval substitution := $(subst .,_,$1))

$1_$2_defined := true
$1_$2_flags_internal := $3

$(local_object): $2
	$(local_compiler) $$(global_flags_internal) $$($1_flags_internal)\
		$$($1_$2_flags_internal) $4 -c $2 -o $(local_object)

$(eval local_dependency := $(subst .o,.d,$(local_object)))
$(eval dependencies += $(local_dependency))

$(local_dependency): $2
	@$$(call make-depend,\
		$$^,$$@,$(addprefix $(build_dir)/$1/,$(subst $(suffix $2),.d,$2)),\
		$$(global_flags_internal) $$($1_flags_internal) $$($1_$2_flags_internal))
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
