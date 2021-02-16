# Kiva template
source_dir 	:= src
configure	:= config.mk
build_dir 	:= build
cleanup		:=
clean_file	:= cleanup

CFLAGS = -Wall -Werror -Wextra
CXXFLAGS = -Wall -Werror -Wextra

all:


# $(call make-depend $(source-file),$(object-file),$(depend-file))
# mildly unfortunate that we have to always check if the directory exists,
# as rules defined in "sources" are always run first
# but otherwise alright implementation
define make-depend
@echo "Generating dependencies for $1"
if [ ! -d $(dir $3) ];			\
then					\
	mkdir -p $(dir $3);			\
fi					\

echo -n "$3 " > $2 &&				\
	gcc -MM 				\
	-MP					\
	$4					\
	$(TARGET_ARCH)				\
	$1 >> $2
endef

#$(build_dir)/%.d: %.c
#	@$(call make-depend,$<,$@,$(subst .o,.d,$@))

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
		$(CFLAGS) $($1_$2_flags) $($1_flags),$2,--c-kinds=+p)
endef

define generate-cxx-tags
	$(call generate-tags,\
		$(CXXFLAGS) $($1_$2_flags) $($1_flags),$2,--c++-kinds=+p)
endef

define make-tags
$(foreach program,$(notdir $(programs)),\
	$(foreach source_file,$($(program)_sources),\
		$(if $(filter .c,$(suffix $2)),\
		$(call generate-cxx-tags,$(program),$(source_file)),\
		$(call generate-c-tags,$(program),$(source_file)))
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
local_object := $(addprefix $(build_dir)/,$(subst $(suffix $2),.o,$2))
global_flags := $(if $(filter .c,$(suffix $2)), CXXFLAGS, CFLAGS)
local_compiler := $(if $(filter .c,$(suffix $2)), $(CXX), $(CC))

$1_$2_flags := $3
$$(local_object): $2
	$$(local_compiler) $$($(global_flags)) $$($1_flags) $$($1_$2_flags) $4 -c $$^ -o $$@

local_dependency := $$(subst .o,.d,$$(local_object))
dependencies += $$(local_dependency)

$$(local_dependency): $2
	@$$(call make-depend,\
		$$^,$$@,$(addprefix $(build_dir)/,$(subst $(suffix $2),.d,$2)),\
		$$($(global_flags)) $$($1_flags) $$($1_$2_flags))
endef

define add-to-flags
$1_$2_flags += $3
endef

# $(call add-rules,$(program),$(file),$(flags))
define add-rules
ifndef $1_$2_flags
	$(call add-single-rule,$1,$2,$3)
else
	$(call add-to-flags,$1,$2,$3)
endif
endef

# $(call call-add-entry,$(program),$(local_sources),$(include_dir),$(local_flags))
define call-add-entry
vpath % $3

$1_sources += $(addprefix $3/,$2)

$1_objects +=$(subst .c,.o,$(subst .cpp,.o,$(addprefix $(build_dir)/$3/,$2)))

$(foreach source,$(addprefix $3/,$2),\
	$(eval $(call add-rules,$1,$(source),$4)))
endef

# $(call call-add-program,$(program),$(linker_flags),$(global_flags))
define call-add-program
$1 := $(build_dir)/$1
$1_flags := $3
programs += $$($1)

$$($1): $$($1_objects)
	$(CXX) $$^ -o $$@ $2
endef

# $(call add-entry,$(program),$(local_sources),$(dir_of_sources),$(flags))
define add-entry
$(eval $(call call-add-entry,$1,$2,$3,$4))
endef

# $(call add-progran,$(program),$(linker_flags),$(global_flags))
define add-program
$(eval $(call call-add-program,$1,$2,$3))
endef

define prepare-cleanup
$(call add-to-cleanup,$(build_dir))
$(call add-to-cleanup,$(clean_file))
$(call sort-cleanfile)
endef

-include $(configure)

programs :=
dependencies :=
include $(source_dir)/source.mk
include $(dependencies)

all: $(programs)

clean:
	xargs $(RM) -r < $(clean_file)

debug: CFLAGS += -DDEBUG -g
debug: CXXFLAGS += -DDEBUG -g
debug: all

lint: CFLAGS += -fsyntax-only
lint: CXXFLAGS += -fsyntax-only
lint: $(foreach t,$(notdir $(programs)),$($(t)_objects))

.PHONY: tags
tags:
	$(call make-tags)

$(foreach n,$(programs),$(eval $(notdir $(n)): $(n)))
$(call prepare-cleanup)
