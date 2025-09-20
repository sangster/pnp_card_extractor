# frozen_string_literal: true

guard :rspec, cmd: :rspec do
  watch('spec/rspec_helper.rb')
  watch(%r{^spec/(.*)_spec.rb$})

  watch(%r{^lib/(.+)\.rb$}) { "spec/#{_1[1]}_spec.rb" }
end

guard :rubocop, keep_failed: false, cli: %w[-D] do
  watch(/.+\.rb$/)
  watch(%r{(?:.+/)?\.rubocop(?:_todo)?\.yml$}) { File.dirname(_1[0]) }
end
