# frozen_string_literal: true

module PnpCardExtractor
  module Services
    # This service provides a simple syntax for specifying numbers:
    #
    # - A comma-or-space seprated list of integers or "ranges."
    # - A range is a dash-separated pair of integers, defining the minimum and
    #   maximum bounds of a range, inclusive.
    # - Both the minimum and maximum numbers, in a range, are optional. If
    #   absent, the smallest or largest possible number will be used by default.
    #
    # Examples:
    #
    # - "-3, 7, 10-20, 50-"
    # - "1 2 3 4"
    # - "10-"
    # - "-20"
    # - "-"
    class SelectNumbers
      include Enumerable

      InvalidRange = Class.new(Error)

      STRING_DELIM = /(?:\s|,)+/
      STRING_RANGE = /\A(\d*)-(\d*)\z/
      SINGLE_NUMBER = /\A\d+\z/

      attr_reader :min, :max, :unique, :valid_range

      def initialize(*ranges, max:, min: 1, unique: false)
        @max = max
        @min = min
        @valid_range = (min..max)
        @entries = unique ? Set.new : []
        @unique = unique

        ranges.each { push(_1) }
        @entries.freeze
      end

      def [](idx)
        to_a[idx]
      end

      def size
        to_a.size
      end

      def to_a
        @to_a ||= @entries.to_a
      end

      def each(...)
        @entries.each(...)
      end

      private

      def push(range)
        @to_a = nil

        case range
        when String
          parse_string(range).each { push(_1) } if validate_string!(range)
        when Integer then @entries << range if validate_single!(range)
        when Range then range.each { @entries << _1 } if validate_range!(range)
        else
          raise Error, "Unexpected range (#{range.class}): #{range}"
        end
      end

      def parse_string(str)
        split_string(str).map do |range_str|
          if (m = STRING_RANGE.match(range_str))
            min_val = m[1].empty? ? min : m[1].to_i
            max_val = m[2].empty? ? max : m[2].to_i
            (min_val..max_val)
          else
            range_str.to_i
          end
        end
      end

      def split_string(str)
        str.strip.split(STRING_DELIM)
      end

      def validate_string!(str)
        return true if split_string(str).all? { string_part?(_1) }

        raise InvalidRange, "'#{str}' is not a valid list of ranges"
      end

      def string_part?(str)
        SINGLE_NUMBER.match?(str) || STRING_RANGE.match?(str)
      end

      def validate_single!(number)
        return true if valid_range.include?(number)

        raise InvalidRange, "#{number} not in range #{r_to_s valid_range}"
      end

      def validate_range!(range)
        return true if range.minmax.all? { valid_range.include?(_1) }

        raise InvalidRange, "#{r_to_s range} not in range #{r_to_s valid_range}"
      end

      def r_to_s(range)
        range.minmax.join('-')
      end
    end
  end
end
