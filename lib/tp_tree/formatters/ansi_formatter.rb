# frozen_string_literal: true

require_relative 'base_formatter'

module TPTree
  module Formatters
    # AnsiFormatter provides ANSI color code formatting for terminal output
    class AnsiFormatter < BaseFormatter
      def colorize(text, color)
        color_codes = {
          black: 30, red: 31, green: 32, yellow: 33,
          blue: 34, magenta: 35, cyan: 36, white: 37
        }

        code = color_codes[color] || 37
        "\e[#{code}m#{text}\e[0m"
      end
    end
  end
end