# frozen_string_literal: true

require_relative "tp_tree/version"
require_relative "tp_tree/tree_builder"
require_relative "tp_tree/method_filter"

module TPTree
  class <<self
    # catch sets up a TracePoint to monitor method calls and returns,
    # printing them in chronological order with proper tree indentation.
    #
    # @param interactive [Boolean] whether to show interactive viewer
    # @param filter [String, Regexp, Array, Proc] only include methods matching these criteria
    # @param exclude [String, Regexp, Array, Proc] exclude methods matching these criteria
    def catch(interactive: false, filter: nil, exclude: nil, &block)
      filter_obj = MethodFilter.new(filter: filter, exclude: exclude) if filter || exclude
      events = TreeBuilder.new(method_filter: filter_obj, &block).build

      if interactive
        require_relative "tp_tree/interactive_viewer"
        InteractiveViewer.new(events).show
      else
      events.each { |event| puts event }
      end
    end
  end
end
