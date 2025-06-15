# frozen_string_literal: true

require_relative 'formatter'

module TPTree
  # TreeNode represents a single event in the method call tree
  class TreeNode
    include Formatter

    attr_reader :event, :method_name, :parameters, :return_value, :depth, :defined_class, :path, :lineno

    def initialize(event, method_name, parameters = nil, return_value = nil, depth = 0, defined_class = nil, path = nil, lineno = nil)
      @event = event
      @method_name = method_name
      @parameters = parameters
      @return_value = return_value
      @depth = depth
      @defined_class = defined_class
      @path = path
      @lineno = lineno
    end

    def to_s(formatter: self)
      prefix = build_prefix(formatter: formatter)
      color = formatter.color_for_depth(depth)
      colored_method_name = formatter.colorize(@method_name, color)

      case @event
      when :call
        "#{prefix}#{colored_method_name}(#{formatter.format_parameters(@parameters)})"
      when :return
        "#{prefix}#{formatter.format_return_value(@return_value)}"
      when :call_return
        "#{prefix}#{colored_method_name}(#{formatter.format_parameters(@parameters)}) → #{formatter.format_return_value(@return_value)}"
      end
    end

    def to_parts(formatter: self)
      prefix_parts = build_prefix_parts(formatter: formatter)
      color = formatter.color_for_depth(depth)
      colored_method_name = formatter.colorize(@method_name, color)

      content = case @event
                when :call
                  "#{colored_method_name}(#{formatter.format_parameters(@parameters)})"
                when :return
                  "#{formatter.format_return_value(@return_value)}"
                when :call_return
                  "#{colored_method_name}(#{formatter.format_parameters(@parameters)}) → #{formatter.format_return_value(@return_value)}"
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