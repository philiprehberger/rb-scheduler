# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-03-28

### Added
- Job dependencies via `depends_on:` option to run jobs only after a named dependency completes
- Conditional scheduling via `if:` option to skip execution based on a lambda condition
- Job result chaining via `input_from:` option to pass output of one job as input to the next
- Timezone support for cron expressions via `timezone:` option with named timezones and UTC offsets
- Job persistence with `save_state` and `load_state` methods for crash recovery
- Distributed scheduling awareness with leader election via file lock (`enable_leader_election`)
- Job naming via `name:` option for interval and cron jobs

## [0.1.8] - 2026-03-26

### Changed
- Add Sponsor badge to README
- Fix License section format
- Sync gemspec summary with README


## [0.1.7] - 2026-03-24

### Fixed
- Align README one-liner with gemspec summary

## [0.1.6] - 2026-03-24

### Fixed
- Standardize README code examples to use double-quote require statements

## [0.1.5] - 2026-03-22

### Changed
- Expand test coverage

## [0.1.4] - 2026-03-21

### Fixed
- Standardize Installation section in README

## [0.1.3] - 2026-03-20

### Changed
- Expand README with detailed API documentation and usage examples

## [0.1.2] - 2026-03-16

### Changed
- Add License badge to README
- Add bug_tracker_uri to gemspec
- Add Requirements section to README

## [0.1.0] - 2026-03-15

### Added
- Initial release
- Cron expression parsing (5-field standard)
- Interval-based scheduling
- Overlap prevention
- Graceful shutdown with in-flight completion
