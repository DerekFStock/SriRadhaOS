# SriRadhaOS

SriRadhaOS is a macOS-native developer utility focused on a simple question:

`Why does my Mac feel slow right now?`

The first feature is a lightweight resource observer that aims to surface the processes and system conditions most likely responsible for sluggishness during development work. Instead of forcing you to open Activity Monitor and hunt through raw metrics, the goal is to provide a calm, always-available signal from the menu bar.

## Vision

SriRadhaOS is not trying to replace macOS or clone Activity Monitor.

The long-term idea is to build a focused operating layer for developers:

- understand system slowdowns quickly
- surface the most likely cause, not just the loudest metric
- provide lightweight, glanceable visibility from the desktop
- grow over time into a richer system-awareness toolset

The first step is a CLI-first prototype backed by native macOS-friendly architecture.

## First Feature

The initial resource observer is planned to:

- sample local system resource usage continuously
- identify top CPU-heavy processes
- grow into memory, swap, disk, and UI pressure detection
- produce a short diagnosis of what is likely affecting responsiveness

Planned examples:

- `Xcode indexing is driving CPU pressure`
- `Memory pressure is high and swap is active`
- `Simulator and WindowServer are contributing to UI lag`

## Tech Direction

The project is being built with:

- `Swift`
- a `Swift Package` for core logic and CLI iteration
- a future native macOS menu bar app using `AppKit` and optionally `SwiftUI`

This structure keeps the core logic easy to build and test from the command line while staying aligned with a proper macOS app architecture.

## Project Status

Current status:

- planning docs are in place
- Swift package scaffolding is being established
- first milestone is a CPU-focused CLI prototype

Near-term roadmap:

1. scaffold the package structure
2. build a CLI sampler for total CPU and top processes
3. add scoring and diagnosis logic
4. wrap the core engine in a native macOS menu bar app

## Repository Layout

```text
SriRadhaOS/
  README.md
  Package.swift
  docs/
  Sources/
    ResourceObserverCore/
    ResourceObserverCLI/
  Tests/
    ResourceObserverCoreTests/
```

## Getting Started

Once the package scaffold is in place, the main development loop will be:

```bash
swift build
swift test
swift run ResourceObserverCLI
```

The CLI will be the fastest place to validate the sampling and diagnosis engine before the desktop UI is added.

## Documentation

- [MVP Specification](./docs/mvp-specification.md)
- [Implementation Plan](./docs/implementation-plan.md)

## Contributing

The repo is being built in small, incremental steps. Clear commits, focused milestones, and public documentation are part of the process from the beginning.
