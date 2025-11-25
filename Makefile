.PHONY: build install clean test

# Variables
BINARY_NAME=orgmos
BUILD_DIR=.
CMD_DIR=./cmd/orgmos

# Build the binary
build:
	@echo "Building $(BINARY_NAME)..."
	@go build -o $(BUILD_DIR)/$(BINARY_NAME) $(CMD_DIR)
	@echo "Build complete: $(BUILD_DIR)/$(BINARY_NAME)"

# Install: create symlink to binary in Myconfig
install: build
	@echo "Creating symlink to $(BINARY_NAME)..."
	@REPO_DIR=$$(cd $(BUILD_DIR) && pwd); \
	if [ -L /usr/local/bin/$(BINARY_NAME) ] || [ -f /usr/local/bin/$(BINARY_NAME) ]; then \
		sudo rm /usr/local/bin/$(BINARY_NAME); \
	fi; \
	sudo ln -s $$REPO_DIR/$(BINARY_NAME) /usr/local/bin/$(BINARY_NAME); \
	echo "Symlink created: /usr/local/bin/$(BINARY_NAME) -> $$REPO_DIR/$(BINARY_NAME)"
	@echo "Creating desktop entry..."
	@mkdir -p ~/.local/share/applications
	@echo '[Desktop Entry]\nName=ORGMOS\nComment=Sistema de configuración ORGMOS\nExec=orgmos menu\nTerminal=true\nType=Application\nIcon=orgmos\nCategories=System;Utility;' > ~/.local/share/applications/orgmos.desktop
	@chmod +x ~/.local/share/applications/orgmos.desktop
	@echo "Installation complete!"

# Clean build artifacts
clean:
	@echo "Cleaning..."
	@rm -f $(BUILD_DIR)/$(BINARY_NAME)
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

