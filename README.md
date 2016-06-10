# philiprehberger-scheduler

[![Tests](https://github.com/philiprehberger/rb-scheduler/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-scheduler/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-scheduler.svg)](https://rubygems.org/gems/philiprehberger-scheduler)
[![License](https://img.shields.io/github/license/philiprehberger/rb-scheduler)](LICENSE)

Lightweight in-process task scheduler with cron and interval support for Ruby

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem 'philiprehberger-scheduler'
```

Or install directly:

```bash
gem install philiprehberger-scheduler
```

## Usage

```ruby
require 'philiprehberger/scheduler'

scheduler = Philiprehberger::Scheduler.new

scheduler.every('5m') { puts 'Runs every 5 minutes' }
scheduler.cron('0 9 * * 1-5') { puts 'Weekdays at 9am' }

scheduler.start
```

### Interval Scheduling

Schedule recurring jobs using human-readable duration strings or numeric seconds.

```ruby
require 'philiprehberger/scheduler'

scheduler = Philiprehberger::Scheduler.new

scheduler.every('30s') { puts 'Every 30 seconds' }
scheduler.every('5m')  { puts 'Every 5 minutes' }
scheduler.every('1h')  { puts 'Every hour' }
scheduler.every(120)   { puts 'Every 120 seconds' }
```

### Cron Scheduling

Schedule jobs using standard 5-field cron expressions. Supported syntax includes wildcards (`*`), specific values, ranges (`1-5`), steps (`*/15`), range steps (`1-30/5`), and comma-separated lists (`1,15,30`).

```ruby
require 'philiprehberger/scheduler'

scheduler = Philiprehberger::Scheduler.new

scheduler.cron('0 9 * * 1-5')  { puts 'Weekdays at 9am' }
scheduler.cron('*/15 * * * *') { puts 'Every 15 minutes' }
scheduler.cron('0 0 1 * *')    { puts 'First of the month at midnight' }
```

### Overlap Prevention

By default, jobs can run concurrently even if a previous execution is still in progress. Set `overlap: false` to skip an execution when the previous one has not yet finished.

```ruby
require 'philiprehberger/scheduler'

scheduler = Philiprehberger::Scheduler.new

scheduler.every('10s', overlap: false) do
  # If this takes longer than 10s, the next run is skipped
  sleep(15)
end

scheduler.start
```

### Job Inspection

Use `#jobs` to retrieve a snapshot of all registered jobs at any time. Each returned `Job` exposes its configuration and runtime state.

```ruby
require 'philiprehberger/scheduler'

scheduler = Philiprehberger::Scheduler.new

scheduler.every('1m') { puts 'tick' }
scheduler.cron('0 * * * *') { puts 'hourly' }

scheduler.jobs.each do |job|
  if job.interval?
    puts "Interval job: every #{job.interval}s"
  elsif job.cron?
    puts "Cron job: #{job.cron.expression}"
  end
  puts "  Last run: #{job.last_run || 'never'}"
  puts "  Currently running: #{job.running}"
end
```

### Error Handling

Each job runs in its own thread. If a job raises an exception, only that thread is affected -- other jobs and the scheduler itself continue running. The `Job#execute` method uses an `ensure` block to reset the running state and record the last run time regardless of whether the block succeeds or raises.

```ruby
require 'philiprehberger/scheduler'

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

If you need guaranteed error visibility, wrap your job block in a `begin/rescue` and log or report the error yourself.

### Scheduler Lifecycle

The scheduler follows a simple lifecycle: create, register jobs, start, and stop.

```ruby
require 'philiprehberger/scheduler'

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
| `#every(interval, overlap:, &block)` | `interval` -- `String` (`'30s'`, `'5m'`, `'1h'`) or `Numeric` (seconds); `overlap:` -- `Boolean` (default `true`) | `Job` | Schedules a recurring interval-based job |
| `#cron(expression, &block)` | `expression` -- `String` (standard 5-field cron) | `Job` | Schedules a job using a cron expression |
| `#start` | -- | `self` | Starts the scheduler in a background thread |
| `#stop(timeout)` | `timeout` -- `Numeric` (default `5`, seconds to wait for thread shutdown) | `self` | Gracefully stops the scheduler, forcefully kills the thread if it exceeds the timeout |
| `#running?` | -- | `Boolean` | Returns `true` if the scheduler background thread is alive |
| `#jobs` | -- | `Array<Job>` | Returns a duplicated snapshot of all registered jobs |

### `Philiprehberger::Scheduler::Job`

| Method | Returns | Description |
|--------|---------|-------------|
| `#interval` | `Float` or `nil` | The interval in seconds, or `nil` for cron jobs |
| `#cron` | `CronParser` or `nil` | The parsed cron expression, or `nil` for interval jobs |
| `#overlap?` | `Boolean` | Whether concurrent executions are allowed |
| `#interval?` | `Boolean` | Returns `true` if this is an interval-based job |
| `#cron?` | `Boolean` | Returns `true` if this is a cron-based job |
| `#due?(now)` | `Boolean` | Whether the job is due for execution at the given time |
| `#last_run` | `Time` or `nil` | Timestamp of the most recent execution, or `nil` if never run |
| `#running` | `Boolean` | Whether the job is currently executing |

### Thread Safety

The scheduler uses a `Mutex` to synchronize access to the internal job list. Adding jobs via `#every` or `#cron` and reading them via `#jobs` is safe to do from any thread. Each job execution runs in its own thread, so job blocks should be thread-safe if they access shared state.

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
