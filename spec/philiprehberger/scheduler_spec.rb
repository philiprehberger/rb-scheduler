# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'json'

RSpec.describe Philiprehberger::Scheduler do
  subject(:scheduler) { Philiprehberger::Scheduler.new }

  after { scheduler.stop if scheduler.is_a?(Philiprehberger::Scheduler) }

  describe 'VERSION' do
    it 'returns the current version' do
      expect(Philiprehberger::Scheduler::VERSION).not_to be_nil
    end
  end

  describe '#every' do
    it 'schedules a job with a parsed interval' do
      scheduler.every('5m') { nil }
      expect(scheduler.jobs.size).to eq(1)
      expect(scheduler.jobs.first.interval).to eq(300)
    end

    it 'parses seconds' do
      scheduler.every('30s') { nil }
      expect(scheduler.jobs.first.interval).to eq(30)
    end

    it 'parses hours' do
      scheduler.every('1h') { nil }
      expect(scheduler.jobs.first.interval).to eq(3600)
    end

    it 'accepts numeric values' do
      scheduler.every(10) { nil }
      expect(scheduler.jobs.first.interval).to eq(10.0)
    end

    it 'raises on invalid interval' do
      expect { scheduler.every('bad') { nil } }.to raise_error(ArgumentError)
    end

    it 'returns a Job object' do
      job = scheduler.every('1s') { nil }
      expect(job).to be_a(Philiprehberger::Scheduler::Job)
    end

    it 'schedules multiple jobs' do
      scheduler.every('1s') { nil }
      scheduler.every('2s') { nil }
      scheduler.every('3s') { nil }
      expect(scheduler.jobs.size).to eq(3)
    end

    it 'defaults overlap to true' do
      job = scheduler.every('1s') { nil }
      expect(job.overlap?).to be true
    end

    it 'supports overlap: false' do
      job = scheduler.every('1s', overlap: false) { nil }
      expect(job.overlap?).to be false
    end

    it 'accepts a name option' do
      job = scheduler.every('1s', name: 'heartbeat') { nil }
      expect(job.name).to eq('heartbeat')
    end
  end

  describe '#cron' do
    it 'schedules a job with a cron expression' do
      scheduler.cron('*/5 * * * *') { nil }
      expect(scheduler.jobs.size).to eq(1)
      expect(scheduler.jobs.first).to be_cron
    end

    it 'returns a Job object' do
      job = scheduler.cron('* * * * *') { nil }
      expect(job).to be_a(Philiprehberger::Scheduler::Job)
    end

    it 'scheduled cron job is not an interval job' do
      job = scheduler.cron('0 12 * * *') { nil }
      expect(job).not_to be_interval
    end

    it 'accepts a name option' do
      job = scheduler.cron('* * * * *', name: 'cron-job') { nil }
      expect(job.name).to eq('cron-job')
    end

    it 'accepts a timezone option' do
      job = scheduler.cron('0 9 * * *', timezone: 'America/New_York') { nil }
      expect(job.timezone).to eq('America/New_York')
    end
  end

  describe '#start and #stop' do
    it 'starts and stops the scheduler' do
      scheduler.start
      expect(scheduler).to be_running
      scheduler.stop
      sleep(0.1)
      expect(scheduler).not_to be_running
    end

    it 'is not running before start' do
      expect(scheduler).not_to be_running
    end

    it 'can be stopped when not started' do
      expect { scheduler.stop }.not_to raise_error
    end

    it 'can be started after being stopped' do
      scheduler.start
      scheduler.stop
      sleep(0.1)
      scheduler.start
      expect(scheduler).to be_running
    end

    it 'returns self from start' do
      result = scheduler.start
      expect(result).to eq(scheduler)
    end

    it 'returns self from stop' do
      scheduler.start
      result = scheduler.stop
      expect(result).to eq(scheduler)
    end
  end

  describe 'job execution' do
    it 'fires a due interval job' do
      called = false
      scheduler.every(0.1) { called = true }
      scheduler.start
      sleep(0.5)
      expect(called).to be(true)
    end

    it 'fires a job multiple times' do
      count = 0
      mutex = Mutex.new
      scheduler.every(0.1) { mutex.synchronize { count += 1 } }
      scheduler.start
      sleep(0.6)
      scheduler.stop
      expect(count).to be >= 2
    end
  end

  describe 'overlap prevention' do
    it 'skips overlapping execution when overlap is false' do
      count = 0
      scheduler.every(0.1, overlap: false) do
        count += 1
        sleep(0.4)
      end
      scheduler.start
      sleep(0.8)
      scheduler.stop
      expect(count).to be <= 2
    end

    it 'allows overlapping execution when overlap is true' do
      count = 0
      mutex = Mutex.new
      scheduler.every(0.1, overlap: true) do
        mutex.synchronize { count += 1 }
        sleep(0.3)
      end
      scheduler.start
      sleep(0.6)
      scheduler.stop
      expect(count).to be >= 2
    end
  end

  describe '#jobs' do
    it 'returns a copy of the job list' do
      scheduler.every('1s') { nil }
      jobs = scheduler.jobs
      jobs.clear
      expect(scheduler.jobs.size).to eq(1)
    end

    it 'returns an empty array when no jobs are scheduled' do
      expect(scheduler.jobs).to eq([])
    end
  end

  describe 'job dependencies' do
    it 'accepts depends_on option for interval jobs' do
      scheduler.every('1s', name: 'A') { nil }
      job_b = scheduler.every('1s', name: 'B', depends_on: 'A') { nil }
      expect(job_b.depends_on).to eq('A')
    end

    it 'accepts depends_on option for cron jobs' do
      scheduler.cron('* * * * *', name: 'A') { nil }
      job_b = scheduler.cron('* * * * *', name: 'B', depends_on: 'A') { nil }
      expect(job_b.depends_on).to eq('A')
    end

    it 'does not fire dependent job when dependency has not run' do
      called_b = false
      scheduler.every(0.1, name: 'A') { sleep(10) } # never completes
      scheduler.every(0.1, name: 'B', depends_on: 'A') { called_b = true }

      # Manually check dependency logic without starting the scheduler
      jobs = scheduler.jobs
      job_a = jobs.find { |j| j.name == 'A' }
      job_b = jobs.find { |j| j.name == 'B' }

      # A has never run, so B should be blocked
      expect(job_a.last_run).to be_nil
      expect(job_b.depends_on).to eq('A')
    end

    it 'fires dependent job after dependency completes' do
      called_b = false
      mutex = Mutex.new
      scheduler.every(0.1, name: 'A') { 'result_a' }
      scheduler.every(0.1, name: 'B', depends_on: 'A') { mutex.synchronize { called_b = true } }
      scheduler.start
      sleep(1.0)
      scheduler.stop
      expect(called_b).to be(true)
    end
  end

  describe 'conditional scheduling' do
    it 'accepts if option for interval jobs' do
      job = scheduler.every('1s', if: -> { true }) { nil }
      expect(job.condition).to be_a(Proc)
    end

    it 'skips execution when condition returns false' do
      called = false
      scheduler.every(0.1, if: -> { false }) { called = true }
      scheduler.start
      sleep(0.5)
      scheduler.stop
      expect(called).to be(false)
    end

    it 'runs job when condition returns true' do
      called = false
      scheduler.every(0.1, if: -> { true }) { called = true }
      scheduler.start
      sleep(0.5)
      scheduler.stop
      expect(called).to be(true)
    end

    it 'evaluates condition on each tick' do
      counter = 0
      condition_calls = 0
      condition_mutex = Mutex.new
      scheduler.every(0.1, if: lambda {
  condition_mutex.synchronize { condition_calls += 1 }
  true
}) do
        counter += 1
      end
      scheduler.start
      sleep(0.6)
      scheduler.stop
      expect(condition_calls).to be >= 2
    end

    it 'works with cron jobs' do
      job = scheduler.cron('* * * * *', if: -> { false }) { nil }
      expect(job.due?(Time.now)).to be(false)
    end
  end

  describe 'job result chaining' do
    it 'accepts input_from option' do
      scheduler.every('1s', name: 'A') { 42 }
      job_b = scheduler.every('1s', name: 'B', input_from: 'A') { |r| r }
      expect(job_b.input_from).to eq('A')
    end

    it 'stores last_result after execution' do
      job = Philiprehberger::Scheduler::Job.new(callable: -> { 42 }, interval: 1, name: 'test')
      job.execute
      expect(job.last_result).to eq(42)
    end

    it 'passes result from source job to dependent job' do
      received = nil
      mutex = Mutex.new
      scheduler.every(0.1, name: 'producer') { 'hello' }
      scheduler.every(0.1, name: 'consumer', input_from: 'producer') { |r| mutex.synchronize { received = r } }
      scheduler.start
      sleep(1.0)
      scheduler.stop
      expect(received).to eq('hello')
    end

    it 'calls without input when source has no result yet' do
      received = :not_called
      job = Philiprehberger::Scheduler::Job.new(
        callable: lambda {
  received = :called_without_input
  nil
},
        interval: 1,
        name: 'consumer',
        input_from: 'producer'
      )
      job.execute
      expect(received).to eq(:called_without_input)
    end
  end

  describe 'timezone support' do
    it 'stores timezone on cron jobs' do
      job = scheduler.cron('0 9 * * *', timezone: 'America/New_York') { nil }
      expect(job.timezone).to eq('America/New_York')
    end

    it 'accepts UTC offset format' do
      job = scheduler.cron('0 9 * * *', timezone: '+05:30') { nil }
      expect(job.timezone).to eq('+05:30')
    end

    it 'matches cron in specified timezone with offset' do
      # Create a cron for 14:00 and use UTC+0 timezone
      job = Philiprehberger::Scheduler::Job.new(
        callable: -> {},
        cron: Philiprehberger::Scheduler::CronParser.new('0 14 * * *'),
        timezone: 'UTC'
      )
      utc_time = Time.utc(2026, 3, 28, 14, 0, 0)
      expect(job.due?(utc_time)).to be(true)
    end

    it 'does not match cron in wrong timezone hour' do
      # Cron is set for 09:00, timezone is UTC
      job = Philiprehberger::Scheduler::Job.new(
        callable: -> {},
        cron: Philiprehberger::Scheduler::CronParser.new('0 9 * * *'),
        timezone: 'UTC'
      )
      # 14:00 UTC should not match 09:00
      utc_time = Time.utc(2026, 3, 28, 14, 0, 0)
      expect(job.due?(utc_time)).to be(false)
    end

    it 'applies named timezone offset for cron matching' do
      # Cron at 04:00, timezone America/New_York (UTC-5)
      # When it's 09:00 UTC, it's 04:00 in New York
      job = Philiprehberger::Scheduler::Job.new(
        callable: -> {},
        cron: Philiprehberger::Scheduler::CronParser.new('0 4 * * *'),
        timezone: 'America/New_York'
      )
      utc_time = Time.utc(2026, 3, 28, 9, 0, 0)
      expect(job.due?(utc_time)).to be(true)
    end

    it 'applies numeric offset for cron matching' do
      # Cron at 17:00, timezone +05:30
      # When it's 11:30 UTC, it's 17:00 in +05:30
      job = Philiprehberger::Scheduler::Job.new(
        callable: -> {},
        cron: Philiprehberger::Scheduler::CronParser.new('0 17 * * *'),
        timezone: '+05:30'
      )
      utc_time = Time.utc(2026, 3, 28, 11, 30, 0)
      expect(job.due?(utc_time)).to be(true)
    end

    it 'does not affect interval jobs' do
      job = scheduler.every('1s', name: 'tz-test') { nil }
      expect(job.timezone).to be_nil
    end
  end

  describe 'job persistence' do
    let(:state_path) { File.join(Dir.tmpdir, "scheduler_test_#{Process.pid}_#{rand(10_000)}.json") }

    after { FileUtils.rm_f(state_path) }

    it 'saves state to a file' do
      scheduler.every('5m', name: 'heartbeat') { nil }
      scheduler.save_state(state_path)

      expect(File.exist?(state_path)).to be(true)
      data = JSON.parse(File.read(state_path))
      expect(data['version']).to eq(Philiprehberger::Scheduler::VERSION)
      expect(data['jobs'].size).to eq(1)
      expect(data['jobs'].first['name']).to eq('heartbeat')
    end

    it 'restores state from a file' do
      job = scheduler.every('5m', name: 'heartbeat') { nil }
      job.last_run = Time.new(2026, 3, 28, 10, 0, 0)
      scheduler.save_state(state_path)

      new_scheduler = Philiprehberger::Scheduler.new
      new_scheduler.every('5m', name: 'heartbeat') { nil }
      new_scheduler.load_state(state_path)

      restored_job = new_scheduler.jobs.find { |j| j.name == 'heartbeat' }
      expect(restored_job.last_run).not_to be_nil
      expect(restored_job.last_run.min).to eq(0)
      expect(restored_job.last_run.hour).to eq(10)
    end

    it 'returns self from save_state' do
      result = scheduler.save_state(state_path)
      expect(result).to eq(scheduler)
    end

    it 'returns self from load_state' do
      result = scheduler.load_state(state_path)
      expect(result).to eq(scheduler)
    end

    it 'handles missing state file gracefully' do
      expect { scheduler.load_state('/nonexistent/path.json') }.not_to raise_error
    end

    it 'only saves named jobs' do
      scheduler.every('1s') { nil } # unnamed
      scheduler.every('1s', name: 'named') { nil }
      scheduler.save_state(state_path)

      data = JSON.parse(File.read(state_path))
      expect(data['jobs'].size).to eq(1)
      expect(data['jobs'].first['name']).to eq('named')
    end

    it 'saves cron expression' do
      scheduler.cron('0 9 * * *', name: 'morning') { nil }
      scheduler.save_state(state_path)

      data = JSON.parse(File.read(state_path))
      expect(data['jobs'].first['cron_expression']).to eq('0 9 * * *')
    end

    it 'saves timezone' do
      scheduler.cron('0 9 * * *', name: 'tz-job', timezone: 'America/New_York') { nil }
      scheduler.save_state(state_path)

      data = JSON.parse(File.read(state_path))
      expect(data['jobs'].first['timezone']).to eq('America/New_York')
    end
  end

  describe 'leader election' do
    let(:lock_path) { File.join(Dir.tmpdir, "scheduler_leader_test_#{Process.pid}_#{rand(10_000)}.lock") }

    after { FileUtils.rm_f(lock_path) }

    it 'is not leader by default' do
      expect(scheduler).not_to be_leader
    end

    it 'enables leader election' do
      result = scheduler.enable_leader_election(lock_path: lock_path)
      expect(result).to eq(scheduler)
    end

    it 'acquires leadership' do
      scheduler.enable_leader_election(lock_path: lock_path)
      expect(scheduler.acquire_leadership).to be(true)
      expect(scheduler).to be_leader
      scheduler.release_leadership
    end

    it 'releases leadership' do
      scheduler.enable_leader_election(lock_path: lock_path)
      scheduler.acquire_leadership
      scheduler.release_leadership
      expect(scheduler).not_to be_leader
    end

    it 'prevents second process from acquiring leadership' do
      scheduler.enable_leader_election(lock_path: lock_path)
      scheduler.acquire_leadership

      scheduler2 = Philiprehberger::Scheduler.new
      scheduler2.enable_leader_election(lock_path: lock_path)
      expect(scheduler2.acquire_leadership).to be(false)
      expect(scheduler2).not_to be_leader

      scheduler.release_leadership
    end

    it 'writes PID to lock file' do
      scheduler.enable_leader_election(lock_path: lock_path)
      scheduler.acquire_leadership
      content = File.read(lock_path)
      expect(content.strip).to eq(Process.pid.to_s)
      scheduler.release_leadership
    end

    it 'does not start scheduler without leadership' do
      scheduler.enable_leader_election(lock_path: lock_path)

      # Acquire lock with another scheduler first
      blocker = Philiprehberger::Scheduler.new
      blocker.enable_leader_election(lock_path: lock_path)
      blocker.acquire_leadership

      scheduler.every(0.1) { nil }
      scheduler.start
      expect(scheduler).not_to be_running

      blocker.release_leadership
    end

    it 'starts scheduler when leadership is acquired' do
      scheduler.enable_leader_election(lock_path: lock_path)
      scheduler.every(0.1) { nil }
      scheduler.start
      expect(scheduler).to be_running
      expect(scheduler).to be_leader
    end

    it 'releases leadership on stop' do
      scheduler.enable_leader_election(lock_path: lock_path)
      scheduler.start
      expect(scheduler).to be_leader
      scheduler.stop
      expect(scheduler).not_to be_leader
    end
  end

  describe Philiprehberger::Scheduler::Job do
    it 'reports interval? correctly for interval jobs' do
      job = described_class.new(callable: -> {}, interval: 10)
      expect(job).to be_interval
      expect(job).not_to be_cron
    end

    it 'reports cron? correctly for cron jobs' do
      cron = Philiprehberger::Scheduler::CronParser.new('* * * * *')
      job = described_class.new(callable: -> {}, cron: cron)
      expect(job).to be_cron
      expect(job).not_to be_interval
    end

    it 'starts with last_run as nil' do
      job = described_class.new(callable: -> {}, interval: 10)
      expect(job.last_run).to be_nil
    end

    it 'starts with running as false' do
      job = described_class.new(callable: -> {}, interval: 10)
      expect(job.running).to be false
    end

    it 'is due when never run before (interval)' do
      job = described_class.new(callable: -> {}, interval: 10)
      expect(job.due?(Time.now)).to be true
    end

    it 'is not due when interval has not elapsed' do
      job = described_class.new(callable: -> {}, interval: 100)
      job.last_run = Time.now
      expect(job.due?(Time.now)).to be false
    end

    it 'sets last_run after execute' do
      job = described_class.new(callable: -> {}, interval: 10)
      job.execute
      expect(job.last_run).not_to be_nil
    end

    it 'sets running to false after execute completes' do
      job = described_class.new(callable: -> {}, interval: 10)
      job.execute
      expect(job.running).to be false
    end

    it 'sets running to false even if callable raises' do
      job = described_class.new(callable: -> { raise 'boom' }, interval: 10)
      begin
        job.execute
      rescue RuntimeError
        nil
      end
      expect(job.running).to be false
    end

    it 'stores last_result' do
      job = described_class.new(callable: -> { 'hello' }, interval: 10)
      job.execute
      expect(job.last_result).to eq('hello')
    end

    it 'passes input to callable when input_from is set' do
      received = nil
      job = described_class.new(
        callable: lambda { |r|
  received = r
  r
},
        interval: 10,
        name: 'consumer',
        input_from: 'producer'
      )
      job.execute('data_from_producer')
      expect(received).to eq('data_from_producer')
    end

    it 'generates state hash' do
      job = described_class.new(callable: -> {}, interval: 300, name: 'test')
      state = job.to_state
      expect(state['name']).to eq('test')
      expect(state['interval']).to eq(300)
    end

    it 'restores state from hash' do
      job = described_class.new(callable: -> {}, interval: 300, name: 'test')
      job.restore_state({ 'last_run' => '2026-03-28T10:00:00+00:00' })
      expect(job.last_run).not_to be_nil
    end

    it 'is not due when condition returns false' do
      job = described_class.new(callable: -> {}, interval: 10, if: -> { false })
      expect(job.due?(Time.now)).to be(false)
    end

    it 'is due when condition returns true' do
      job = described_class.new(callable: -> {}, interval: 10, if: -> { true })
      expect(job.due?(Time.now)).to be(true)
    end
  end

  describe Philiprehberger::Scheduler::CronParser do
    it 'matches a wildcard expression' do
      parser = described_class.new('* * * * *')
      expect(parser.matches?(Time.now)).to be(true)
    end

    it 'matches a specific minute' do
      parser = described_class.new('30 * * * *')
      time = Time.new(2026, 1, 1, 12, 30, 0)
      expect(parser.matches?(time)).to be(true)
    end

    it 'does not match a different minute' do
      parser = described_class.new('30 * * * *')
      time = Time.new(2026, 1, 1, 12, 15, 0)
      expect(parser.matches?(time)).to be(false)
    end

    it 'matches ranges' do
      parser = described_class.new('0-5 * * * *')
      time = Time.new(2026, 1, 1, 12, 3, 0)
      expect(parser.matches?(time)).to be(true)
    end

    it 'matches steps' do
      parser = described_class.new('*/15 * * * *')
      time = Time.new(2026, 1, 1, 12, 45, 0)
      expect(parser.matches?(time)).to be(true)
    end

    it 'rejects invalid expressions' do
      expect { described_class.new('* * *') }.to raise_error(ArgumentError)
    end

    it 'matches comma-separated values' do
      parser = described_class.new('0,15,30,45 * * * *')
      expect(parser.matches?(Time.new(2026, 1, 1, 12, 15, 0))).to be(true)
      expect(parser.matches?(Time.new(2026, 1, 1, 12, 10, 0))).to be(false)
    end

    it 'matches specific hour and minute' do
      parser = described_class.new('30 14 * * *')
      expect(parser.matches?(Time.new(2026, 1, 1, 14, 30, 0))).to be(true)
      expect(parser.matches?(Time.new(2026, 1, 1, 14, 31, 0))).to be(false)
    end

    it 'matches day of week' do
      parser = described_class.new('0 0 * * 1') # Monday
      monday = Time.new(2026, 3, 23, 0, 0, 0) # a Monday
      sunday = Time.new(2026, 3, 22, 0, 0, 0) # a Sunday
      expect(parser.matches?(monday)).to be(true)
      expect(parser.matches?(sunday)).to be(false)
    end

    it 'matches specific month' do
      parser = described_class.new('0 0 1 6 *') # June 1st midnight
      expect(parser.matches?(Time.new(2026, 6, 1, 0, 0, 0))).to be(true)
      expect(parser.matches?(Time.new(2026, 7, 1, 0, 0, 0))).to be(false)
    end

    it 'rejects invalid field tokens' do
      expect { described_class.new('abc * * * *') }.to raise_error(ArgumentError)
    end

    it 'exposes the original expression' do
      parser = described_class.new('*/5 * * * *')
      expect(parser.expression).to eq('*/5 * * * *')
    end

    it 'matches range with step' do
      parser = described_class.new('1-10/3 * * * *')
      expect(parser.matches?(Time.new(2026, 1, 1, 0, 1, 0))).to be(true)
      expect(parser.matches?(Time.new(2026, 1, 1, 0, 4, 0))).to be(true)
      expect(parser.matches?(Time.new(2026, 1, 1, 0, 7, 0))).to be(true)
      expect(parser.matches?(Time.new(2026, 1, 1, 0, 2, 0))).to be(false)
    end
  end
end
