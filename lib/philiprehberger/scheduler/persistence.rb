# frozen_string_literal: true

require 'json'
require 'time'

module Philiprehberger
  class Scheduler
    module Persistence
      def save_state(path)
        state = {
          'version' => VERSION,
          'saved_at' => Time.now.iso8601,
          'jobs' => jobs.select(&:name).map(&:to_state)
        }
        File.write(path, JSON.pretty_generate(state))
        self
      end

      def load_state(path)
        return self unless File.exist?(path)

        data = JSON.parse(File.read(path))
        job_states = data.fetch('jobs', [])
        named_jobs = @mutex.synchronize { @jobs.select(&:name) }

        job_states.each do |js|
          job = named_jobs.find { |j| j.name == js['name'] }
          job&.restore_state(js)
        end
        self
      end
    end
  end
end
