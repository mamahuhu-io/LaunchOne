#!/bin/bash

# LaunchOne.app DMG packaging script
# Use the create-dmg tool to package the app automatically

set -e  # Exit on any error

# Configuration variables
APP_NAME="LaunchOne"
APP_PATH="../target/LaunchOne.app"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
# User-visible version
VERSION=$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")
# Internal build version
BUILD=$(plutil -extract CFBundleVersion raw "$INFO_PLIST")
DMG_NAME="${APP_NAME}-${VERSION}-${BUILD}.dmg"
VOLUME_NAME="${APP_NAME}"
DMG_SIZE="100m"  # DMG size; adjust based on app size
ICON_PATH="../docs/assets/icon.png"

# Colored output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
    print_info "检查依赖..."

    if ! command -v create-dmg &> /dev/null; then
        print_error "create-dmg 未安装，请运行: brew install create-dmg"
        exit 1
    fi

    if ! command -v fileicon -h &> /dev/null; then
        print_error "fileicon 未安装，请运行: brew install fileicon"
        exit 1
    fi

    if [ ! -d "$APP_PATH" ]; then
        print_error "应用程序不存在: $APP_PATH"
        exit 1
    fi

    print_info "依赖检查通过"
}

# Clean previous DMG files
cleanup() {
    print_info "清理之前的 DMG 文件..."
    # Only clean DMG files with specific pattern; keep create-dmg auto-generated names
    rm -f "../target/"*.dmg
}

# Create DMG
create_dmg() {
    print_info "开始创建 DMG..."

    # Use the Homebrew create-dmg syntax
    create-dmg \
        --volname "$APP_NAME" \
        --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
        --window-pos 400 200 \
        --window-size 660 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 160 185 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 500 185 \
        ../target/$DMG_NAME \
        ../target/$APP_NAME.app/

    if [ $? -eq 0 ]; then
        print_info "DMG 创建成功: $DMG_NAME"
    else
        print_error "DMG 创建失败"
        exit 1
    fi
}

# Verify DMG
verify_dmg() {
    print_info "验证 DMG 文件..."

    if [ -f "../target/$DMG_NAME" ]; then
        DMG_SIZE=$(du -h "../target/$DMG_NAME" | cut -f1)
        print_info "DMG 文件大小: $DMG_SIZE"
        print_info "DMG 文件路径: $(pwd)../target/$DMG_NAME"
    else
        print_error "DMG 文件不存在: ../target/$DMG_NAME"
        exit 1
    fi
}

# Set DMG icon
set_dmg_icon() {
    print_info "开始设置 DMG 文件图标..."

    # Use the Homebrew create-dmg syntax
    fileicon set ../target/$DMG_NAME "$APP_PATH/Contents/Resources/AppIcon.icns"

    if [ $? -eq 0 ]; then
        print_info "设置 DMG 文件图标成功: $DMG_NAME"
    else
        print_error "设置 DMG 文件图标失败"
        exit 1
    fi
}

# Main function
main() {
    print_info "开始打包 $APP_NAME.app 为 DMG..."
    echo $DMG_NAME
    check_dependencies
    cleanup
    create_dmg
    verify_dmg
    set_dmg_icon

    print_info "打包完成！"
    print_info "DMG 文件: $DMG_NAME"
}

# Run main
main "$@"
