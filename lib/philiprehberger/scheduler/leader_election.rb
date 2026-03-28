# frozen_string_literal: true

module Philiprehberger
  class Scheduler
    module LeaderElection
      def enable_leader_election(lock_path:)
        @leader_lock_path = lock_path
        @leader_lock_file = nil
        @is_leader = false
        self
      end

      def leader?
        @is_leader == true
      end

      def acquire_leadership
        return false unless @leader_lock_path

        @leader_lock_file = File.open(@leader_lock_path, File::RDWR | File::CREAT)
        if @leader_lock_file.flock(File::LOCK_EX | File::LOCK_NB)
          @leader_lock_file.truncate(0)
          @leader_lock_file.write("#{Process.pid}\n")
          @leader_lock_file.flush
          @is_leader = true
          true
        else
          @leader_lock_file.close
          @leader_lock_file = nil
          @is_leader = false
          false
        end
      rescue Errno::ENOENT, Errno::EACCES
        @is_leader = false
        false
      end

      def release_leadership
        return unless @leader_lock_file

        @leader_lock_file.flock(File::LOCK_UN)
        @leader_lock_file.close
        @leader_lock_file = nil
        @is_leader = false
      rescue IOError
        @is_leader = false
      end
    end
  end
end
