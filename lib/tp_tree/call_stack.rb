# frozen_string_literal: true

module TPTree
  # CallStack manages the state of method calls during tracing
  class CallStack
    def initialize
      @call_stack = []
      @call_depth = 0
      @events = []
    end

    def start_call(method_name, parameters, defined_class, path, lineno, start_time)
      call_info = {
        method_name: method_name,
        parameters: parameters,
        depth: @call_depth,
        event_index: @events.length,
        defined_class: defined_class,
        path: path,
        lineno: lineno,
        start_time: start_time
      }

      @call_stack.push(call_info)
      @events << nil # Placeholder for the actual TreeNode
      @call_depth += 1

      call_info
    end

    def finish_call(method_name, return_value, end_time)
      return nil if @call_stack.empty?

      # Find matching call on stack (handles filtered nested calls)
      call_info = @call_stack.last
      return nil unless call_info && call_info[:method_name] == method_name

      @call_depth -= 1
      @call_stack.pop

      call_info.merge(
        return_value: return_value,
        end_time: end_time,
        has_children: @events.length > call_info[:event_index] + 1
      )
    end

    def add_event(event)
      @events << event
    end

    def set_event_at_index(index, event)
      @events[index] = event
    end

    def events
      @events.compact
    end

    def events_array
      @events
    end

    def current_depth
      @call_depth
    end

    def empty?
      @call_stack.empty?
    end
  end
end