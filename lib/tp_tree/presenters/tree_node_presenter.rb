# frozen_string_literal: true

require_relative '../formatters/ansi_formatter'

module TPTree
  module Presenters
    # TreeNodePresenter handles the formatting and display logic for TreeNode objects
    class TreeNodePresenter
      def initialize(tree_node, formatter: nil)
        @tree_node = tree_node
        @formatter = formatter || Formatters::AnsiFormatter.new
      end

      def to_s
        prefix = build_prefix
        color = @formatter.color_for_depth(@tree_node.depth)
        colored_method_name = @formatter.colorize(@tree_node.method_name, color)
        timing_info = @formatter.format_timing(@tree_node.duration)

        case @tree_node.event
        when :call
          "#{prefix}#{colored_method_name}(#{@formatter.format_parameters(@tree_node.parameters)})#{timing_info}"
        when :return
          "#{prefix}#{@formatter.format_return_value(@tree_node.return_value)}#{timing_info}"
        when :call_return
          "#{prefix}#{colored_method_name}(#{@formatter.format_parameters(@tree_node.parameters)}) → #{@formatter.format_return_value(@tree_node.return_value)}#{timing_info}"
        end
      end

      def to_parts
        prefix_parts = build_prefix_parts
        color = @formatter.color_for_depth(@tree_node.depth)
        colored_method_name = @formatter.colorize(@tree_node.method_name, color)
        timing_info = @formatter.format_timing(@tree_node.duration)

        content = case @tree_node.event
                  when :call
                    "#{colored_method_name}(#{@formatter.format_parameters(@tree_node.parameters)})#{timing_info}"
                  when :return
                    "#{@formatter.format_return_value(@tree_node.return_value)}#{timing_info}"
                  when :call_return
                    "#{colored_method_name}(#{@formatter.format_parameters(@tree_node.parameters)}) → #{@formatter.format_return_value(@tree_node.return_value)}#{timing_info}"
                  end
        [prefix_parts, content]
      end

      private

      def build_prefix_parts
        parts = []
        color = @formatter.color_for_depth(@tree_node.depth)

        if @tree_node.event == :return
          (0...@tree_node.depth).each do |level|
            parts << ['│  ', @formatter.color_for_depth(level)]
          end
          parts << ['└→ ', color]
          return parts
        end

        return [] if @tree_node.depth.zero?

        (0...@tree_node.depth).each do |level|
          parts << ['│  ', @formatter.color_for_depth(level)]
        end
        parts
      end

      def build_prefix
        build_prefix_parts.map do |text, color|
          @formatter.colorize(text, color)
        end.join
      end
    end
  end
end