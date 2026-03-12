.PHONY: build build-linux build-windows rebuild run clean clean-linux clean-windows nuke

build:
	bash scripts/build.sh native

build-linux:
	bash scripts/build.sh linux

build-windows:
	bash scripts/build.sh windows

rebuild: clean build

run:
	bash scripts/run.sh

clean:
	bash scripts/clean.sh all

clean-linux:
	bash scripts/clean.sh linux

clean-windows:
	bash scripts/clean.sh windows

nuke:
	bash scripts/clean.sh all nuke