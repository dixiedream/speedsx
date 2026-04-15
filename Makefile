APP_NAME ?= speedsx
VERSION ?= 1.0

ZIG ?= zig
BUILD_MODE ?= ReleaseSafe
TARGET ?= native
BUILD_PREFIX ?= ./zig-out

# Linux Vars
INSTALL_PREFIX ?= /usr/local
DESTDIR ?=

# Mac Os Vars
APP_BUNDLE = $(APP_NAME).app
APP_CONTENTS = $(APP_BUNDLE)/Contents
APP_MACOS = $(APP_CONTENTS)/MacOS
APP_RESOURCES = $(APP_CONTENTS)/Resources

# Windows Vars
WIN_TARGET ?= x86_64-windows-gnu
WIN_BUNDLE = $(APP_NAME)-win
WIN_EXE = $(APP_NAME).exe

.PHONY: all build clean mac win winbundle winzip

all: build

build:
	$(ZIG) build -Doptimize=$(BUILD_MODE) -Dtarget=$(TARGET)

clean:
	rm -rf $(BUILD_PREFIX) .zig-cache

# Linux
install: build
	install -Dm755 $(BUILD_PREFIX)/bin/$(APP_NAME) "$(DESTDIR)$(INSTALL_PREFIX)/bin/$(APP_NAME)"

uninstall:
	rm -f "$(DESTDIR)$(INSTALL_PREFIX)/bin/$(APP_NAME)"

# Mac Os
mac: build
	mkdir -p $(APP_MACOS)
	mkdir -p $(APP_RESOURCES)

	# Copy executable
	cp $(BUILD_PREFIX)/bin/$(APP_NAME) $(APP_MACOS)/$(APP_NAME)

	# Create Info.plist
	printf '%s\n' \
	'<?xml version="1.0" encoding="UTF-8"?>' \
	'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
	'<plist version="1.0">' \
	'<dict>' \
	'  <key>CFBundleName</key><string>$(APP_NAME)</string>' \
	'  <key>CFBundleExecutable</key><string>$(APP_NAME)</string>' \
	'  <key>CFBundleIdentifier</key><string>com.dixiedream.$(APP_NAME)</string>' \
	'  <key>CFBundleVersion</key><string>$(VERSION)</string>' \
	'  <key>CFBundlePackageType</key><string>APPL</string>' \
	'</dict>' \
	'</plist>' > $(APP_CONTENTS)/Info.plist

# Build a Windows executable
win:
	$(ZIG) build -Doptimize=$(BUILD_MODE) -Dtarget=$(WIN_TARGET)

# Create a distributable Windows folder
winbundle: win
	rm -rf $(WIN_BUNDLE)
	mkdir -p $(WIN_BUNDLE)
	cp zig-out/bin/$(WIN_EXE) $(WIN_BUNDLE)/$(WIN_EXE)

winzip: winbundle
	zip -r $(WIN_BUNDLE).zip $(WIN_BUNDLE)
