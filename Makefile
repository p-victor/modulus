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

build-test-modules:
	MODULE=mod_a bash scripts/build.sh native debug module
	MODULE=mod_b bash scripts/build.sh native debug module
	MODULE=mod_c bash scripts/build.sh native debug module
	MODULE=mod_d bash scripts/build.sh native debug module
	MODULE=mod_e bash scripts/build.sh native debug module

# Diamond graph: a→(b,c), b→d, c→e
# Passed in scrambled order to verify topo sort.
# Valid init orders: d/e before b/c, b/c before a.
# Valid shutdown orders: reverse of init.
test-manifest: build build-test-modules
	./build/linux_amd64/bin/modulus \
		build/linux_amd64/modules/mod_a.so \
		build/linux_amd64/modules/mod_c.so \
		build/linux_amd64/modules/mod_d.so \
		build/linux_amd64/modules/mod_b.so \
		build/linux_amd64/modules/mod_e.so

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