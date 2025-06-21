# frozen_string_literal: true

module TPTree
  # Formatter provides methods for colorizing and formatting output.
  module Formatter
    # Color codes for different depth levels in the call tree
    DEPTH_COLORS = [:green, :blue, :yellow, :magenta, :cyan, :red].freeze

    def colorize(text, color)
      color_codes = {
        black: 30, red: 31, green: 32, yellow: 33,
        blue: 34, magenta: 35, cyan: 36, white: 37
      }

      code = color_codes[color] || 37
      "\e[#{code}m#{text}\e[0m"
    end

    def format_timing(duration)
      return '' if duration.nil?

      formatted_time = if duration < 0.001
        "#{(duration * 1_000_000).round(1)}μs"
      elsif duration < 1.0
        "#{(duration * 1000).round(1)}ms"
      else
        "#{duration.round(3)}s"
      end

      colorize(" [#{formatted_time}]", :cyan)
    end

    def format_parameters(parameters)
      return '' if parameters.nil? || parameters.empty?

      parameters.map { |param_type, param_name, param_value|
        case param_type
        when :req, :opt
          "#{param_name} = #{format_value(param_value)}"
        when :keyreq, :key
          if param_value.nil?
            "#{param_name}:"
          else
            "#{param_name} = #{format_value(param_value)}"
          end
        when :rest
          "*#{param_name}"
        when :keyrest
          "**#{param_name}"
        when :block
          "&#{param_name}"
        else
          param_name.to_s
        end
      }.join(', ')
    end

    def format_value(value)
      case value
      when String
        value.inspect
      when Symbol
        ":#{value}"
      when NilClass
        'nil'
      when TrueClass, FalseClass
        value.to_s
      when Numeric
        value.to_s
      when Array
        "[#{value.map { |v| format_value(v) }.join(', ')}]"
      when Hash
        "{#{value.map { |k, v| "#{format_value(k)} => #{format_value(v)}" }.join(', ')}}"
      when Proc
        'Proc'
      else
        value.inspect
      end
    end

    def format_return_value(return_value)
      format_value(return_value)
    end

    def color_for_depth(depth)
      DEPTH_COLORS[depth % DEPTH_COLORS.length]
    end
  end
end