# Implementation Plan: macOS Resource Observer

## 1. Recommended Build Strategy

Use a two-track approach:

- build the core logic as plain Swift modules that can be run and tested from the CLI
- wrap that logic in a native macOS menu bar app for the real desktop experience

This gives the project the correct native platform while still keeping development fast from the command line.

## 2. Suggested Phases

### Phase 0: Project Scaffold

Goal:

Create the initial project structure and choose the build system.

Recommended direction:

- start with a Swift package for the core engine
- add a macOS app target after the engine shape is stable

Suggested structure:

```text
SriRadhaOS/
  README.md
  docs/
  Sources/
    ResourceObserverCore/
    ResourceObserverCLI/
  Tests/
    ResourceObserverCoreTests/
  App/
    ResourceObserverMenuBar/
```

Why this structure:

- `ResourceObserverCore` contains sampling, scoring, and models
- `ResourceObserverCLI` provides a quick terminal runner for local iteration
- `ResourceObserverMenuBar` hosts the native macOS UI

### Phase 1: CLI Sampler Prototype

Goal:

Prove that we can gather useful data before building UI polish.

Deliverables:

- sample total CPU usage every 1 to 2 seconds
- sample top processes by CPU
- print a rolling snapshot to the terminal
- keep a short history buffer in memory

CLI output can start simple, for example:

```text
Load: Elevated
CPU: 74%
Memory Pressure: Normal
Top Processes:
1. Xcode 48%
2. Simulator 22%
3. WindowServer 9%
Diagnosis: Xcode and Simulator are driving CPU pressure.
```

### Phase 2: Scoring and Diagnosis

Goal:

Turn raw numbers into useful interpretation.

Deliverables:

- define an `impact score`
- rank processes by likely responsibility
- generate one-line diagnosis text
- add tests for scoring behavior

Start with rules, not advanced analytics.

### Phase 3: Native Menu Bar App

Goal:

Move the output into the upper-right corner of the desktop.

Deliverables:

- menu bar status item
- popover or menu panel
- live refresh from core engine
- process list and diagnosis view

The status item should remain very small and calm. The detail belongs in the popover.

### Phase 4: Memory and Disk Expansion

Goal:

Improve beyond simple CPU visibility.

Deliverables:

- memory pressure display
- swap tracking
- disk activity display where practical
- better diagnosis when CPU is not the main problem

### Phase 5: History and Event Detection

Goal:

Explain changes over time, not just the current moment.

Deliverables:

- 60 to 120 second rolling history
- pressure spike detection
- “what changed recently” messaging

## 3. Step-by-Step Plan

### Step 1

Create a Swift package with:

- one core library target
- one CLI executable target
- one test target

### Step 2

Implement core models:

- `SystemSnapshot`
- `ProcessSnapshot`
- `Diagnosis`
- `ResourcePressureLevel`

### Step 3

Implement a sampler service that gathers:

- total CPU
- top processes by CPU

Keep the first version narrow. Do not block on disk or memory edge cases.

### Step 4

Implement a rolling history buffer for the last N samples.

### Step 5

Implement a small scoring engine that:

- calculates impact scores
- ranks processes
- produces a one-line diagnosis

### Step 6

Create a CLI runner that:

- samples every 2 seconds
- prints a compact report
- can run continuously during local development

### Step 7

Add unit tests for:

- score calculation
- diagnosis selection
- history behavior

### Step 8

Create the menu bar app shell using native macOS frameworks.

### Step 9

Bind the menu bar UI to the core engine and display:

- status summary
- top processes
- diagnosis text

### Step 10

Add memory pressure and swap awareness.

## 4. CLI-First Development Workflow

The user wants to build for macOS but run and test through the CLI. The most practical workflow is:

### During core development

Use:

- `swift build`
- `swift test`
- `swift run`

This is ideal for sampler logic, scoring, history, and diagnosis behavior.

### During app integration

Use:

- `xcodebuild`

This is ideal once the menu bar app target exists and needs native app packaging or signing-related behavior.

## 5. Platform Recommendation

The best long-term platform choice for this idea is:

- native macOS app
- `Swift`
- `AppKit` with optional `SwiftUI`

The best short-term implementation choice is:

- core logic in a Swift package
- terminal output through a CLI executable

This lets the project start small without painting itself into the wrong architecture.

## 6. Design Principles

- prefer public APIs
- keep the sampler lightweight
- separate data collection from display
- favor explanations over raw metrics
- optimize for glanceability, not dashboard bloat

## 7. Immediate Next Build Step

The best next move after this documentation is to create:

- `Package.swift`
- `Sources/ResourceObserverCore/`
- `Sources/ResourceObserverCLI/`
- `Tests/ResourceObserverCoreTests/`

Then implement a narrow CPU-only prototype that runs in the terminal.

## 8. Definition of Done for the First Working Prototype

The first working prototype should:

- run from the CLI on macOS
- sample every 2 seconds
- show total CPU usage
- show the top 3 CPU-heavy processes
- print a one-line diagnosis
- exit cleanly

Once that works, the menu bar UI becomes much lower risk.
