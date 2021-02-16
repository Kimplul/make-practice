include src/secondbin/source.mk
include src/code1/source.mk
include src/code2/source.mk

include_dirs 	:= src
local_sources 	:= lib.c main.cpp
local_flags	:= -DALL

$(call add-entry,exec,$(local_sources),$(include_dirs),$(local_flags))
$(call add-entry,exec,main.cpp,$(include_dirs),-DSINGLE_FLAG)

linker_flags 		:= -ldl
exec_global_flags 	:= $(addprefix -I ,src src/code1 src/code2) $(EXTRA_FLAGS)

$(call add-program,exec,$(linker_flags),$(exec_global_flags))

%.c: %.m4
	$(call add-to-cleanup,$@)
	m4 $^ > $@
