.PHONY: build install clean test

# Variables
BINARY_NAME=orgmos
CMD_DIR=./cmd/orgmos
DIST_DIR=./

# Build orgmos binary
build:
	@echo "Building $(BINARY_NAME)..."
	@go build -o $(DIST_DIR)/$(BINARY_NAME) $(CMD_DIR)
	@chmod +x $(DIST_DIR)/$(BINARY_NAME)
	@echo "Build complete: $(DIST_DIR)/$(BINARY_NAME)"


# Install: build and create desktop entry
install: build
	@echo "Creating desktop entry..."
	@mkdir -p ~/.local/share/applications
	@echo '[Desktop Entry]\nName=ORGMOS\nComment=Sistema de configuración ORGMOS\nExec=orgmos menu\nTerminal=true\nType=Application\nIcon=orgmos\nCategories=System;Utility;' > ~/.local/share/applications/orgmos.desktop
	@chmod +x ~/.local/share/applications/orgmos.desktop
	@echo "Installation complete! Binary installed to ~/.local/bin/$(BINARY_NAME)"

# Clean build artifacts
clean:
	@echo "Cleaning..."
	@go clean
	@rm -rf build/
	@echo "Clean complete"


# Update dependencies
deps:
	@go mod tidy

# Run the application
run: build
	@./$(BINARY_NAME) menu

# Help
help:
	@echo "Available targets:"
	@echo "  build         - Build binary"
	@echo "  install       - Build and create desktop entry"
	@echo "  clean         - Remove build artifacts"
	@echo "  run           - Build and run menu"
	@echo "  help          - Show this help"
