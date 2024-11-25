# Tic Tac Toe

A modern implementation of the classic Tic Tac Toe game built with Flutter. Play the timeless game of X's and O's with a clean, intuitive interface and smooth animations.

## Features

- Interactive 3x3 game board
- Multiple game modes:
  - Two player mode
  - Computer opponent with 3 difficulty levels:
    - Easy: Random moves
    - Medium: 70% smart moves, 30% random
    - Hard: Unbeatable AI using minimax algorithm
- Comprehensive scoring system
- Beautiful UI with:
  - Smooth animations
  - Particle effects
  - Gradient backgrounds
  - Shimmer effects
  - Victory celebrations
- Game settings drawer with:
  - Game mode selection
  - Difficulty settings
  - Statistics tracking
  - Score reset option
- Responsive design for all screen sizes
- Game state management
- Victory and draw detection

## Installation

You can download and install the APK directly:
- [Download APK](https://github.com/Rover1218/tic-tac-toe-app/releases/download/v1.1.0/app-release.apk)

To install:
1. Download the APK file on your Android device
2. Enable "Install from Unknown Sources" in your device settings
3. Open the APK file and follow the installation prompts

## Getting Started

1. Make sure you have Flutter installed on your machine
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the app

## How to Play

1. Launch the game
2. Open settings (gear icon) to:
   - Choose game mode (2 Players or vs Computer)
   - Select difficulty level for computer opponent
   - View statistics
3. Players take turns:
   - X always plays first
   - Tap any empty cell to make a move
   - In computer mode, AI will automatically respond
4. Game ends when:
   - Three symbols align (horizontal, vertical, or diagonal)
   - Board fills up (Draw)
5. Use 'New Game' button to start over
6. Track scores in the statistics section

## Technical Details

### Features Implementation
- Custom animations using:
  - AnimationController
  - Transform animations
  - Confetti effects
  - Shimmer effects
  - Pulse animations
- AI Implementation:
  - Minimax algorithm for hard difficulty
  - Random selection for easy mode
  - Hybrid approach for medium difficulty
- UI Components:
  - Gradient backgrounds
  - Custom animated buttons
  - Responsive layout
  - Settings drawer
  - Score tracking

### Dependencies
- flutter/material.dart
- dart:math
- confetti package

## Development

Requirements:
- Flutter SDK
- Android Studio / VS Code
- A mobile device or emulator