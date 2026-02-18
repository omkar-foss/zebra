.DEFAULT_GOAL := all
.PHONY: all build test run format clean

all: build

build:
	@echo "Build the project..."
	zig build

test:
	@echo "Running tests..."
	NODE_ENV=testing API_KEY=secret_123 IS_DEBUG=true PORT=3000 zig test src/tests.zig

run:
	@echo "Running locally..."
	NODE_ENV=testing API_KEY=secret_123 IS_DEBUG=true PORT=3000 zig run src/main.zig

format:
	@echo "Formatting source files..."
	zig fmt --check src/*

clean:
	@echo "Cleaning up..."
	rm -rf .zig-cache zig-out
