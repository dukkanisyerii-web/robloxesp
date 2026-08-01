# ApexEngine

ApexEngine is a modular Lua framework for Roblox-oriented plugin development. It uses a lightweight plugin system with dependency injection, event dispatching, configuration-driven modules, and a clean bootstrap flow.

## Features

- Modular plugin architecture
- Central configuration system
- Event-driven communication with an internal event bus
- Runtime plugin lifecycle management
- Diagnostics, resilience, analytics, and recovery helpers
- Extensible structure for future feature modules

## Project Structure

```text
src/
  init.lua
  Core/
  Data/
  Plugins/
```

## Getting Started

1. Copy or open the project in Roblox Studio.
2. Place the contents of the `src` folder in your desired Lua environment.
3. Bootstrap the framework from `src/init.lua`.

## Development Notes

- Main bootstrap entry: `src/init.lua`
- Shared settings: `src/Data/Config.lua`
- Runtime modules: `src/Core/`
- Plugin implementations: `src/Plugins/`

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
