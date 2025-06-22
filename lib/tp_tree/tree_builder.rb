# frozen_string_literal: true

require_relative 'tree_node'
require_relative 'call_stack'

module TPTree
  # TreeBuilder uses TracePoint to build a tree of method calls.
  class TreeBuilder
    attr_reader :events

    def initialize(method_filter: nil, &block)
      @call_stack = CallStack.new
      @method_filter = method_filter
      @block = block
    end

    def events
      @call_stack.events
    end

    def build
      tp = TracePoint.trace(:call, :return) do |tp|
        next if tp.callee_id == :disable && tp.defined_class == TracePoint

        case tp.event
        when :call
          handle_call(tp)
        when :return
          handle_return(tp)
        end
      end

      @block.call
      tp.disable

      events
    end

    private

    def handle_call(tp)
      # Apply filtering if a method filter is configured
      if @method_filter && !@method_filter.should_include?(tp.callee_id, tp.defined_class, tp)
        return
      end

      param_values = extract_parameters(tp)
      call_time = Time.now

      @call_stack.start_call(
        tp.callee_id,
        param_values,
        tp.defined_class,
        tp.path,
        tp.lineno,
        call_time
      )
    end

        def handle_return(tp)
      return_time = Time.now
      call_info = @call_stack.finish_call(tp.callee_id, tp.return_value, return_time)

      # If call_info is nil, the method was filtered out during call
      return unless call_info

      if call_info[:has_children]
        # Create separate call and return events
        call_node = TreeNode.new(
          :call,
          call_info[:method_name],
          call_info[:parameters],
          nil,
          call_info[:depth],
          call_info[:defined_class],
          call_info[:path],
          call_info[:lineno],
          call_info[:start_time],
          return_time
        )

        return_node = TreeNode.new(
          :return,
          tp.callee_id,
          nil,
          tp.return_value,
          @call_stack.current_depth,
          tp.defined_class,
          tp.path,
          tp.lineno,
          call_info[:start_time],
          return_time
        )

        # Replace placeholder and add return event
        @call_stack.set_event_at_index(call_info[:event_index], call_node)
        @call_stack.add_event(return_node)
      else
        # Create single call_return event
        call_return_node = TreeNode.new(
          :call_return,
          call_info[:method_name],
          call_info[:parameters],
          tp.return_value,
          call_info[:depth],
          call_info[:defined_class],
          call_info[:path],
          call_info[:lineno],
          call_info[:start_time],
          return_time
        )

        # Replace placeholder
        @call_stack.set_event_at_index(call_info[:event_index], call_return_node)
      end
    end

    def extract_parameters(tp)
      return tp.parameters.map { |type, name| [type, name, nil] } unless tp.binding

      tp.parameters.map do |param_type, param_name|
        begin
          value = case param_type
                  when :req, :opt, :keyreq, :key
                    tp.binding.local_variable_get(param_name)
                  else
                    nil
                  end
          [param_type, param_name, value]
        rescue NameError
          [param_type, param_name, nil]
        end
      end
    end
  end
end