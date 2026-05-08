# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-05-08

Initial release.

### Added
- `Cluster.Strategy.HyParView` — a `libcluster` strategy that uses
  [`hyparview`](https://hex.pm/packages/hyparview) for membership and
  invokes `Node.connect/1` only for peers in the local active view.
  Combined with `-connect_all false`, this gives Elixir clusters
  partial-mesh BEAM distribution.
- Documentation: pre-flight checklist (`-connect_all false`), full
  topology config example, integration notes with other libcluster
  strategies.
- Tracks `:hyparview ~> 0.2` (hex).

[Unreleased]: https://github.com/b-erdem/libcluster_hyparview/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/b-erdem/libcluster_hyparview/releases/tag/v0.1.0
