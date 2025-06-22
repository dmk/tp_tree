# frozen_string_literal: true

require_relative 'formatters/ansi_formatter'

module TPTree
  # Formatter provides methods for colorizing and formatting output.
  # This module acts as a compatibility layer for the old Formatter module.
  module Formatter
    def self.included(base)
      base.extend(FormatterMethods)
      base.include(FormatterMethods)
    end

    module FormatterMethods
      def formatter
        @formatter ||= Formatters::AnsiFormatter.new
      end

      def colorize(text, color)
        formatter.colorize(text, color)
      end

      def format_timing(duration)
        formatter.format_timing(duration)
      end

      def format_parameters(parameters)
        formatter.format_parameters(parameters)
      end

      def format_value(value)
        formatter.format_value(value)
      end

      def format_return_value(return_value)
        formatter.format_return_value(return_value)
      end

      def color_for_depth(depth)
        formatter.color_for_depth(depth)
      end
    end

    # Expose constants for backward compatibility
    DEPTH_COLORS = Formatters::BaseFormatter::DEPTH_COLORS
  end
end