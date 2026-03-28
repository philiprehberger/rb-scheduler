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
        jobs = @mutex.synchronize { @jobs.dup }
        jobs_by_name = build_name_index(jobs)

        jobs.each do |job|
          next unless job.due?(now)
          next if job.running && !job.overlap?
          next if dependency_pending?(job, jobs_by_name)

          input = resolve_input(job, jobs_by_name)
          Thread.new { job.execute(input) }
        end
      end

      def build_name_index(jobs)
        index = {}
        jobs.each do |job|
          index[job.name] = job if job.name
        end
        index
      end

      def dependency_pending?(job, jobs_by_name)
        return false unless job.depends_on

        dep = jobs_by_name[job.depends_on]
        return true unless dep
        return true if dep.last_run.nil?
        return true if dep.running

        false
      end

      def resolve_input(job, jobs_by_name)
        return nil unless job.input_from

        source = jobs_by_name[job.input_from]
        source&.last_result
      end
    end
  end
end
