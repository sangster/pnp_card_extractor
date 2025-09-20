# frozen_string_literal: true

module PnpCardExtractor
  # A service to compile a pathname from a template string possibly containing
  # variables.
  #
  # Each variable must be surrounded by curly braces and may use dot-notation
  # for nested variables.
  #
  # You can also include text conditionally, based on the truthiness of a
  # variable, separating the variable and text with a question mark. For
  # example, {type.is_subtype ? "hard-coded text"} or {is_cool ? foo.bar.baz}
  #
  # Example:
  #
  #   ./output-cards/{pack.code}/{faction_code}/{code} - {title}.png
  class FilenameTemplate
    # An individual part of the total filename, either a dirname or basename.
    class Component
      attr_reader :template

      def initialize(template)
        @template = template
      end

      def call(hash)
        compile(hash).gsub(%r{\\|/}, '-')
      end

      private

      def compile(hash)
        template.gsub(/\{\s*([^}]+)\s*\}/) do
          parse_expr(Regexp.last_match(1).strip, hash)
        end
      end

      def parse_expr(expr, hash)
        # conditional form?
        if (m = /\A(.+?)\?\s*((?:"[^"]*")|(?:\w+(?:\.\w+)*))\z/.match(expr))
          # predicate, like {is_foo ? "text"} or {is_foo ? foo.bar}
          if lookup(hash, m[1].strip)
            m[2][0] == '"' ? m[2][1..-2] : lookup(hash, m[2])
          else
            ''
          end
        else
          # raw variable, like {foo.bar}
          lookup(hash, expr)
        end
      end

      def lookup(hash, path)
        hash.to_h.dig(*path.split('.'))
      end
    end

    attr_reader :template

    def initialize(template)
      @template = template.to_s
    end

    def call(hash)
      parts = components.map { _1.call(hash) }
      parts[1..].inject(Pathname(parts.first)) { _1 / _2 }
    end

    def components
      @components ||= begin
        parts = template.split('/')
        parts = parts[1..].prepend('/') if parts.first.empty?
        parts.map { Component.new(_1) }
      end
    end
  end
end
