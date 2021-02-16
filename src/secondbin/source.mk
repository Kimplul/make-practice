current_dir := src/secondbin
local_sources := main.cpp

$(call add-entry,bin,$(local_sources),$(current_dir))
$(call add-program,bin)
