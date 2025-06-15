# frozen_string_literal: true

require_relative "tp_tree/version"
require_relative "tp_tree/tree_builder"

module TPTree
  class <<self
    # catch sets up a TracePoint to monitor method calls and returns,
    # printing them in chronological order with proper tree indentation.
    def catch(&block)
      events = TreeBuilder.new(&block).build
      events.each { |event| puts event }
    end
  end
end
