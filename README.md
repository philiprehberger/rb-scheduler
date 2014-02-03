# philiprehberger-scheduler

[![Gem Version](https://badge.fury.io/rb/philiprehberger-scheduler.svg)](https://badge.fury.io/rb/philiprehberger-scheduler)

Lightweight in-process task scheduler with cron and interval support for Ruby.

## Installation

Add to your Gemfile:

```ruby
gem 'philiprehberger-scheduler'
```

Or install directly:

```sh
gem install philiprehberger-scheduler
```

## Usage

```ruby
require 'philiprehberger/scheduler'

scheduler = Philiprehberger::Scheduler.new

# Schedule with an interval
scheduler.every('5m') { puts 'Runs every 5 minutes' }
scheduler.every('30s') { puts 'Runs every 30 seconds' }
scheduler.every('1h') { puts 'Runs every hour' }

# Schedule with a cron expression (standard 5-field)
scheduler.cron('0 9 * * 1-5') { puts 'Weekdays at 9am' }
scheduler.cron('*/15 * * * *') { puts 'Every 15 minutes' }

# Prevent overlapping runs
scheduler.every('10s', overlap: false) do
  # Long-running task that won't overlap
  sleep(15)
end

# Start the scheduler (non-blocking)
scheduler.start

# Stop gracefully
scheduler.stop
```

## API

### `Philiprehberger::Scheduler.new`

Creates a new scheduler instance.

### `#every(interval, overlap: true, &block)`

Schedules a recurring job. Interval accepts seconds (`'30s'`), minutes (`'5m'`), hours (`'1h'`), or a numeric value in seconds. Set `overlap: false` to skip execution if the previous run is still active.

### `#cron(expression, &block)`

Schedules a job using a standard 5-field cron expression. Supports `*`, specific values, ranges (`1-5`), steps (`*/15`), and comma-separated lists.

### `#start`

Starts the scheduler in a background thread. Returns `self`.

### `#stop(timeout = 5)`

Gracefully stops the scheduler. Waits up to `timeout` seconds for the background thread to finish.

### `#running?`

Returns `true` if the scheduler is currently running.

### `#jobs`

Returns a snapshot of all scheduled jobs.

## Development

```sh
bundle install
bundle exec rake spec
bundle exec rake rubocop
```

## License

MIT License. See [LICENSE](LICENSE) for details.
