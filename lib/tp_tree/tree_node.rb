# frozen_string_literal: true

require_relative 'formatter'
require_relative 'presenters/tree_node_presenter'

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

    def to_hash
      {
        event: @event,
        method_name: @method_name,
        parameters: serialize_parameters(@parameters),
        return_value: serialize_value(@return_value),
        depth: @depth,
        defined_class: @defined_class&.to_s,
        path: @path,
        lineno: @lineno,
        start_time: @start_time&.to_f,
        end_time: @end_time&.to_f,
        duration: duration
      }
    end

    def to_s(formatter: self)
      # Create appropriate formatter for presenter
      presenter_formatter = if formatter.respond_to?(:formatter)
                              formatter.formatter
                            elsif formatter.respond_to?(:colorize)
                              formatter
                            else
                              # Fallback to default ANSI formatter
                              Formatters::AnsiFormatter.new
                            end

      presenter = Presenters::TreeNodePresenter.new(self, formatter: presenter_formatter)
      presenter.to_s
    end

    def to_parts(formatter: self)
      # Create appropriate formatter for presenter
      presenter_formatter = if formatter.respond_to?(:formatter)
                              formatter.formatter
                            elsif formatter.respond_to?(:colorize)
                              formatter
                            else
                              # Fallback to default ANSI formatter
                              Formatters::AnsiFormatter.new
                            end

      presenter = Presenters::TreeNodePresenter.new(self, formatter: presenter_formatter)
      presenter.to_parts
    end

    private

    def serialize_parameters(parameters)
      return nil unless parameters
      parameters.map { |param_type, param_name, param_value|
        {
          type: param_type,
          name: param_name,
          value: serialize_value(param_value)
        }
      }
    end

    def serialize_value(value)
      case value
      when String
        # Handle binary strings that can't be converted to UTF-8
        if value.encoding == Encoding::ASCII_8BIT || !value.valid_encoding?
          # For binary data, show type and size instead of content
          "[Binary data: #{value.bytesize} bytes]"
        else
          value
        end
      when Symbol, NilClass, TrueClass, FalseClass, Numeric
        value
      when Array
        value.map { |v| serialize_value(v) }
      when Hash
        value.transform_values { |v| serialize_value(v) }
      when Proc
        'Proc'
      else
        # Safely inspect objects, handling encoding issues
        begin
          inspected = value.inspect
          if inspected.valid_encoding?
            inspected
          else
            "[Object: #{value.class}]"
          end
        rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
          "[Object: #{value.class}]"
        end
      end
    end
  end
end