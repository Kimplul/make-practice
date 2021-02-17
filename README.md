# `make` is fun
This repo is for a pet project of mine, a `make` framework that aims to be as flexible and portable as possible, while sacrificing as little speed as possible.

## Features
+ Simple API. Just three calls!
+ Flexible. I swear, your deepest most deprived fantasies about repo composition are (probably) doable.
+ Relatively quick. While there are definitely faster and simpler Makefiles, they are typically written for a specific project, whereas this tries to be as plug-and-play as possible.
+ Rambling documentation.

## Drawbacks
+ Files with spaces are always an issue with Makefiles, and I haven't even attempted to add support for spaces. See discussion [here](http://savannah.gnu.org/bugs/?712) about some possible ways to work around this issue in your Makefiles.
+ If you for some godawful reason want to create two binaries with the exact same name (please don't), it won't work. There's a limit to flexibility.
+ If speed is your utmost priority, and you absolutely have to run `make clean && make` ten thousand times per second, then this is not the Makefile for you. For nomral usecases, you should be alright.
+ Rambling documentation.

## API
Just three calls:
+ `$(call add-target,$(target),$(linker_flags),$(global_flags),$(library))`
+ `$(call add-entry,$(target),$(local_sources),$(dir),$(flags))`
+ `$(call add-to-cleanup,$(item))`

More detailed usage information can be found in `Makefile`, and examples in `src/`. Look for files named `source.mk`, you can't miss them.

## Documentation
Essentially the Makefile itself and the example usage in `src/`.
The documentation is admittedly very verbose, as I wrote it from a perspective of having a discussion with someone and explaining why and how the different parts work. If you just want to see the actual macros and short descriptions on how to call them, run `grep -v ^#% Makefile`.
