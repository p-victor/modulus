MODULE ?= test_module

.PHONY: build build-linux build-windows build-module watch release release-linux release-windows safe safe-linux safe-windows rebuild run run-release run-safe clean clean-linux clean-windows nuke

build:
	bash scripts/build.sh native debug

build-module:
	MODULE=$(MODULE) bash scripts/build.sh native debug module

watch:
	bash scripts/watch.sh

build-linux:
	bash scripts/build.sh linux debug

build-windows:
	bash scripts/build.sh windows debug

release:
	bash scripts/build.sh native release

release-linux:
	bash scripts/build.sh linux release

release-windows:
	bash scripts/build.sh windows release

safe:
	bash scripts/build.sh native safe

safe-linux:
	bash scripts/build.sh linux safe

safe-windows:
	bash scripts/build.sh windows safe

rebuild: clean build

run:
	bash scripts/run.sh $(MODULE)

run-release: release
	bash scripts/run.sh $(MODULE)

run-safe: safe
	bash scripts/run.sh $(MODULE)

clean:
	bash scripts/clean.sh all

clean-linux:
	bash scripts/clean.sh linux

clean-windows:
	bash scripts/clean.sh windows

nuke:
	bash scripts/clean.sh all nuke