# frozen_string_literal: true

module Philiprehberger
  class Scheduler
    class Runner
      TICK = 0.25

      def initialize(jobs, mutex)
        @jobs = jobs
        @mutex = mutex
        @thread = nil
        @running = false
      end

      def start
        @running = true
        @thread = Thread.new { run_loop }
      end

      def stop(timeout = 5)
        @running = false
        @thread&.join(timeout)
        @thread&.kill if @thread&.alive?
        @thread = nil
      end

      def running?
        @running && @thread&.alive?
      end

      private

      def run_loop
        tick while @running
      rescue StandardError
        # silently exit on unexpected errors
      end

      def tick
        now = Time.now
        fire_due_jobs(now)
        sleep(TICK)
      end

      def fire_due_jobs(now)
        @mutex.synchronize { @jobs.dup }.each do |job|
          next unless job.due?(now)
          next if job.running && !job.overlap?

          Thread.new { job.execute }
        end
      end
    end
  end
end
