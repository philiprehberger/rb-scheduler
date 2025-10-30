# frozen_string_literal: true

module Philiprehberger
  class Scheduler
    class Job
      attr_reader :callable, :interval, :cron, :run_at, :options, :name, :depends_on,
                  :input_from, :condition, :timezone
      attr_accessor :last_run, :running, :last_result, :last_error, :paused

      def initialize(callable:, interval: nil, cron: nil, run_at: nil, **options)
        @callable = callable
        @interval = interval
        @cron = cron
        @run_at = run_at
        @name = options.delete(:name)
        @depends_on = options.delete(:depends_on)
        @input_from = options.delete(:input_from)
        @condition = options.delete(:if)
        @timezone = options.delete(:timezone)
        @options = { overlap: true }.merge(options)
        @last_run = nil
        @running = false
        @last_result = nil
        @last_error = nil
        @paused = false
      end

      def overlap?
        @options[:overlap]
      end

      def paused?
        @paused == true
      end

      def interval?
        !@interval.nil?
      end

      def cron?
        !@cron.nil?
      end

      def run_at?
        !@run_at.nil?
      end

      def due?(now)
        return false if paused?
        return false if @condition && !@condition.call

        effective_now = apply_timezone(now)
        return due_by_run_at?(now) if run_at?
        return due_by_interval?(now) if interval?
        return due_by_cron?(effective_now) if cron?

        false
      end

      def execute(input = nil)
        @running = true
        @last_error = nil
        @last_result = if @input_from && !input.nil?
                         @callable.call(input)
                       else
                         @callable.call
                       end
        @last_result
      rescue StandardError => e
        @last_error = e
        raise
      ensure
        @running = false
        @last_run = Time.now
      end

      def to_state
        {
          'name' => @name,
          'interval' => @interval,
          'cron_expression' => @cron&.expression,
          'overlap' => overlap?,
          'last_run' => @last_run&.iso8601,
          'timezone' => @timezone,
          'last_error' => @last_error&.message,
          'paused' => paused?
        }
      end

      def restore_state(state)
        @last_run = Time.parse(state['last_run']) if state['last_run']
        @paused = state['paused'] == true if state.key?('paused')
      end

      private

      def apply_timezone(now)
        return now unless @timezone && cron?

        offset = parse_timezone_offset(@timezone)
        return now unless offset

        now.getutc + offset
      end

      def parse_timezone_offset(tz)
        case tz
        when /\A[+-]\d{2}:\d{2}\z/
          sign = tz[0] == '+' ? 1 : -1
          hours, minutes = tz[1..].split(':').map(&:to_i)
          sign * ((hours * 3600) + (minutes * 60))
        when 'UTC', 'GMT'
          0
        else
          resolve_named_timezone(tz)
        end
      end

      def resolve_named_timezone(tz)
        offsets = {
          'US/Eastern' => -5 * 3600, 'America/New_York' => -5 * 3600,
          'US/Central' => -6 * 3600, 'America/Chicago' => -6 * 3600,
          'US/Mountain' => -7 * 3600, 'America/Denver' => -7 * 3600,
          'US/Pacific' => -8 * 3600, 'America/Los_Angeles' => -8 * 3600,
          'Europe/London' => 0, 'Europe/Berlin' => 1 * 3600,
          'Europe/Paris' => 1 * 3600, 'Asia/Tokyo' => 9 * 3600,
          'Asia/Shanghai' => 8 * 3600, 'Australia/Sydney' => 11 * 3600
        }
        offsets[tz]
      end

      def due_by_interval?(now)
        return true if @last_run.nil?

        (now - @last_run) >= @interval
      end

      def due_by_cron?(now)
        return false if @last_run && (now - @last_run) < 60

        @cron.matches?(now)
      end

      def due_by_run_at?(now)
        return false unless @last_run.nil?

        now >= @run_at
      end
    end
  end
end
