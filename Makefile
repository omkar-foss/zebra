# Env variables for development/testing.
export NODE_ENV=testing
export API_KEY=secret_123
export PORT=3000
export IS_DEBUG=true

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
