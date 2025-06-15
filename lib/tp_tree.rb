# frozen_string_literal: true

require_relative "tp_tree/version"

module TPTree
  # Color codes for different depth levels in the call tree
  DEPTH_COLORS = [:green, :blue, :yellow, :magenta, :cyan, :red].freeze

  # TreeNode represents a single event (call or return) in the method call tree
  class TreeNode
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
      colored_method_name = colorize(@method_name, color_for_depth)

      case @event
      when :call
        "#{prefix}#{colored_method_name}(#{format_parameters})"
      when :return
        "#{prefix}#{format_return_value}"
      when :call_return
        "#{prefix}#{colored_method_name}(#{format_parameters}) → #{format_return_value}"
      end
    end

    private

    def build_prefix
      if @event == :return
        prefix = ''
        # Add colored pipes for parent levels
        (0...@depth).each do |level|
          color = DEPTH_COLORS[level % DEPTH_COLORS.length]
          prefix += colorize('│  ', color)
        end
        # Add return arrow for current level
        color = DEPTH_COLORS[@depth % DEPTH_COLORS.length]
        prefix += colorize('└→ ', color)
        return prefix
      end

      return '' if @depth == 0

      prefix = ''
      (0...@depth).each do |level|
        color = DEPTH_COLORS[level % DEPTH_COLORS.length]
        prefix += colorize('│  ', color)
      end
      prefix
    end

    def color_for_depth
      DEPTH_COLORS[@depth % DEPTH_COLORS.length]
    end

    def colorize(text, color)
      color_codes = {
        black: 30, red: 31, green: 32, yellow: 33,
        blue: 34, magenta: 35, cyan: 36, white: 37
      }

      code = color_codes[color] || 37
      "\e[#{code}m#{text}\e[0m"
    end

    def format_parameters
      return '' if @parameters.nil? || @parameters.empty?

      @parameters.map { |param_type, param_name, param_value|
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

    def format_return_value
      format_value(@return_value)
    end
  end

  class <<self
    # catch sets up a TracePoint to monitor method calls and returns,
    # printing them in chronological order with proper tree indentation.
    # Methods without child calls are shown as single call -> return lines.
    # Each depth level uses a different color for visual clarity.
    def catch(signals = %i[call return], &block)
      events = []
      call_depth = 0
      call_stack = []

      tp = TracePoint.trace(*signals) do |tp|
        # Skip tp.disable call
        next if tp.callee_id == :disable && tp.defined_class == TracePoint

        case tp.event
        when :call
          # Try to get parameter values from binding
          param_values = []
          if tp.binding
            tp.parameters.each do |param_type, param_name|
              begin
                case param_type
                when :req, :opt, :keyreq, :key
                  value = tp.binding.local_variable_get(param_name)
                  param_values << [param_type, param_name, value]
                else
                  param_values << [param_type, param_name, nil]
                end
              rescue NameError
                param_values << [param_type, param_name, nil]
              end
            end
          else
            param_values = tp.parameters.map { |type, name| [type, name, nil] }
          end

          call_info = {
            method_name: tp.callee_id,
            parameters: param_values,
            depth: call_depth,
            event_index: events.length
          }
          call_stack.push(call_info)
          # Add placeholder for call event
          events << nil
          call_depth += 1
        when :return
          call_depth -= 1
          call_info = call_stack.pop

          # Check if any events were added between call and return (meaning it had children)
          has_children = events.length > call_info[:event_index] + 1

          if has_children
            # Replace placeholder with call event and add return event
            events[call_info[:event_index]] = TreeNode.new(:call, call_info[:method_name], call_info[:parameters], nil, call_info[:depth])
            events << TreeNode.new(:return, tp.callee_id, nil, tp.return_value, call_depth)
          else
            # Replace placeholder with combined call_return event
            events[call_info[:event_index]] = TreeNode.new(:call_return, call_info[:method_name], call_info[:parameters], tp.return_value, call_info[:depth])
          end
        end
      end

      yield(block)
      tp.disable

      events.compact.each { |event| puts event }
    end
  end
end
