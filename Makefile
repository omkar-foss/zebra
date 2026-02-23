# Env variables for development/testing.
export ZEBRA_TEST_OS_NODE_ENV=testing
export ZEBRA_TEST_OS_API_KEY=secret_123
export ZEBRA_TEST_OS_PORT=3000
export ZEBRA_TEST_OS_IS_DEBUG=true

.DEFAULT_GOAL := all
.PHONY: all build test run format clean

all: build

build:
	@echo "Build the project..."
	zig build

test:
	@echo "Running tests..."
	zig build test --summary all

run:
	@echo "Running locally..."
	zig run src/main.zig

format:
	@echo "Formatting source files..."
	zig fmt --check src/*

clean:
	@echo "Cleaning up..."
	rm -rf .zig-cache zig-out
