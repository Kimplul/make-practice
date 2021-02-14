# Kiva template
source_dir 	:= src
configure	:= config.mk
build_dir 	:= build

CFLAGS = -Wall -Werror -Wextra
CXXFLAGS = -Wall -Werror -Wextra

all:

-include $(configure)

# $(call make-depend source-file,object-file,depend-file)
# mildly unfortunate that we have to always check if the directory exists,
# as rules defined in "sources" are always run first
# but otherwise alright implementation
define make-depend
@echo "Generating dependencies for $1"
for dir in $4;					\
do						\
	if [ ! -d $$dir ];			\
	then					\
		mkdir -p $$dir;			\
	fi					\
done

echo -n "$3 " > $2 &&				\
	gcc -MM 				\
	-MP					\
	$(CFLAGS)				\
	$(CPPFLAGS)				\
	$5					\
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

define make-tags
$(foreach n,$(notdir $(programs)),\
	$(if $($(n)_cfiles),$(call generate-tags,$($(n)_cfiles),$($(n)_cflags),--c-kinds=+p)))

$(foreach n,$(notdir $(programs)),\
	$(if $($(n)_cxxfiles),$(call generate-tags,$($(n)_cxxfiles),$($(n)_cxxflags),--c++-kinds=+p --extras=+q)))
endef

define append-files
ifeq ($(suffix $2),.c)
	$1_cfiles += $2
else
	$1_cxxfiles += $2
endif

endef

define call-add-entry
ifeq ($(origin $1_include_dirs), undefined)
	$1_include_dirs :=
	$1_output_dirs :=
	$1_sources :=
	$1_objects :=
	$1_cfiles :=
	$1_cxxfiles :=
	$1_cflags :=
	$1_cxxflags :=
	$1_libraries :=
endif

vpath % $2

$1_include_dirs += $2
$1_output_dirs += $(addprefix $(build_dir)/,$2)

local_sources := $(addprefix $2/,$3)
$1_sources += $$(local_sources)

$$(foreach n,$$(addprefix $2/,$3),\
	$$(eval $$(call append-files,$1,$$(n))))

local_objects := $$(subst .c,.o,$$(subst .cpp,.o,$3))
local_objects := $$(addprefix $(build_dir)/$2/,$$(local_objects))
$1_objects += $$(local_objects)

$1_cflags += $(addprefix -I ,$2)
$1_cxxflags += $$($1_cflags)

$1_libraries += $4
endef

define add-rules
local_object := $$(addprefix $(build_dir)/,$$(subst .c,.o,$$(subst .cpp,.o,$2)))

global_flags := $(if $(filter .c,$(suffix $2)), CXXFLAGS, CFLAGS)

$$(local_object): $2
	$3 $$($$(global_flags)) $4 -c $$^ -o $$@

local_dependency := $$(subst .o,.d,$$(local_object))
dependencies += $$(local_dependency)

$$(local_dependency): $2
	@$$(call make-depend,\
		$$^,$$@,$$(subst $$(suffix $2),.d,$2),\
		$$($1_output_dirs),$4)
endef

define call-add-program
$1 := $(build_dir)/$1
programs += $$($1)

$$($1): $$($1_objects)
	$(CXX) $$^ -o $$@ $$($1_libraries)

c_sources := $$(filter %.c,$$($1_sources))
cxx_sources := $$(filter %.cpp,$$($1_sources))

$$(foreach o,$$(c_sources),\
	$$(eval $$(call add-rules,$1,$$(o),$$(CC),$$($1_cflags))))
$$(foreach o,$$(cxx_sources),\
	$$(eval $$(call add-rules,$1,$$(o),$$(CXX),$$($1_cxxflags))))
endef

define add-entry
$(eval $(call call-add-entry,$1,$2,$3,$4))
endef

define add-program
$(eval $(call call-add-program,$1))
endef

programs :=
dependencies :=
include $(source_dir)/source.mk
include $(dependencies)

all: $(programs)

clean:
	$(RM) -r $(build_dir)

debug: CFLAGS += -DDEBUG -g
debug: CXXFLAGS += -DDEBUG -g
debug: all

lint: CFLAGS += -fsyntax-only
lint: CXXFLAGS += -fsyntax-only
lint: $(foreach t,$(notdir $(programs)),\
	$($(t)_objects))

.PHONY: tags
tags:
	@$(call make-tags)

$(foreach n,$(programs),\
	$(eval $(notdir $(n)): $(n)))
