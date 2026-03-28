# frozen_string_literal: true

require_relative 'scheduler/version'
require_relative 'scheduler/job'
require_relative 'scheduler/cron_parser'
require_relative 'scheduler/runner'
require_relative 'scheduler/persistence'
require_relative 'scheduler/leader_election'

module Philiprehberger
  class Scheduler
    include Persistence
    include LeaderElection

    def initialize
      @jobs = []
      @mutex = Mutex.new
      @runner = Runner.new(@jobs, @mutex)
      @leader_lock_path = nil
      @leader_lock_file = nil
      @is_leader = false
    end

    def every(interval, name: nil, overlap: true, depends_on: nil, input_from: nil, if: nil, &block)
      seconds = parse_interval(interval)
      job = Job.new(
        callable: block,
        interval: seconds,
        overlap: overlap,
        name: name,
        depends_on: depends_on,
        input_from: input_from,
        if: binding.local_variable_get(:if)
      )
      @mutex.synchronize { @jobs << job }
      job
    end

    def cron(expression, name: nil, depends_on: nil, input_from: nil, timezone: nil, if: nil, &block)
      parsed = CronParser.new(expression)
      job = Job.new(
        callable: block,
        cron: parsed,
        name: name,
        depends_on: depends_on,
        input_from: input_from,
        timezone: timezone,
        if: binding.local_variable_get(:if)
      )
      @mutex.synchronize { @jobs << job }
      job
    end

    def start
      if @leader_lock_path && !acquire_leadership
        return self
      end

      @runner.start
      self
    end

    def stop(timeout = 5)
      @runner.stop(timeout)
      release_leadership if @leader_lock_path
      self
    end

    def running?
      @runner.running?
    end

    def jobs
      @mutex.synchronize { @jobs.dup }
    end

    private

    def parse_interval(value)
      case value
      when Numeric then value.to_f
      when /\A(\d+)s\z/ then ::Regexp.last_match(1).to_f
      when /\A(\d+)m\z/ then ::Regexp.last_match(1).to_f * 60
      when /\A(\d+)h\z/ then ::Regexp.last_match(1).to_f * 3600
      else raise ArgumentError, "invalid interval: #{value}"
      end
    end
  end
end
