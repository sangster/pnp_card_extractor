# frozen_string_literal: true

require 'poppler'

module PnpCardExtractor
  module Apps
    # Prints the available card packs and their codes.
    class ListCardPacks < Base
      def call
        cycles.each { print_cycle_sets(*_1.values_at('code', 'name')) }
      end

      private

      def cycles
        @cycles ||= database.cycles
      end

      def print_cycle_sets(cycle_code, cycle_name)
        if cycle_packs[cycle_code].size == 1
          print_single_set(cycle_code)
        else
          print_list_of_sets(cycle_code, cycle_name)
        end
      end

      def print_single_set(cycle_code)
        pack = cycle_packs[cycle_code].first
        code, name, date = pack.values_at('code', 'name', 'date_release')
        printf(cycle_pattern, code, name, date)
      end

      def print_list_of_sets(cycle_code, cycle_name)
        cycle_packs[cycle_code].each do |pack|
          code, name, date = pack.values_at('code', 'name', 'date_release')
          printf(pack_pattern, code, cycle_name, name, date)
        end
      end

      def cycle_pattern
        @cycle_pattern ||= "% #{code_len}s  %s (%s)\n"
      end

      def pack_pattern
        @pack_pattern ||= "% #{code_len}s  %s: %s (%s)\n"
      end

      def code_len
        @code_len ||= packs.map { _1.code.size }.max
      end

      def packs
        @packs ||= database.packs
      end

      def cycle_packs
        @cycle_packs ||= cycles.to_h do |cycle|
          [cycle.code,
           packs.select { _1.cycle_code == cycle.code }.sort_by(&:position)]
        end
      end

      def database
        options.database
      end
    end
  end
end
