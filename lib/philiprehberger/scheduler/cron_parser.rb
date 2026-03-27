# frozen_string_literal: true

module Philiprehberger
  class Scheduler
    class CronParser
      FIELD_RANGES = [
        0..59,  # minute
        0..23,  # hour
        1..31,  # day of month
        1..12,  # month
        0..6    # day of week (0 = Sunday)
      ].freeze

      attr_reader :expression

      def initialize(expression)
        @expression = expression
        @fields = parse(expression)
      end

      def matches?(time)
        values = [time.min, time.hour, time.day, time.month, time.wday]
        @fields.each_with_index.all? { |field, i| field.include?(values[i]) }
      end

      private

      def parse(expression)
        parts = expression.strip.split(/\s+/)
        raise ArgumentError, "expected 5 fields, got #{parts.size}" unless parts.size == 5

        parts.each_with_index.map { |part, i| parse_field(part, FIELD_RANGES[i]) }
      end

      def parse_field(field, range)
        field.split(',').flat_map { |token| parse_token(token, range) }.uniq.sort
      end

      def parse_token(token, range)
        case token
        when '*'
          range.to_a
        when %r{\A\*/(\d+)\z}
          range.step(::Regexp.last_match(1).to_i).to_a
        when /\A(\d+)-(\d+)\z/
          (::Regexp.last_match(1).to_i..::Regexp.last_match(2).to_i).to_a
        when %r{\A(\d+)-(\d+)/(\d+)\z}
          (::Regexp.last_match(1).to_i..::Regexp.last_match(2).to_i).step(::Regexp.last_match(3).to_i).to_a
        when /\A\d+\z/
          [token.to_i]
        else
          raise ArgumentError, "invalid cron field: #{token}"
        end
      end
    end
  end
end
