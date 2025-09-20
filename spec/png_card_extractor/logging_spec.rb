# frozen_string_literal: true

RSpec.describe Logging do
  describe '.wrap_logger' do
    subject { described_class.wrap_logger(logger) }

    context 'when given a truthy value' do
      let(:logger) { :foo }

      it { is_expected.to be logger }
    end

    context 'when given a falsey value' do
      let(:logger) { nil }

      it { is_expected.to be_a Logging::NilLogger }
    end
  end

  describe '.nil_logger' do
    subject { described_class.nil_logger }

    it { is_expected.to be_a Logging::NilLogger }
  end
end
