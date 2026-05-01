# MVP Specification: macOS Resource Observer

## 1. Product Summary

The first feature for SriRadhaOS is a small macOS-native utility that helps identify what is making the machine feel slow in real time.

The utility should live in the macOS menu bar and surface a compact, always-available view of the system's current resource pressure. Instead of only showing raw usage, it should help the developer understand which processes are the most likely cause of sluggishness.

## 2. Problem Statement

When the machine becomes slow during development, the built-in tools are often too slow to open, too broad, or too noisy. The user wants a constant lightweight signal in the upper-right area of the desktop that answers:

- What is stressing the machine right now?
- Is the bottleneck CPU, memory, disk, or system UI?
- Which processes are most likely responsible?
- Did something change recently that explains the slowdown?

## 3. Primary User

The first user is a macOS developer working in tools such as:

- Xcode
- iOS Simulator
- browsers
- terminal sessions
- git tooling
- indexing and sync services

## 4. MVP Goal

Build a small native macOS utility that:

- samples local system resource usage continuously
- ranks the top likely sources of slowdown
- displays the current state in a menu bar interface
- can be developed and partially tested from the CLI

## 5. Non-Goals for V1

The first version should not try to:

- replace Activity Monitor completely
- inspect kernel scheduling internals directly
- kill or manage processes automatically
- predict future slowdowns
- support non-macOS platforms
- require private Apple APIs

## 6. User Experience

### Menu Bar Presence

The app should place a small status item in the menu bar. The initial display can be simple, for example:

- a text label such as `CPU 42%`
- a compact combined score such as `Load 68`
- a colored status dot for calm, warning, or high pressure

### Popover or Menu

When the user clicks the menu bar item, they should see:

- overall CPU usage
- memory pressure summary
- swap activity summary
- disk activity summary
- top 3 to 5 likely offending processes
- a one-line interpretation of the current state

Example interpretations:

- `Xcode indexing is driving CPU pressure`
- `Memory pressure is high and swap is active`
- `Simulator and WindowServer are contributing to UI lag`
- `Disk activity spiked in the last 30 seconds`

## 7. Core Functional Requirements

### FR1: Continuous Sampling

The system should sample metrics on a fixed interval, likely every 1 to 2 seconds.

### FR2: System Metrics

The MVP should collect:

- total CPU usage
- per-process CPU usage
- memory pressure indicators
- swap usage or swap activity if available
- disk read/write activity if available

### FR3: Process Ranking

The MVP should maintain a ranked list of likely culprits based on resource impact.

Initial ranking can be heuristic-based using:

- current CPU usage
- memory footprint
- recent growth in memory footprint
- recent disk activity when available
- whether the process appears during a pressure spike

### FR4: Likely Cause Summary

The UI should generate a short diagnosis string from the sampled state.

### FR5: Short-Term History

The app should store a rolling in-memory history window, such as the last 60 to 120 seconds, so it can detect sudden changes instead of only showing a single moment.

### FR6: Low Overhead

The app should avoid becoming a source of slowdown itself. Sampling should stay lightweight, and the UI should update efficiently.

## 8. Suggested Technical Direction

### Platform Choice

For macOS, the correct platform choice is:

- `Swift`
- native macOS frameworks
- menu bar app architecture

### UI Stack

Recommended:

- `AppKit` for the menu bar status item and app lifecycle
- `SwiftUI` for the popover content if desired

This hybrid approach is practical because AppKit remains the most direct way to manage menu bar apps, while SwiftUI can make the panel faster to iterate on.

### Sampling Layer

Keep the resource sampler separate from the UI. This makes it easier to:

- run and test logic from the CLI
- unit test heuristic scoring
- later reuse the engine in a richer app

### Build and Test Path

The project should support:

- normal Xcode development
- CLI builds with `xcodebuild` or `swift build`
- CLI test runs for the non-UI logic

## 9. Proposed Architecture

Split the system into four small layers:

### 1. Sampler Engine

Responsible for reading process and system metrics on an interval.

### 2. Scoring Engine

Responsible for turning raw measurements into a ranked list of probable causes.

### 3. State Store

Responsible for:

- current snapshot
- rolling history
- derived diagnosis text

### 4. Menu Bar UI

Responsible for:

- status item display
- popover rendering
- user-triggered refresh or inspection

## 10. Data Model for the MVP

Possible starting models:

### SystemSnapshot

- timestamp
- total CPU usage
- memory pressure level
- swap usage
- disk throughput
- top processes

### ProcessSnapshot

- pid
- process name
- cpu percent
- memory bytes
- disk activity if available
- impact score

### Diagnosis

- summary text
- primary bottleneck type
- confidence score

## 11. MVP Heuristics

The first version does not need machine learning. Simple rules are enough.

Examples:

- if one process dominates CPU for multiple samples, mark CPU bottleneck
- if memory pressure is elevated and swap grows, mark memory bottleneck
- if UI feels slow and `WindowServer` rises with Simulator or Xcode load, note graphics or UI pressure
- if disk activity spikes alongside indexing or build tools, mark disk pressure

## 12. Risks and Unknowns

- some deeper metrics may be awkward to obtain cleanly through public APIs
- process-level disk data may require fallback strategies or reduced scope in V1
- menu bar text can become noisy if too much information is shown
- “highest resource use” is not always the same as “true cause of slowdown”

## 13. Success Criteria for V1

The MVP is successful if it can:

- run quietly in the menu bar
- show live CPU and pressure state
- list the top likely resource-heavy processes
- produce a short, reasonable explanation for why the machine feels slow
- help the user spot issues faster than opening Activity Monitor
