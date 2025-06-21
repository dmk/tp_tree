# frozen_string_literal: true

require_relative 'formatter'

module TPTree
  # TreeNode represents a single event in the method call tree
  class TreeNode
    include Formatter

    attr_reader :event, :method_name, :parameters, :return_value, :depth, :defined_class, :path, :lineno, :start_time, :end_time

    def initialize(event, method_name, parameters = nil, return_value = nil, depth = 0, defined_class = nil, path = nil, lineno = nil, start_time = nil, end_time = nil)
      @event = event
      @method_name = method_name
      @parameters = parameters
      @return_value = return_value
      @depth = depth
      @defined_class = defined_class
      @path = path
      @lineno = lineno
      @start_time = start_time
      @end_time = end_time
    end

    def duration
      return nil unless @start_time && @end_time
      @end_time - @start_time
    end

    def to_s(formatter: self)
      prefix = build_prefix(formatter: formatter)
      color = formatter.color_for_depth(depth)
      colored_method_name = formatter.colorize(@method_name, color)
      timing_info = formatter.format_timing(duration)

      case @event
      when :call
        "#{prefix}#{colored_method_name}(#{formatter.format_parameters(@parameters)})#{timing_info}"
      when :return
        "#{prefix}#{formatter.format_return_value(@return_value)}#{timing_info}"
      when :call_return
        "#{prefix}#{colored_method_name}(#{formatter.format_parameters(@parameters)}) → #{formatter.format_return_value(@return_value)}#{timing_info}"
      end
    end

    def to_parts(formatter: self)
      prefix_parts = build_prefix_parts(formatter: formatter)
      color = formatter.color_for_depth(depth)
      colored_method_name = formatter.colorize(@method_name, color)
      timing_info = formatter.format_timing(duration)

      content = case @event
                when :call
                  "#{colored_method_name}(#{formatter.format_parameters(@parameters)})#{timing_info}"
                when :return
                  "#{formatter.format_return_value(@return_value)}#{timing_info}"
                when :call_return
                  "#{colored_method_name}(#{formatter.format_parameters(@parameters)}) → #{formatter.format_return_value(@return_value)}#{timing_info}"
                end
      [prefix_parts, content]
    end

    private

    def build_prefix_parts(formatter: self)
      parts = []
      color = formatter.color_for_depth(depth)

      if @event == :return
        (0...@depth).each do |level|
          parts << ['│  ', formatter.color_for_depth(level)]
        end
        parts << ['└→ ', color]
        return parts
      end

      return [] if @depth.zero?

      (0...@depth).each do |level|
        parts << ['│  ', formatter.color_for_depth(level)]
      end
      parts
    end

    def build_prefix(formatter: self)
      build_prefix_parts(formatter: formatter).map do |text, color|
        formatter.colorize(text, color)
      end.join
    end
  end
end