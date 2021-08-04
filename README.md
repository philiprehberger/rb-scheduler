# philiprehberger-scheduler

[![Tests](https://github.com/philiprehberger/rb-scheduler/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-scheduler/actions/workflows/ci.yml) [![Gem Version](https://img.shields.io/gem/v/philiprehberger-scheduler)](https://rubygems.org/gems/philiprehberger-scheduler) [![GitHub release](https://img.shields.io/github/v/release/philiprehberger/rb-scheduler)](https://github.com/philiprehberger/rb-scheduler/releases) [![GitHub last commit](https://img.shields.io/github/last-commit/philiprehberger/rb-scheduler)](https://github.com/philiprehberger/rb-scheduler/commits/main) [![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE) [![Bug Reports](https://img.shields.io/badge/bug-reports-red.svg)](https://github.com/philiprehberger/rb-scheduler/issues) [![Feature Requests](https://img.shields.io/badge/feature-requests-blue.svg)](https://github.com/philiprehberger/rb-scheduler/issues) [![GitHub Sponsors](https://img.shields.io/badge/sponsor-philiprehberger-ea4aaa.svg?logo=github)](https://github.com/sponsors/philiprehberger)

Lightweight in-process task scheduler with cron and interval support for Ruby

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-scheduler"
```

Or install directly:

```bash
gem install philiprehberger-scheduler
```

## Usage

```ruby
require "philiprehberger/scheduler"

scheduler = Philiprehberger::Scheduler.new

scheduler.every('5m') { puts 'Runs every 5 minutes' }
scheduler.cron('0 9 * * 1-5') { puts 'Weekdays at 9am' }

scheduler.start
```

### Interval Scheduling

Schedule recurring jobs using human-readable duration strings or numeric seconds.

```ruby
require "philiprehberger/scheduler"

scheduler = Philiprehberger::Scheduler.new

scheduler.every('30s') { puts 'Every 30 seconds' }
scheduler.every('5m')  { puts 'Every 5 minutes' }
scheduler.every('1h')  { puts 'Every hour' }
scheduler.every(120)   { puts 'Every 120 seconds' }
```

### Cron Scheduling

Schedule jobs using standard 5-field cron expressions. Supported syntax includes wildcards (`*`), specific values, ranges (`1-5`), steps (`*/15`), range steps (`1-30/5`), and comma-separated lists (`1,15,30`).

```ruby
require "philiprehberger/scheduler"

scheduler = Philiprehberger::Scheduler.new

scheduler.cron('0 9 * * 1-5')  { puts 'Weekdays at 9am' }
scheduler.cron('*/15 * * * *') { puts 'Every 15 minutes' }
scheduler.cron('0 0 1 * *')    { puts 'First of the month at midnight' }
```

### Overlap Prevention

By default, jobs can run concurrently even if a previous execution is still in progress. Set `overlap: false` to skip an execution when the previous one has not yet finished.

```ruby
require "philiprehberger/scheduler"

scheduler = Philiprehberger::Scheduler.new

scheduler.every('10s', overlap: false) do
  # If this takes longer than 10s, the next run is skipped
  sleep(15)
end

scheduler.start
```

### Job Dependencies

Use `depends_on:` to ensure a job only runs after a named dependency has completed at least once. The dependent job will wait until the dependency has finished its first execution before it becomes eligible to run.

```ruby
require "philiprehberger/scheduler"

scheduler = Philiprehberger::Scheduler.new

scheduler.every('5m', name: 'fetch_data') { fetch_from_api }
scheduler.every('5m', name: 'process', depends_on: 'fetch_data') { transform_data }

scheduler.start
```

### Conditional Scheduling

Use `if:` to skip job execution based on a condition evaluated at each tick. The lambda is called every time the job is checked, so conditions can be dynamic.

```ruby
require "philiprehberger/scheduler"

scheduler = Philiprehberger::Scheduler.new

# Only run during business hours
scheduler.every('1h', if: -> { Time.now.hour.between?(9, 16) }) do
  send_report
end

# Only run on weekdays
scheduler.cron('0 8 * * *', if: -> { (1..5).cover?(Time.now.wday) }) do
  morning_digest
end

scheduler.start
```

### Job Result Chaining

Use `input_from:` to pass the return value of one job as input to another. The consumer job receives the most recent result from the source job as its block argument.

```ruby
require "philiprehberger/scheduler"

scheduler = Philiprehberger::Scheduler.new

scheduler.every('5m', name: 'fetch') { fetch_raw_data }
scheduler.every('5m', name: 'transform', input_from: 'fetch') do |raw_data|
  process(raw_data)
end

scheduler.start
```

### Timezone Support

Cron jobs can target a specific timezone using `timezone:`. Accepts IANA timezone names (e.g. `America/New_York`) or UTC offsets (e.g. `+05:30`). The cron expression is evaluated against the specified timezone rather than system local time.

```ruby
require "philiprehberger/scheduler"

scheduler = Philiprehberger::Scheduler.new

scheduler.cron('0 9 * * *', timezone: 'America/New_York') { east_coast_report }
scheduler.cron('0 9 * * *', timezone: 'Europe/Berlin') { berlin_report }
scheduler.cron('30 17 * * *', timezone: '+05:30') { india_close }

scheduler.start
```

### Job Persistence

Save and restore scheduler state for crash recovery. Only named jobs are persisted. State includes last run timestamps so the scheduler can resume without immediately re-firing jobs that already ran.

```ruby
require "philiprehberger/scheduler"

scheduler = Philiprehberger::Scheduler.new

scheduler.every('5m', name: 'heartbeat') { ping_service }
scheduler.every('1h', name: 'cleanup') { clean_temp_files }

# Restore previous state if available
scheduler.load_state('/tmp/scheduler_state.json')
scheduler.start

# Save state before shutdown
at_exit do
  scheduler.stop
  scheduler.save_state('/tmp/scheduler_state.json')
end
```

### Leader Election

In multi-process deployments, use leader election to ensure only one process runs scheduled jobs. Leadership is managed via an exclusive file lock. If the lock cannot be acquired, the scheduler does not start.

```ruby
require "philiprehberger/scheduler"

scheduler = Philiprehberger::Scheduler.new
scheduler.enable_leader_election(lock_path: '/tmp/scheduler.lock')

scheduler.every('1m') { perform_work }

# Only starts if this process acquires the lock
scheduler.start

if scheduler.running?
  puts "This process is the leader"
else
  puts "Another process holds the lock"
end
```

### Job Inspection

Use `#jobs` to retrieve a snapshot of all registered jobs at any time. Each returned `Job` exposes its configuration and runtime state.

```ruby
require "philiprehberger/scheduler"

scheduler = Philiprehberger::Scheduler.new

scheduler.every('1m', name: 'tick') { puts 'tick' }
scheduler.cron('0 * * * *', name: 'hourly') { puts 'hourly' }

scheduler.jobs.each do |job|
  if job.interval?
    puts "Interval job: every #{job.interval}s"
  elsif job.cron?
    puts "Cron job: #{job.cron.expression}"
  end
  puts "  Name: #{job.name || 'unnamed'}"
  puts "  Last run: #{job.last_run || 'never'}"
  puts "  Last result: #{job.last_result.inspect}"
end
```

### Error Handling

Each job runs in its own thread. If a job raises an exception, only that thread is affected -- other jobs and the scheduler itself continue running. The `Job#execute` method uses an `ensure` block to reset the running state and record the last run time regardless of whether the block succeeds or raises.

```ruby
require "philiprehberger/scheduler"

scheduler = Philiprehberger::Scheduler.new

scheduler.every('10s') do
  begin
    perform_risky_operation
  rescue => e
    MyLogger.error("Job failed: #{e.message}")
  end
end

scheduler.start
```

### Scheduler Lifecycle

The scheduler follows a simple lifecycle: create, register jobs, start, and stop.

```ruby
require "philiprehberger/scheduler"

# 1. Create
scheduler = Philiprehberger::Scheduler.new

# 2. Register jobs (can also be added after start)
scheduler.every('5s') { puts 'heartbeat' }

# 3. Start -- launches a non-blocking background thread
scheduler.start
scheduler.running?  #=> true

# 4. Stop -- waits up to `timeout` seconds for the thread to finish
scheduler.stop
scheduler.running?  #=> false
```

Jobs can be added both before and after calling `#start`. The scheduler checks for due jobs every 0.25 seconds (the internal tick interval). Calling `#stop` signals the run loop to exit and joins the background thread. If the thread does not finish within the timeout, it is forcefully terminated.

## API

### `Philiprehberger::Scheduler`

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `.new` | -- | `Scheduler` | Creates a new scheduler instance |
| `#every(interval, **opts, &block)` | `interval` -- `String` (`'30s'`, `'5m'`, `'1h'`) or `Numeric` (seconds); `name:` -- `String`; `overlap:` -- `Boolean` (default `true`); `depends_on:` -- `String` (name of dependency); `input_from:` -- `String` (name of source job); `if:` -- `Proc` (condition lambda) | `Job` | Schedules a recurring interval-based job |
| `#cron(expression, **opts, &block)` | `expression` -- `String` (5-field cron); `name:` -- `String`; `depends_on:` -- `String`; `input_from:` -- `String`; `timezone:` -- `String` (IANA name or UTC offset); `if:` -- `Proc` | `Job` | Schedules a job using a cron expression |
| `#start` | -- | `self` | Starts the scheduler in a background thread |
| `#stop(timeout)` | `timeout` -- `Numeric` (default `5`, seconds to wait for thread shutdown) | `self` | Gracefully stops the scheduler |
| `#running?` | -- | `Boolean` | Returns `true` if the scheduler background thread is alive |
| `#jobs` | -- | `Array<Job>` | Returns a duplicated snapshot of all registered jobs |
| `#save_state(path)` | `path` -- `String` (file path) | `self` | Saves named job state to a JSON file |
| `#load_state(path)` | `path` -- `String` (file path) | `self` | Restores job state from a JSON file |
| `#enable_leader_election(lock_path:)` | `lock_path:` -- `String` (file path for lock) | `self` | Enables file-based leader election |
| `#leader?` | -- | `Boolean` | Returns `true` if this instance holds the leader lock |
| `#acquire_leadership` | -- | `Boolean` | Attempts to acquire the leader file lock |
| `#release_leadership` | -- | -- | Releases the leader file lock |

### `Philiprehberger::Scheduler::Job`

| Method | Returns | Description |
|--------|---------|-------------|
| `#name` | `String` or `nil` | The job name, or `nil` if unnamed |
| `#interval` | `Float` or `nil` | The interval in seconds, or `nil` for cron jobs |
| `#cron` | `CronParser` or `nil` | The parsed cron expression, or `nil` for interval jobs |
| `#overlap?` | `Boolean` | Whether concurrent executions are allowed |
| `#interval?` | `Boolean` | Returns `true` if this is an interval-based job |
| `#cron?` | `Boolean` | Returns `true` if this is a cron-based job |
| `#due?(now)` | `Boolean` | Whether the job is due for execution at the given time |
| `#last_run` | `Time` or `nil` | Timestamp of the most recent execution |
| `#last_result` | `Object` or `nil` | Return value from the most recent execution |
| `#running` | `Boolean` | Whether the job is currently executing |
| `#depends_on` | `String` or `nil` | Name of the dependency job |
| `#input_from` | `String` or `nil` | Name of the source job for result chaining |
| `#condition` | `Proc` or `nil` | The condition lambda for conditional scheduling |
| `#timezone` | `String` or `nil` | The timezone for cron evaluation |

### Thread Safety

The scheduler uses a `Mutex` to synchronize access to the internal job list. Adding jobs via `#every` or `#cron` and reading them via `#jobs` is safe to do from any thread. Each job execution runs in its own thread, so job blocks should be thread-safe if they access shared state.

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Philip%20Rehberger-blue?logo=linkedin)](https://linkedin.com/in/philiprehberger) [![More Packages](https://img.shields.io/badge/more-packages-blue.svg)](https://github.com/philiprehberger?tab=repositories)

## License

[MIT](LICENSE)
