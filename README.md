<p align="center">
  <img src="https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/assets/logo.webp" alt="Steam Debloat Logo" width="250"/>
</p>

<p align="center">
  <a href="https://github.com/mtytyx/Steam-Debloat/releases/latest">
    <img src="https://img.shields.io/github/v/release/mtytyx/Steam-Debloat?style=for-the-badge&logo=github&logoColor=white&labelColor=1F2937&color=4B5563" alt="Latest Release">
  </a>
  <a href="https://github.com/mtytyx/Steam-Debloat/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/mtytyx/Steam-Debloat?style=for-the-badge&logo=opensourceinitiative&logoColor=white&labelColor=1F2937&color=4B5563" alt="License">
  </a>
  <a href="https://github.com/mtytyx/Steam-Debloat/stargazers">
    <img src="https://img.shields.io/github/stars/mtytyx/Steam-Debloat?style=for-the-badge&logo=starship&logoColor=white&labelColor=1F2937&color=4B5563" alt="Stars">
  </a>
</p>

<p align="center">
  Optimize and streamline your Steam client with our customizable debloat solutions, designed for enhanced performance and efficiency.
</p>

## 📋 Table of Contents

- [🔍 Overview](#-overview)
- [✨ Features](#-features)
- [💻 System Requirements](#-system-requirements)
- [📥 Downloads](#-downloads)
- [🚀 Quick Start](#-quick-start)
- [🛠️ Troubleshooting](#️-troubleshooting)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)
- [🙏 Acknowledgments](#-acknowledgments)
- [💀 WARNING](#-warning)

## 🔍 Overview

Steam Debloat is a comprehensive toolkit designed to optimize and customize your Steam client on Windows. Our solution addresses common performance issues, reduces resource usage, and enhances the overall user experience by removing unnecessary components and streamlining processes.

## ✨ Features

- **🚀 Performance Optimization**: Significantly reduce Steam's resource footprint and improve startup times.
- **🎛️ Customizable Debloat Options**: Choose between different debloat levels to suit your needs.
- **🖼️ UI Enhancements**: Fix common UI issues, including friends list display problems.
- **🔒 Update Control**: Option to prevent automatic updates, giving you control over your Steam client version.
- **💾 Backup and Restore**: Built-in functionality to create backups before making changes, ensuring easy recovery if needed.
- **🛠️ PowerShell Script**: Advanced users can utilize our PowerShell script for more granular control and automation.

## 💻 System Requirements

- **Operating System**: Windows 7, 8, 8.1, 10, or 11
- **Architecture**: 64-bit
- **PowerShell**: Version 5.1 or higher (for advanced installation method)
- **Administrator Rights**: Required for installation and execution

## 📥 Downloads

<details>
  <summary><b>Steam Legacy 🌟</b></summary>

  This version offers a balanced optimization approach aimed at improving Steam's performance by reducing unnecessary background processes and components, while preserving essential functionality.

  ### Features:
  - ⚡ Optimizes startup times and reduces resource usage
  - 🧹 Removes non-essential components to enhance performance

  ### Pros and Cons:
  - ✅ Significant performance improvement with reduced system load
  - ✅ Minimal impact on core Steam functionality
  - ✅ Less frequent user prompts during installation
  
  - ❌ May not remove all bloatware
  - ❌ Possible residual components that could still affect performance

  ### Installation:
  1. **Download** the [Installer.bat](https://github.com/mtytyx/Steam-Debloat/releases/download/v2.5/Installer.bat)
  2. **Run** the installer as an administrator
  3. **Advanced Method** (PowerShell):
     ```powershell
     iex "& { $(iwr -useb 'https://raw.githubusercontent.com/mtytyx/Steam-Debloat/main/script/app.ps1') }"
     ```
</details>

<details>
  <summary><b>Fix Friends List UI 👥</b></summary>

  This option resolves issues with the Steam friends list UI, improving display and functionality.

  ### Steps:
  1. Download [QuickPatcher_Patch.zip](https://github.com/TiberiumFusion/FixedSteamFriendsUI/releases)
  2. Extract the contents to a folder on your PC
  3. Run `FixedSteamFriendsUI.exe`
  4. Click the **Install Patch** button
</details>

<details>
  <summary><b>Uninstall Steam Legacy 🔄</b></summary>

  Use this method to force Steam to update to the latest version and revert any changes made by the debloat process.

  ### Steps:
  1. Download [Uninstall Steam Legacy](https://github.com/mtytyx/Steam-Debloat/releases/download/v2.5/Uninstall-Steam-Legacy.bat)
  2. Run the file as an administrator
  3. Follow the on-screen instructions to complete the process
</details>

## 🚀 Quick Start

1. Choose your preferred option from the [Downloads](#-downloads) section
2. Run the downloaded file with administrator privileges
3. Follow the on-screen instructions to complete the installation or uninstallation process
4. For the Fix Friends List UI option, ensure you follow the steps in the extracted readme file

## 🛠️ Troubleshooting

 If there is an issue, please [open an issue](https://github.com/mtytyx/Steam-Debloat/issues/new) in our GitHub repository.

## 🤝 Contributing

We welcome contributions from the community! To contribute:

1. Fork the repository
2. Create a new branch (`git checkout -b feature/AmazingFeature`)
3. Make your changes and commit (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

Please read our [Contributing Guide](https://github.com/mtytyx/Steam-Debloat/blob/main/assets/CONTRIBUTING.md) for more details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/mtytyx/Steam-Debloat/blob/main/LICENSE) file for details.

## 🙏 Acknowledgments

- Special thanks to [TiberiumFusion](https://github.com/TiberiumFusion) for their contributions to the Friends List UI fix

---

### 💀 Warning 

1. There are steam scripts that many are intended to "optimize" but many do it by touching files like `config.vdf` and `loginusers.vdf` but really the only thing that works is to downgrade steam in case of optimizing steam to the limit or optimizing steam in a way safe with only parameters and optimizing 'steam.cfg' but from there there is nothing that optimizes steam more. Check all the files on [Virustotal](https://virustotal.com/) and don't get carried avarice by the greed that Steam consumes little.
2. Virustotal results
- Version to which steam is outdated [2022Dec](https://www.virustotal.com/gui/url/73d0c1e2bf9ca30701504a8ec1225502676b2f794d64d93c79945ba37b900051)
- Steam debloat source code [APP.PS1](https://www.virustotal.com/gui/file/efda4de8df6b082f53bbff59dc8cb14e4da9377259642c3f9c3b55714fe5b49b?nocache=1)

<p align="center">
  Made with ❤️ by my
</p>
