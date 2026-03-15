# frozen_string_literal: true

require_relative 'scheduler/version'
require_relative 'scheduler/job'
require_relative 'scheduler/cron_parser'
require_relative 'scheduler/runner'

module Philiprehberger
  class Scheduler
    def initialize
      @jobs = []
      @mutex = Mutex.new
      @runner = Runner.new(@jobs, @mutex)
    end

    def every(interval, overlap: true, &block)
      seconds = parse_interval(interval)
      job = Job.new(callable: block, interval: seconds, overlap: overlap)
      @mutex.synchronize { @jobs << job }
      job
    end

    def cron(expression, &block)
      parsed = CronParser.new(expression)
      job = Job.new(callable: block, cron: parsed)
      @mutex.synchronize { @jobs << job }
      job
    end

    def start
      @runner.start
      self
    end

    def stop(timeout = 5)
      @runner.stop(timeout)
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
