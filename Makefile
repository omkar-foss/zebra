# Env variables for development/testing.
export ZEBRA_TEST_NODE_ENV=testing
export ZEBRA_TEST_API_KEY=secret_123
export ZEBRA_TEST_PORT=3000
export ZEBRA_TEST_IS_DEBUG=true

.DEFAULT_GOAL := all
.PHONY: all build test run format clean

all: build

build:
	@echo "Build the project..."
	zig build

test:
	@echo "Running tests..."
	@printenv | grep -E 'ZEBRA_TEST' > .env_test
	zig build test --summary all

run:
	@echo "Running locally..."
	zig run src/main.zig

format:
	@echo "Formatting source files..."
	zig fmt --check src/*

clean:
	@echo "Cleaning up..."
	rm -rf .zig-cache zig-out .env_test
