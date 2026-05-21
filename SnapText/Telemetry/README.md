# Telemetry in SnapText

This module implements on-device telemetry collection for product diagnostics and KPI tracking.

## What it tracks

Events are modeled in `TelemetryEventName` and include:
- capture/parsing lifecycle (`image_selected`, `parse_started`, `parse_succeeded`, `parse_failed`)
- export lifecycle (`export_started`, `export_succeeded`, `export_failed`)
- table flow (`table_detected`, `table_detection_failed`)
- UX/product signals (`camera_opened`, `parse_mode_switched`, `document_saved`, etc.)

## Privacy model

- Each event has a `PrivacyClassification` (`anonymous_metadata_only` or `sensitive_content_never_collect`).
- Session identity is a salted hash from a local UUID via `TelemetrySessionManager` (no raw user identifier is stored).
- Metadata is capped and lightly noised (`noise`) to reduce exact fingerprinting while keeping trends useful.

## Architecture

- `TelemetryManager` is the app-facing singleton API (`track`, `clear`, `snapshotKPI`, `exportURL`).
- `TelemetryQueue` is an actor-backed queue with bounded size and batch draining.
- `TelemetryStorage` persists queued events into `telemetry_queue.json` in the app documents directory.
- `TelemetryUploader` performs best-effort uploads (stub endpoint in this project).
- `TelemetryAnalytics` computes local KPI rollups for debug/UI use.

## Operational behavior

- Tracking is opt-in controlled by `telemetryEnabled`.
- Uploading is best-effort and resilient: failed uploads keep events queued.
- A telemetry debug screen (`TelemetryDebugView`) exposes queue state, failures, KPI snapshot, clear, and JSON export.

## Key files

- `SnapText/Telemetry/TelemetryCore.swift`
- `SnapText/Views/Telemetry/TelemetryDebugView.swift`
- `SnapTextTests/Telemetry/TelemetryTests.swift`
