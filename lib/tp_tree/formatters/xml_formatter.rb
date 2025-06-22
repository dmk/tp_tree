# frozen_string_literal: true

require_relative 'base_formatter'

module TPTree
  module Formatters
    # XmlFormatter provides XML tag formatting for structured output
    class XmlFormatter < BaseFormatter
      def colorize(text, color)
        "<#{color}>#{text}</#{color}>"
      end
    end
  end
end