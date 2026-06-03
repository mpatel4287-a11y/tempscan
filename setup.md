# TempScan Setup Guide 🛠️

This document outlines the step-by-step setup process to run the **TempScan** project on a brand-new Windows or Linux machine. Follow these instructions to set up your development environment, install all dependencies, and run the app.

---

## 📋 System Prerequisites Matrix

| Requirement | Windows | Linux (Ubuntu/Debian) |
|-------------|---------|------------------------|
| **Git** | [Git for Windows](https://git-scm.com/) | `sudo apt install git` |
| **Dart/Flutter SDK** | Stable Bundle / Git | Stable Bundle / Git / Snap |
| **C++ Compiler (Desktop)** | Visual Studio 2022 (with C++ workload) | `clang`, `cmake`, `ninja-build` |
| **Android Tooling** | Android Studio, Android SDK | Android Studio, Android SDK |
| **Java JDK** | JDK 17 (Included in Android Studio) | OpenJDK 17 |
| **IDE** | VS Code / Android Studio | VS Code / Android Studio |

---

## 🛠️ Step 1: Install System Dependencies

### 🪟 Windows Setup
1. **Install Git**: Download and run the [Git for Windows installer](https://git-scm.com/). Ensure `Git from the command line and also from 3rd-party software` is selected during installation.
2. **Install C++ Build Tools** (Required for Desktop/Flutter tooling):
   - Download and run the [Visual Studio Installer](https://visualstudio.microsoft.com/downloads/).
   - Select **Visual Studio Community 2022** (or professional/enterprise).
   - Under the **Workloads** tab, check the box for **Desktop development with C++**.
   - Complete the installation and reboot your PC.

### 🐧 Linux Setup
Open your terminal and run the following commands to install required system tools, build libraries, and desktop dependencies:
```bash
sudo apt update
sudo apt install -y curl git unzip xz-utils zip libglu1-mesa
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-dev
```

---

## 🚀 Step 2: Install Flutter SDK

The `pubspec.yaml` environment requires a Flutter/Dart SDK version compatible with `sdk: ^3.10.7` (Dart 3.x). We recommend using the latest **Stable** channel of Flutter.

### 🪟 Windows
1. **Download**: Download the latest stable Flutter SDK zip package from the [official Flutter Windows docs](https://docs.flutter.dev/get-started/install/windows/desktop).
2. **Extract**: Extract the zip file and place the `flutter` folder in a development directory (e.g., `C:\src\flutter`). 
   > [!WARNING]
   > Do **NOT** extract Flutter into directories like `C:\Program Files\`, as it requires administrator privileges and will fail during updates or CLI builds.
3. **Environment Variables**:
   - In the Windows Start menu, search for "env" and select **Edit the system environment variables**.
   - Click **Environment Variables...**.
   - Under **User variables**, select the **Path** variable and click **Edit...**.
   - Click **New** and add the full path to `flutter\bin` (e.g., `C:\src\flutter\bin`).
   - Click **OK** to close all dialogs.
4. **Verify**: Open a new Command Prompt or PowerShell window and run:
   ```cmd
   flutter --version
   ```

### 🐧 Linux
1. **Download & Extract**:
   Create a directory for your development tools and clone the stable Flutter channel:
   ```bash
   mkdir -p ~/development
   git clone https://github.com/flutter/flutter.git -b stable ~/development/flutter
   ```
2. **Add to PATH**:
   Add the following line to your `~/.bashrc`, `~/.zshrc`, or `~/.profile` file:
   ```bash
   export PATH="$PATH:$HOME/development/flutter/bin"
   ```
   Apply the changes:
   ```bash
   source ~/.bashrc
   ```
3. **Alternative Installation (Ubuntu Snap)**:
   ```bash
   sudo snap install flutter --classic
   ```
4. **Verify**: Open a terminal and run:
   ```bash
   flutter --version
   ```

---

## 🤖 Step 3: Set up Android Development Environment

Setting up Android is critical for scanning, camera, and PDF workflows.

1. **Download Android Studio**: Download and install [Android Studio](https://developer.android.com/studio).
2. **Run Setup Wizard**:
   - Launch Android Studio.
   - Follow the Setup Wizard to install the **Android SDK**, **Android SDK Command-line Tools**, and **Android Virtual Device (AVD) / Emulator**.
3. **Configure Java SDK**:
   - Android Studio comes bundled with its own OpenJDK.
   - If running builds from the CLI, ensure Java JDK 17 is installed.
     - Linux: `sudo apt install -y openjdk-17-jdk`
     - Windows: Download JDK 17 from [Oracle](https://www.oracle.com/java/technologies/downloads/) or [Adoptium](https://adoptium.net/).
4. **Accept Android Licenses (CRITICAL)**:
   Open a terminal/command prompt and run:
   ```bash
   flutter doctor --android-licenses
   ```
   Press `y` to accept every license agreement.

---

## 🔍 Step 4: Run Flutter Doctor

To ensure everything is correctly configured, run:
```bash
flutter doctor
```
Review the output. Make sure there are checkmarks (`[✓]`) next to **Flutter**, **Android toolchain**, and your target platforms (like **Visual Studio** or **Chrome**). Resolve any missing dependencies flagged by the tool.

---

## 💻 Step 5: Configure your IDE

### 📝 VS Code (Recommended)
1. Install [Visual Studio Code](https://code.visualstudio.com/).
2. Open VS Code, click on the **Extensions** icon on the sidebar (or press `Ctrl+Shift+X`).
3. Search for and install the **Flutter** extension (developed by `flutter.dev`). This will automatically install the **Dart** extension.

### ☕ Android Studio
1. Open Android Studio.
2. Go to **Plugins** (on the welcome screen, or via **Settings/Preferences -> Plugins**).
3. Search for **Flutter** in the Marketplace and click **Install**.
4. Restart Android Studio.

---

## 📥 Step 6: Clone and Initialize the Project

1. **Clone the Repository**:
   Open a terminal/command prompt and navigate to your workspace directory:
   ```bash
   git clone <your-repository-url>
   cd tempscan
   ```
2. **Fetch Dart/Flutter Dependencies**:
   Install all library dependencies specified in `pubspec.yaml`:
   ```bash
   flutter pub get
   ```
3. **Generate Native Configurations (Icons and Splash Screen)**:
   The app uses custom icons and a native dark splash screen. Generate them by running:
   ```bash
   # Generate Launcher Icons
   flutter pub run flutter_launcher_icons
   
   # Generate Native Splash Screen
   flutter pub run flutter_native_splash:create
   ```
   *(Note: You can also use `dart run` instead of `flutter pub run` on newer Flutter versions).*

---

## 🏃 Step 7: Run the Application

Connect a physical device via USB (with USB Debugging enabled) or start an emulator/simulator.

1. **List Available Devices**:
   ```bash
   flutter devices
   ```
2. **Run the App**:
   ```bash
   flutter run
   ```
   If multiple devices are connected, target a specific platform using `-d`:
   ```bash
   # Run on Android Emulator/Device
   flutter run -d android
   
   # Run as Windows Desktop Application
   flutter run -d windows
   
   # Run as Linux Desktop Application
   flutter run -d linux
   
   # Run on Web (Chrome browser)
   flutter run -d chrome
   ```

> [!NOTE]
> **AI Features (ML Kit OCR & Translation)**: Since Google ML Kit plugins primarily target Android and iOS, features such as automatic Text Recognition and Translation will function on mobile devices/emulators. On desktop platforms (Windows/Linux), these features may run in fallback mode or be inactive. For the full experience, running the application on an Android or iOS device/emulator is recommended.

---

## ⚠️ Troubleshooting & Common Issues

### 1. `Android SDK not found` or `Command-line Tools component is missing`
If `flutter doctor` complains about the Android SDK or cmdline-tools:
- Open Android Studio.
- Go to **Tools** -> **SDK Manager** (or Settings -> Appearance & Behavior -> System Settings -> Android SDK).
- Select the **SDK Tools** tab.
- Check the box for **Android SDK Command-line Tools (latest)**.
- Click **Apply** and let it download.
- Set the SDK path manually if needed:
  ```bash
  flutter config --android-sdk "path/to/android-sdk"
  ```

### 2. Gradle Build Failed / JVM Heap Memory / OutOfMemory
If your build fails due to Java or Gradle memory limits, or network timeouts:
- Run a project cleanup:
  ```bash
  flutter clean
  flutter pub get
  ```
- Make sure you are using Java 17. Run `java -version` to verify.

### 3. Windows Visual Studio Toolchain Missing
If you get errors compiling for Windows Desktop:
- Re-run the Visual Studio Installer.
- Double-check that **Desktop development with C++** is checked.
- On individual components inside that workload, verify that **MSVC v143 - VS 2022 C++ x64/x86 build tools (Latest)** and **Windows 10/11 SDK** are selected.
