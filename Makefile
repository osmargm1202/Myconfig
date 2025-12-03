.PHONY: build build-orgmos build-orgmai install clean test

# Variables
BINARY_NAME=orgmos
CMD_DIR=./cmd/orgmos
DIST_DIR=./dist

# Crear directorio dist si no existe
$(DIST_DIR):
	@mkdir -p $(DIST_DIR)

# Build orgmos binary to dist/
build-orgmos: $(DIST_DIR)
	@echo "Building $(BINARY_NAME)..."
	@go build -o $(DIST_DIR)/$(BINARY_NAME) $(CMD_DIR)
	@chmod +x $(DIST_DIR)/$(BINARY_NAME)
	@echo "Build complete: $(DIST_DIR)/$(BINARY_NAME)"

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

# Build both binaries
build: build-orgmos build-orgmai
	@echo "All binaries built in $(DIST_DIR)/"

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
	@echo "  build         - Build both binaries (orgmos and orgmai) in dist/"
	@echo "  build-orgmos  - Build orgmos binary in dist/"
	@echo "  build-orgmai  - Build orgmai binary in dist/"
	@echo "  install       - Create symlink in /usr/local/bin"
	@echo "  clean         - Remove build artifacts"
	@echo "  test          - Run tests"
	@echo "  deps          - Update dependencies"
	@echo "  run           - Build and run menu"
	@echo "  help          - Show this help"

