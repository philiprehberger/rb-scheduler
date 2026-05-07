# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.0] - 2026-05-07

### Added
- `Scheduler#due_jobs(now: Time.now)` -- returns the array of jobs whose `due?` is true at the given time, useful for monitoring without starting the scheduler.

## [0.5.0] - 2026-04-16

### Added
- `Scheduler#next_runs(limit: 10, from: Time.now)` returns an array of `{ job_id:, job_name:, next_run_at: }` hashes sorted by `next_run_at` ascending across all scheduled jobs (interval, cron, and `run_at`); jobs that will never fire again after `from` are excluded, and passing `limit: nil` returns every upcoming run
- `Job#next_run_at(from)` returns the next `Time` this job will fire at or after `from`, or `nil` if it will never fire again

## [0.4.0] - 2026-04-15

### Added
- `Scheduler#cancel(name)` removes a named job from the scheduler
- `Scheduler#pause(name)`, `Scheduler#resume(name)`, and `Scheduler#paused?(name)` toggle per-job pause state without removing the job
- `Scheduler#run_at(time, &block)` schedules a one-shot job that fires once at a given `Time` and is removed after execution
- `Scheduler#job_count` returns the number of registered jobs
- `Scheduler#find_job(name)` looks up a job by name
- `Job#run_at` / `Job#run_at?` expose the one-shot target time
- `Job#paused?` reflects pause state; `Job#to_state` and `Job#restore_state` persist it

## [0.3.0] - 2026-04-09

### Added
- `Scheduler#on_error(&block)` callback receiving `(job, error)` when a job raises
- `Job#last_error` stores the most recent exception (cleared on next successful run)
- `Job#to_state` includes `last_error` message for persistence

## [0.2.2] - 2026-03-31

### Added
- Add GitHub issue templates, dependabot config, and PR template

## [0.2.1] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

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

[Unreleased]: https://github.com/philiprehberger/rb-scheduler/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/philiprehberger/rb-scheduler/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/philiprehberger/rb-scheduler/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/philiprehberger/rb-scheduler/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/philiprehberger/rb-scheduler/compare/v0.2.2...v0.3.0
[0.2.2]: https://github.com/philiprehberger/rb-scheduler/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/philiprehberger/rb-scheduler/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/philiprehberger/rb-scheduler/compare/v0.1.8...v0.2.0
[0.1.8]: https://github.com/philiprehberger/rb-scheduler/compare/v0.1.7...v0.1.8
[0.1.7]: https://github.com/philiprehberger/rb-scheduler/compare/v0.1.6...v0.1.7
[0.1.6]: https://github.com/philiprehberger/rb-scheduler/compare/v0.1.5...v0.1.6
[0.1.5]: https://github.com/philiprehberger/rb-scheduler/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/philiprehberger/rb-scheduler/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/philiprehberger/rb-scheduler/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/philiprehberger/rb-scheduler/compare/v0.1.0...v0.1.2
[0.1.0]: https://github.com/philiprehberger/rb-scheduler/releases/tag/v0.1.0
