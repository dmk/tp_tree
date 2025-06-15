# frozen_string_literal: true

require_relative "tp_tree/version"
require_relative "tp_tree/tree_builder"
require_relative "tp_tree/interactive_viewer"

module TPTree
  class <<self
    # catch sets up a TracePoint to monitor method calls and returns,
    # printing them in chronological order with proper tree indentation.
    def catch(interactive: false, &block)
      events = TreeBuilder.new(&block).build

      if interactive
        InteractiveViewer.new(events).show
      else
      events.each { |event| puts event }
      end
    end
  end
end
