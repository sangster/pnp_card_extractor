# frozen_string_literal: true

require 'rspec/core/rake_task'
require 'rubocop/rake_task'

task default: :test

RSpec::Core::RakeTask.new(:test)
RuboCop::RakeTask.new

desc 'Start an REPL with default `options` and `database`'
task :console do
  sh 'irb -I scripts -r console_env'
end
