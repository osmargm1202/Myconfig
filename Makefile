.PHONY: build install clean test

# Variables
BINARY_NAME=orgmos
CMD_DIR=./cmd/orgmos

# Build the binary to temporary location
build:
	@echo "Building $(BINARY_NAME)..."
	@TEMP_BINARY=$$(mktemp); \
	BIN_DIR=$$HOME/.local/bin; \
	go build -o $$TEMP_BINARY $(CMD_DIR); \
	mkdir -p $$BIN_DIR; \
	mv $$TEMP_BINARY $$BIN_DIR/$(BINARY_NAME); \
	chmod +x $$BIN_DIR/$(BINARY_NAME); \
	echo "Build complete: $$BIN_DIR/$(BINARY_NAME)"

# Install: build and create desktop entry
install: build
	@echo "Creating desktop entry..."
	@mkdir -p ~/.local/share/applications
	@echo '[Desktop Entry]\nName=ORGMOS\nComment=Sistema de configuración ORGMOS\nExec=orgmos menu\nTerminal=true\nType=Application\nIcon=orgmos\nCategories=System;Utility;' > ~/.local/share/applications/orgmos.desktop
	@chmod +x ~/.local/share/applications/orgmos.desktop
	@echo "Installation complete! Binary installed to ~/.local/bin/$(BINARY_NAME)"

# Clean build artifacts (no longer needed as we build to temp, but keep for compatibility)
clean:
	@echo "Cleaning..."
	@go clean
	@echo "Clean complete"

# Run tests
test:
	@go test ./...

# Update dependencies
deps:
	@go mod tidy

# Run the application
run: build
	@./$(BINARY_NAME) menu

# Help
help:
	@echo "Available targets:"
	@echo "  build   - Build the binary"
	@echo "  install - Create symlink in /usr/local/bin"
	@echo "  clean   - Remove build artifacts"
	@echo "  test    - Run tests"
	@echo "  deps    - Update dependencies"
	@echo "  run     - Build and run menu"
	@echo "  help    - Show this help"

