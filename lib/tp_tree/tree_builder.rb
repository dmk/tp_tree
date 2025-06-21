# frozen_string_literal: true

require_relative 'tree_node'

module TPTree
  # TreeBuilder uses TracePoint to build a tree of method calls.
  class TreeBuilder
    attr_reader :events

    def initialize(method_filter: nil, &block)
      @events = []
      @call_depth = 0
      @call_stack = []
      @method_filter = method_filter
      @block = block
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

      @events.compact
    end

    private

    def handle_call(tp)
      # Apply filtering if a method filter is configured
      if @method_filter && !@method_filter.should_include?(tp.callee_id, tp.defined_class, tp)
        return
      end

      param_values = extract_parameters(tp)
      call_time = Time.now

      call_info = {
        method_name: tp.callee_id,
        parameters: param_values,
        depth: @call_depth,
        event_index: @events.length,
        defined_class: tp.defined_class,
        path: tp.path,
        lineno: tp.lineno,
        start_time: call_time
      }
      @call_stack.push(call_info)
      @events << nil # Placeholder
      @call_depth += 1
    end

    def handle_return(tp)
      # If method was filtered out during call, there won't be anything on the stack
      return if @call_stack.empty?

      # Check if this return matches the last call (in case of nested filtered calls)
      call_info = @call_stack.last
      return unless call_info && call_info[:method_name] == tp.callee_id

      @call_depth -= 1
      call_info = @call_stack.pop
      return_time = Time.now

      has_children = @events.length > call_info[:event_index] + 1

      if has_children
        @events[call_info[:event_index]] = TreeNode.new(
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
        @events << TreeNode.new(
          :return,
          tp.callee_id,
          nil,
          tp.return_value,
          @call_depth,
          tp.defined_class,
          tp.path,
          tp.lineno,
          call_info[:start_time],
          return_time
        )
      else
        @events[call_info[:event_index]] = TreeNode.new(
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