current_dir := src/secondbin
local_sources := main.cpp

$(eval $(call add-entry,bin,$(current_dir),$(local_sources)))
$(eval $(call add-program,bin))
