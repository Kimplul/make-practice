current_dir 	:= $(source_dir)/code2
local_sources 	:= code2.c
$(eval $(call add-entry,exec,$(current_dir),$(local_sources)))
