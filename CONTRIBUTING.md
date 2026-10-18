# Contributing to NOX WHISHPER RED

Thank you for your interest in contributing to **NOX WHISHPER RED**!

## Development Setup

1. **Prerequisites**:
   - macOS 14.0 (Sonoma) or newer.
   - Xcode 15+ / Command Line Tools with Swift 5.9+.
   - (Optional) [Ollama](https://ollama.ai) installed locally for offline inference.

2. **Clone & Build**:
   ```bash
   git clone https://github.com/Naveen57990/nox-whisper-red.git
   cd nox-whisper-red
   swift build
   ```

3. **Packaging the App**:
   ```bash
   ./package_app.sh
   ```
   This compiles the release binary, creates `NOX WHISHPER RED.app`, codesigns it with a designated identifier so macOS TCC permissions remain intact, and installs it to `/Applications`.

4. **Generating the DMG Installer**:
   ```bash
   ./package_dmg.sh
   ```

## Code Guidelines

- **Zero Noise Invariant**: NOX WHISHPER RED is strictly covert. Do not introduce any audio alerts or `NSSound` calls.
- **Screen Stealth Invariant**: Any window showing answers must set `sharingType = .none` so it remains invisible to screen recorders (Zoom, Teams, Meet).
- **Dual Engine Architecture**: Keep both Local Ollama (offline) and OpenAI-compatible Cloud APIs supported.
- Maintain format-aware parsing and clean fallback mechanisms.

## Submitting a Pull Request

1. Fork the repository and create your feature branch: `git checkout -b feature/my-feature`.
2. Commit your changes: `git commit -m "feat: add feature description"`.
3. Push to your branch: `git push origin feature/my-feature`.
4. Open a Pull Request on GitHub.
