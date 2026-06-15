# Convenience tasks for the HockeyTracker project.
#
# The Xcode project is generated from `project.yml` with XcodeGen, so it is not
# committed to git. Run `make project` once after cloning (and any time you add
# or remove source files) to (re)generate `HockeyTracker.xcodeproj`.

PROJECT := HockeyTracker.xcodeproj
SCHEME_IOS := HockeyTracker
SCHEME_WATCH := HockeyTrackerWatch

.PHONY: help project open clean build-ios build-watch

help:
	@echo "Available targets:"
	@echo "  make project     Generate $(PROJECT) from project.yml (needs xcodegen)"
	@echo "  make open        Generate the project and open it in Xcode"
	@echo "  make build-ios   Build the iPhone app for the simulator"
	@echo "  make build-watch Build the Apple Watch app for the simulator"
	@echo "  make clean       Remove generated project and build output"

project:
	@command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen not found. Install it with: brew install xcodegen"; exit 1; }
	xcodegen generate

open: project
	open $(PROJECT)

build-ios: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME_IOS) \
		-destination 'generic/platform=iOS Simulator' build

build-watch: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME_WATCH) \
		-destination 'generic/platform=watchOS Simulator' build

clean:
	rm -rf $(PROJECT) build DerivedData
