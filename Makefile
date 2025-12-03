.PHONY: build build-orgmos build-orgmai install install-local clean test

# Variables
BINARY_NAME=orgmos
CMD_DIR=./cmd/orgmos
DIST_DIR=./dist
LOCAL_BIN_DIR=~/.local/bin

# Crear directorio dist si no existe
$(DIST_DIR):
	@mkdir -p $(DIST_DIR)

# Build orgmos binary to dist/
build-orgmos: $(DIST_DIR)
	@echo "Building $(BINARY_NAME)..."
	@go build -o $(DIST_DIR)/$(BINARY_NAME) $(CMD_DIR)
	@chmod +x $(DIST_DIR)/$(BINARY_NAME)
	@echo "Build complete: $(DIST_DIR)/$(BINARY_NAME)"
	@mkdir -p $(LOCAL_BIN_DIR)
	@cp $(DIST_DIR)/$(BINARY_NAME) $(LOCAL_BIN_DIR)/$(BINARY_NAME)
	@chmod +x $(LOCAL_BIN_DIR)/$(BINARY_NAME)
	@echo "Copied to $(LOCAL_BIN_DIR)/$(BINARY_NAME)"

# Build orgmai binary to dist/
build-orgmai: $(DIST_DIR)
	@echo "Building orgmai..."
	@if ! command -v pyinstaller &> /dev/null; then \
		echo "Error: pyinstaller no está instalado"; \
		echo "Instala con: pip install pyinstaller"; \
		exit 1; \
	fi
	@pyinstaller --onefile --name orgmai --distpath $(DIST_DIR) orgmai.py
	@echo "Build complete: $(DIST_DIR)/orgmai"
	@mkdir -p $(LOCAL_BIN_DIR)
	@cp $(DIST_DIR)/orgmai $(LOCAL_BIN_DIR)/orgmai
	@chmod +x $(LOCAL_BIN_DIR)/orgmai
	@echo "Copied to $(LOCAL_BIN_DIR)/orgmai"

# Build both binaries
build: build-orgmos build-orgmai
	@echo "All binaries built in $(DIST_DIR)/"

# Install local: copy binaries from dist/ to ~/.local/bin
install-local:
	@echo "Installing binaries to $(LOCAL_BIN_DIR)..."
	@mkdir -p $(LOCAL_BIN_DIR)
	@if [ -f $(DIST_DIR)/$(BINARY_NAME) ]; then \
		cp $(DIST_DIR)/$(BINARY_NAME) $(LOCAL_BIN_DIR)/$(BINARY_NAME); \
		chmod +x $(LOCAL_BIN_DIR)/$(BINARY_NAME); \
		echo "Installed $(BINARY_NAME) to $(LOCAL_BIN_DIR)/"; \
	fi
	@if [ -f $(DIST_DIR)/orgmai ]; then \
		cp $(DIST_DIR)/orgmai $(LOCAL_BIN_DIR)/orgmai; \
		chmod +x $(LOCAL_BIN_DIR)/orgmai; \
		echo "Installed orgmai to $(LOCAL_BIN_DIR)/"; \
	fi
	@echo "Installation complete!"

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
	@rm -rf $(DIST_DIR)
	@rm -rf build/
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
	@echo "  build         - Build both binaries (orgmos and orgmai) in dist/ and copy to ~/.local/bin"
	@echo "  build-orgmos  - Build orgmos binary in dist/ and copy to ~/.local/bin"
	@echo "  build-orgmai  - Build orgmai binary in dist/ and copy to ~/.local/bin"
	@echo "  install-local - Copy binaries from dist/ to ~/.local/bin (without building)"
	@echo "  install       - Build, copy binaries, and create desktop entry"
	@echo "  clean         - Remove build artifacts"
	@echo "  test          - Run tests"
	@echo "  deps          - Update dependencies"
	@echo "  run           - Build and run menu"
	@echo "  help          - Show this help"

