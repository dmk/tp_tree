# frozen_string_literal: true

require_relative 'tree_node'

module TPTree
  # TreeBuilder uses TracePoint to build a tree of method calls.
  class TreeBuilder
    attr_reader :events

    def initialize(&block)
      @events = []
      @call_depth = 0
      @call_stack = []
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
      param_values = extract_parameters(tp)

      call_info = {
        method_name: tp.callee_id,
        parameters: param_values,
        depth: @call_depth,
        event_index: @events.length
      }
      @call_stack.push(call_info)
      @events << nil # Placeholder
      @call_depth += 1
    end

    def handle_return(tp)
      @call_depth -= 1
      call_info = @call_stack.pop

      has_children = @events.length > call_info[:event_index] + 1

      if has_children
        @events[call_info[:event_index]] = TreeNode.new(:call, call_info[:method_name], call_info[:parameters], nil, call_info[:depth])
        @events << TreeNode.new(:return, tp.callee_id, nil, tp.return_value, @call_depth)
      else
        @events[call_info[:event_index]] = TreeNode.new(:call_return, call_info[:method_name], call_info[:parameters], tp.return_value, call_info[:depth])
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