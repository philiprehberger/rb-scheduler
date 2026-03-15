# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::Scheduler do
  subject(:scheduler) { described_class.new }

  after { scheduler.stop }

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
  end

  describe '#cron' do
    it 'schedules a job with a cron expression' do
      scheduler.cron('*/5 * * * *') { nil }
      expect(scheduler.jobs.size).to eq(1)
      expect(scheduler.jobs.first).to be_cron
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
  end

  describe 'job execution' do
    it 'fires a due interval job' do
      called = false
      scheduler.every(0.1) { called = true }
      scheduler.start
      sleep(0.5)
      expect(called).to be(true)
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
  end

  describe 'CronParser' do
    it 'matches a wildcard expression' do
      parser = Philiprehberger::Scheduler::CronParser.new('* * * * *')
      expect(parser.matches?(Time.now)).to be(true)
    end

    it 'matches a specific minute' do
      parser = Philiprehberger::Scheduler::CronParser.new('30 * * * *')
      time = Time.new(2026, 1, 1, 12, 30, 0)
      expect(parser.matches?(time)).to be(true)
    end

    it 'does not match a different minute' do
      parser = Philiprehberger::Scheduler::CronParser.new('30 * * * *')
      time = Time.new(2026, 1, 1, 12, 15, 0)
      expect(parser.matches?(time)).to be(false)
    end

    it 'matches ranges' do
      parser = Philiprehberger::Scheduler::CronParser.new('0-5 * * * *')
      time = Time.new(2026, 1, 1, 12, 3, 0)
      expect(parser.matches?(time)).to be(true)
    end

    it 'matches steps' do
      parser = Philiprehberger::Scheduler::CronParser.new('*/15 * * * *')
      time = Time.new(2026, 1, 1, 12, 45, 0)
      expect(parser.matches?(time)).to be(true)
    end

    it 'rejects invalid expressions' do
      expect { Philiprehberger::Scheduler::CronParser.new('* * *') }.to raise_error(ArgumentError)
    end
  end
end
