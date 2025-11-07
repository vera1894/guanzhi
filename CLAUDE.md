# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Language Rule
- All responses from Claude Code should be in Chinese (Simplified) as specified in .rules/agent_rules.md
- Code comments may be in Chinese or English depending on context
- Technical terms may be in English but should include Chinese explanations when possible

## Project Overview
This is a SwiftUI iOS application called "guanzhi" that appears to be a social mapping application with camera functionality. The app allows users to capture photos/videos, view them on a map, and share content with others.

## Architecture
- **Main App Entry**: `guanzhiApp.swift` - Contains the main app structure with navigation stack
- **Core Models**:
  - `AppStateModel.swift` - Global app state management
  - `CameraModel.swift` - Camera functionality state
  - `LocationManager.swift` - Location services
  - Network models in `ModelsForNetwork/` for API communication
  - Map models in `ModelsForMap/` for map-related functionality
- **Views**: Organized in the `View/` directory with subdirectories for different sections:
  - `FrontPage/` - Main map and search views
  - `LoginViews/` - Authentication screens
  - `MyPages/` - User profile and settings
  - `UIElement/` - Reusable UI components
- **Camera Functionality**: Located in `CameraViews/` and `CaptureFunctions/` directories
- **Data**: Core Data models and user profile management in `Data/`

## Development Environment
- iOS deployment target: 17.0
- Swift project using SwiftUI
- Uses CocoaPods for dependency management
- Primary dependency: Alamofire for networking

## Common Development Tasks

### Building the Project
```bash
# Open the workspace in Xcode
open guanzhi.xcworkspace

# Or build from command line
xcodebuild -workspace guanzhi.xcworkspace -scheme guanzhi -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

### Dependency Management
```bash
# Install/update pods
pod install

# Update pods
pod update
```

### Project Structure Key Points
- Uses Core Data for local data persistence
- Follows MVVM pattern with ObservableObjects
- Uses Environment and EnvironmentObject for state management
- Navigation is handled through a custom NavigationCoordinator
- Location services integrated with map views
- Camera functionality implemented with AVFoundation