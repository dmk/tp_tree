# frozen_string_literal: true

require_relative 'formatter'

module TPTree
  # TreeNode represents a single event in the method call tree
  class TreeNode
    include Formatter

    attr_reader :event, :method_name, :parameters, :return_value, :depth

    def initialize(event, method_name, parameters = nil, return_value = nil, depth = 0)
      @event = event
      @method_name = method_name
      @parameters = parameters
      @return_value = return_value
      @depth = depth
    end

    def to_s
      prefix = build_prefix
      color = color_for_depth(depth)
      colored_method_name = colorize(@method_name, color)

      case @event
      when :call
        "#{prefix}#{colored_method_name}(#{format_parameters(@parameters)})"
      when :return
        "#{prefix}#{format_return_value(@return_value)}"
      when :call_return
        "#{prefix}#{colored_method_name}(#{format_parameters(@parameters)}) → #{format_return_value(@return_value)}"
      end
    end

    private

    def build_prefix
      color = color_for_depth(depth)
      if @event == :return
        prefix = ''
        (0...@depth).each do |level|
          parent_color = color_for_depth(level)
          prefix += colorize('│  ', parent_color)
        end
        prefix += colorize('└→ ', color)
        return prefix
      end

      return '' if @depth == 0

      prefix = ''
      (0...@depth).each do |level|
        parent_color = color_for_depth(level)
        prefix += colorize('│  ', parent_color)
      end
      prefix
    end
  end
end