# `make` is fun
This repo is for a pet project of mine, a flexible `make` framework that aims to be as flexible and portable as possible, while sacrificing as little speed as possible.

## Features
+ Simple API. Just three calls!
+ Flexible. I swear, your deepest most deprived fantasies about repo composition are (probably) doable.
+ Relatively quick. While there are definitely faster and simpler Makefiles, they are typically written for a specific project, whereas this tries to be as plug-and-play as possible.
+ Rambling documentation

## API
Just three calls:
+ `$(call add-target,$(target),$(linker_flags),$(global_flags),$(library))`
+ `$(call add-entry,$(target),$(local_sources),$(dir),$(flags))`
+ `$(call add-to-cleanup,$(item))`

More detailed usage information can be found in `Makefile`, and examples in `src/`. Look for files named `source.mk`, you can't miss them.

## Documentation
The documentation is admittedly fairly rambly, as I wrote it from a perspective of having a discussion with someone and explaining why and how the different parts work. If you just want to see the actual macros and short descriptions on how to call them, run `grep -v ^#% Makefile`.
