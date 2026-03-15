# frozen_string_literal: true

module Philiprehberger
  class Scheduler
    class Job
      attr_reader :callable, :interval, :cron, :options
      attr_accessor :last_run, :running

      def initialize(callable:, interval: nil, cron: nil, **options)
        @callable = callable
        @interval = interval
        @cron = cron
        @options = { overlap: true }.merge(options)
        @last_run = nil
        @running = false
      end

      def overlap?
        @options[:overlap]
      end

      def interval?
        !@interval.nil?
      end

      def cron?
        !@cron.nil?
      end

      def due?(now)
        return due_by_interval?(now) if interval?
        return due_by_cron?(now) if cron?

        false
      end

      def execute
        @running = true
        @callable.call
      ensure
        @running = false
        @last_run = Time.now
      end

      private

      def due_by_interval?(now)
        return true if @last_run.nil?

        (now - @last_run) >= @interval
      end

      def due_by_cron?(now)
        return false if @last_run && (now - @last_run) < 60

        @cron.matches?(now)
      end
    end
  end
end
