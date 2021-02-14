current_dir 	:= $(source_dir)/code1
local_sources 	:= code1.c
$(eval $(call add-entry,exec,$(current_dir),$(local_sources)))
