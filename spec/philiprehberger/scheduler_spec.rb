# frozen_string_literal: true

require 'spec_helper'

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
