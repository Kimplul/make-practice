include $(source_dir)/secondbin/source.mk
include $(source_dir)/code1/source.mk
include $(source_dir)/code2/source.mk

current_dir 	:= src
local_sources 	:= lib.c main.cpp
local_libraries := -ldl

#$(eval $(call add-entry,exec,$(current_dir),$(local_sources),$(local_libraries)))
$(call add-entry,exec,$(current_dir),$(local_sources),$(local_libraries))
$(call add-program,exec)

%.c: %.m4
	$(call add-to-cleanup,$@)
	m4 $^ > $@
