# frozen_string_literal: true

require_relative 'lib/philiprehberger/scheduler/version'

Gem::Specification.new do |spec|
  spec.name = 'philiprehberger-scheduler'
  spec.version = Philiprehberger::Scheduler::VERSION
  spec.authors = ['Philip Rehberger']
  spec.email = ['me@philiprehberger.com']

  spec.summary = 'Lightweight in-process task scheduler with cron and interval support'
  spec.description = 'A lightweight in-process task scheduler for Ruby. ' \
                     'Schedule recurring tasks using simple intervals or cron ' \
                     'expressions with overlap prevention and graceful shutdown.'
  spec.homepage = 'https://github.com/philiprehberger/rb-scheduler'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => spec.homepage,
    'changelog_uri' => "#{spec.homepage}/blob/main/CHANGELOG.md",
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'rubygems_mfa_required' => 'true'
  }

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
