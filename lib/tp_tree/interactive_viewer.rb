# frozen_string_literal: true

require 'curses'
require 'set'
require_relative 'xml_formatter'
require_relative 'tree_node'

module TPTree
  class InteractiveViewer
    include XMLFormatter

    def initialize(tree)
      @tree = tree
      @original_tree = tree  # Keep reference to original tree for navigation
      @tree_stack = []       # Stack to track zoom levels
      @lines = []
      @visible_lines = []
      @scroll_pos = 0
      @cursor_pos = 0
      @stdscr = Curses.init_screen
      @expanded_nodes = Set.new
      @node_children = {}

      # Initialize all nodes as expanded and build parent-child relationships
      analyze_tree_structure
      expand_all_initially
    end

    def show
      Curses.start_color
      init_color_pairs
      Curses.curs_set(0) # Hide cursor
      Curses.noecho
      @stdscr.keypad(true)

      prepare_lines
      update_visible_lines
      main_loop
    ensure
      Curses.close_screen
    end

    private

    def analyze_tree_structure
      @node_children = {}
      call_stack = []

      @tree.each_with_index do |node, index|
        case node.event
        when :call
          # This is a call that will have children (has separate return)
          call_stack.push(index)
          @node_children[index] = []
        when :return
          # This is a return, pop the corresponding call
          if call_stack.any?
            call_index = call_stack.pop
            # Mark all nodes between call and return as children
            @node_children[call_index] = ((call_index + 1)...index).to_a
          end
        when :call_return
          # This is a leaf node (no children)
          @node_children[index] = []
        end
      end
    end

    def expand_all_initially
      @node_children.each_key do |index|
        @expanded_nodes.add(index) if has_children?(index)
      end
    end

    def has_children?(index)
      @node_children[index] && @node_children[index].any?
    end

    def is_expanded?(index)
      @expanded_nodes.include?(index)
    end

    def toggle_expansion(index)
      if has_children?(index)
        if is_expanded?(index)
          @expanded_nodes.delete(index)
        else
          @expanded_nodes.add(index)
        end
        update_visible_lines
      end
    end

    def update_visible_lines
      @visible_lines = []
      @tree.each_with_index do |node, index|
        @visible_lines << index if should_show_node?(index)
      end
    end

    def should_show_node?(index)
      # Always show root level nodes
      return true if @tree[index].depth == 0

      # Check if ALL ancestors are expanded
      all_ancestors_expanded?(index)
    end

    def all_ancestors_expanded?(index)
      current_depth = @tree[index].depth

      # Check each ancestor level
      (1..current_depth).each do |depth_to_check|
        ancestor_index = find_ancestor_at_depth(index, depth_to_check - 1)
        next if ancestor_index.nil?

        # If this ancestor has children and is not expanded, hide this node
        if has_children?(ancestor_index) && !is_expanded?(ancestor_index)
          return false
        end
      end

      true
    end

    def find_ancestor_at_depth(index, target_depth)
      current_depth = @tree[index].depth

      # Look backwards for a call at the target depth
      (index - 1).downto(0) do |i|
        node = @tree[i]
        if node.depth == target_depth && (node.event == :call || node.event == :call_return)
          return i
        end
        # Stop if we've gone too far back (past a shallower depth)
        break if node.depth < target_depth
      end
      nil
    end

    def find_parent_call(index)
      current_depth = @tree[index].depth

      # Look backwards for a call at depth-1
      (index - 1).downto(0) do |i|
        node = @tree[i]
        if node.depth == current_depth - 1 && (node.event == :call || node.event == :call_return)
          return i
        end
      end
      nil
    end

    def init_color_pairs
      Curses.init_pair(Curses::COLOR_RED, Curses::COLOR_RED, Curses::COLOR_BLACK)
      Curses.init_pair(Curses::COLOR_GREEN, Curses::COLOR_GREEN, Curses::COLOR_BLACK)
      Curses.init_pair(Curses::COLOR_YELLOW, Curses::COLOR_YELLOW, Curses::COLOR_BLACK)
      Curses.init_pair(Curses::COLOR_BLUE, Curses::COLOR_BLUE, Curses::COLOR_BLACK)
      Curses.init_pair(Curses::COLOR_MAGENTA, Curses::COLOR_MAGENTA, Curses::COLOR_BLACK)
      Curses.init_pair(Curses::COLOR_CYAN, Curses::COLOR_CYAN, Curses::COLOR_BLACK)
      Curses.init_pair(Curses::COLOR_WHITE, Curses::COLOR_WHITE, Curses::COLOR_BLACK)

      # Status bar color pairs with default background
      Curses.init_pair(8, Curses::COLOR_WHITE, Curses::COLOR_BLACK)
      Curses.init_pair(9, Curses::COLOR_GREEN, Curses::COLOR_BLACK)    # class name: green
      Curses.init_pair(10, Curses::COLOR_YELLOW, Curses::COLOR_BLACK)  # method name: yellow
    end

    def prepare_lines
      @lines = @tree.map do |node|
        node.to_parts(formatter: self)
      end
    end

    def main_loop
      loop do
        adjust_scroll
        draw
        handle_input
      end
    end

    def adjust_scroll
      max_visible_lines = @stdscr.maxy - 1  # Reserve one line for status bar

      if @cursor_pos < @scroll_pos
        @scroll_pos = @cursor_pos
      elsif @cursor_pos >= @scroll_pos + max_visible_lines
        @scroll_pos = @cursor_pos - max_visible_lines + 1
      end

      # Ensure we don't scroll past the end
      max_scroll = [@visible_lines.size - max_visible_lines, 0].max
      @scroll_pos = [@scroll_pos, max_scroll].min

      # Special case: if we're at the last selectable line, make sure final returns are visible
      last_selectable_idx = find_last_selectable_line
      if @cursor_pos == last_selectable_idx
        # Calculate scroll to show the cursor and as many final visible lines as possible
        desired_scroll = [@visible_lines.size - max_visible_lines, 0].max
        @scroll_pos = [desired_scroll, @scroll_pos].max
      end
    end

    def find_last_selectable_line
      (@visible_lines.size - 1).downto(0) do |i|
        actual_index = @visible_lines[i]
        return i if @tree[actual_index].event != :return
      end
      0 # fallback
    end

    def draw
      @stdscr.clear
      draw_content
      draw_status_bar
      @stdscr.refresh
    end

    def draw_content
      (@stdscr.maxy - 1).times do |i|
        visible_line_idx = @scroll_pos + i
        next unless visible_line_idx < @visible_lines.size

        actual_line_idx = @visible_lines[visible_line_idx]
        display_line(@lines[actual_line_idx], i, visible_line_idx, actual_line_idx)
      end
    end

    def display_line(parts, row, visible_line_idx, actual_line_idx)
      prefix_parts, content_xml = parts
      x = 0

      # Add expansion indicator for nodes with children
      if has_children?(actual_line_idx)
        expansion_indicator = is_expanded?(actual_line_idx) ? "[-] " : "[+] "
        @stdscr.attron(Curses.color_pair(Curses::COLOR_CYAN))
        @stdscr.setpos(row, x)
        @stdscr.addstr(expansion_indicator)
        @stdscr.attroff(Curses.color_pair(Curses::COLOR_CYAN))
        x += expansion_indicator.length
      else
        # Add spacing to align with expandable nodes
        @stdscr.setpos(row, x)
        @stdscr.addstr("    ")
        x += 4
      end

      # Draw prefix (no highlighting)
      prefix_parts.each do |text, color_name|
        attrs = color_pair_for(color_name) || Curses.color_pair(Curses::COLOR_WHITE)

        @stdscr.attron(attrs)
        @stdscr.setpos(row, x)
        @stdscr.addstr(text)
        @stdscr.attroff(attrs)
        x += text.length
      end

      # Draw content with method name highlighting for current line
      draw_xml_string(content_xml, row, x, visible_line_idx == @cursor_pos)
    end

    def draw_xml_string(xml_str, row, start_x, highlight_method_name = false)
      x = start_x
      xml_str.scan(/(<(\w+)>)?([^<]+)(<\/\w+>)?/).each do |_, color_tag, text, _|
        color_name = color_tag&.to_sym

        # Highlight method name (colored text) on current line
        is_method_name = highlight_method_name && color_name && color_name != :white

        attrs = color_pair_for(color_name) || Curses.color_pair(Curses::COLOR_WHITE)
        attrs |= Curses::A_STANDOUT if is_method_name

        @stdscr.attron(attrs)
        @stdscr.setpos(row, x)
        @stdscr.addstr(text)
        @stdscr.attroff(attrs)
        x += text.length
      end
    end

    def color_pair_for(color_name)
      case color_name
      when :red then Curses.color_pair(Curses::COLOR_RED)
      when :green then Curses.color_pair(Curses::COLOR_GREEN)
      when :yellow then Curses.color_pair(Curses::COLOR_YELLOW)
      when :blue then Curses.color_pair(Curses::COLOR_BLUE)
      when :magenta then Curses.color_pair(Curses::COLOR_MAGENTA)
      when :cyan then Curses.color_pair(Curses::COLOR_CYAN)
      else Curses.color_pair(Curses::COLOR_WHITE)
      end
    end

    def draw_status_bar
      actual_index = @visible_lines[@cursor_pos] if @cursor_pos < @visible_lines.size
      return unless actual_index

      node = @tree[actual_index]

      # Build method signature
      method_signature = if node.defined_class
        class_name, separator = format_class_and_separator(node.defined_class)
        "#{class_name}#{separator}#{node.method_name}"
      else
        node.method_name.to_s
      end

      # Add zoom level indicator
      if @tree_stack.any?
        zoom_indicator = " [#{@tree_stack.size + 1}]"
        method_signature += zoom_indicator
      end

            # Build location info
      location_info = if node.path && node.lineno
        filename = File.basename(node.path)
        "#{filename}:#{node.lineno}"
      else
        ""
      end

      # Create a status bar with method on left, file on right
      status_bar_width = @stdscr.maxx
      padding = 2

      # Calculate available space for content
      left_padding = " " * padding
      right_padding = " " * padding

      # Calculate middle spacing
      used_space = left_padding.length + method_signature.length + location_info.length + right_padding.length
      available_space = status_bar_width - used_space

      # Handle overflow by truncating the method signature
      if available_space < 0
        max_method_length = status_bar_width - location_info.length - (padding * 2) - 3 # 3 for "..."
        if max_method_length > 0
          method_signature = method_signature[0, max_method_length] + "..."
          available_space = status_bar_width - left_padding.length - method_signature.length - location_info.length - right_padding.length
        else
          # Extreme case: just show truncated method, no file info
          method_signature = method_signature[0, status_bar_width - (padding * 2) - 3] + "..."
          location_info = ""
          available_space = 0
        end
      end

      # Calculate middle spacing
      middle_spacing = available_space > 0 ? " " * available_space : ""

      # Start drawing from left
      x = 0
      white_pair = Curses.color_pair(8)

      # Draw left padding in white
      @stdscr.attron(white_pair)
      @stdscr.setpos(@stdscr.maxy - 1, x)
      @stdscr.addstr(left_padding)
      x += left_padding.length
      @stdscr.attroff(white_pair)

      # Split method_signature into class/sep/method if separator present
      class_part, sep, method_part = method_signature.rpartition(/[.#]/)
      if sep.empty?
        # Fallback: no separator found
        class_part = ""
        sep = ""
        method_part = method_signature
      end

      # Class name in green
      green_pair = Curses.color_pair(9)
      unless class_part.empty?
        @stdscr.attron(green_pair)
        @stdscr.setpos(@stdscr.maxy - 1, x)
        @stdscr.addstr(class_part)
        @stdscr.attroff(green_pair)
        x += class_part.length
      end

      # Separator in white
      unless sep.empty?
        @stdscr.attron(white_pair)
        @stdscr.setpos(@stdscr.maxy - 1, x)
        @stdscr.addstr(sep)
        @stdscr.attroff(white_pair)
        x += sep.length
      end

      # Method name in yellow
      yellow_pair = Curses.color_pair(10)
      @stdscr.attron(yellow_pair)
      @stdscr.setpos(@stdscr.maxy - 1, x)
      @stdscr.addstr(method_part)
      @stdscr.attroff(yellow_pair)
      x += method_part.length

      # Middle spacing in white
      @stdscr.attron(white_pair)
      @stdscr.setpos(@stdscr.maxy - 1, x)
      @stdscr.addstr(middle_spacing)
      @stdscr.attroff(white_pair)
      x += middle_spacing.length

      # Location info in white
      @stdscr.attron(white_pair)
      @stdscr.setpos(@stdscr.maxy - 1, x)
      @stdscr.addstr(location_info)
      @stdscr.attroff(white_pair)
      x += location_info.length

      # Right padding in white
      @stdscr.attron(white_pair)
      @stdscr.setpos(@stdscr.maxy - 1, x)
      @stdscr.addstr(right_padding)
      @stdscr.attroff(white_pair)
    end

    def format_class_and_separator(klass)
      class_str = klass.to_s

      # Handle singleton classes like #<Class:Gem::Specification>
      if class_str.match(/^#<Class:(.+)>$/)
        ["#{$1}", "."]  # Class method: Gem::Specification.method_name
      # Handle singleton classes for instances like #<Class:#<Gem::ConfigFile:0x...>>
      elsif class_str.match(/^#<Class:#<(.+?):/)
        ["#{$1}.instance.class", "#"]  # Instance singleton: Class.instance.class#method
      # Handle regular classes and modules
      else
        [class_str, "#"]  # Instance method: ClassName#method_name
      end
    end

    def current_method_name
      return 'N/A' if @visible_lines.empty?

      actual_index = @visible_lines[@cursor_pos]
      return 'N/A' unless actual_index

      node = @tree[actual_index]
      node.method_name.to_s
    end

    def handle_input
      case @stdscr.getch
      when Curses::KEY_UP, 'k'
        move_up
      when Curses::KEY_DOWN, 'j'
        move_down
      when Curses::KEY_RIGHT, 'l'
        expand_current_node
      when Curses::KEY_LEFT, 'h'
        collapse_current_node
      when Curses::KEY_ENTER, 10, 13  # Enter key
        enter_current_call
      when 'T'
        collapse_all
      when 't'
        expand_all
      when 'b'  # Back - go up one level in the call stack
        go_back
      when 'q'
        exit
      end
    end

    def expand_current_node
      return if @visible_lines.empty?

      actual_index = @visible_lines[@cursor_pos]
      if has_children?(actual_index) && !is_expanded?(actual_index)
        @expanded_nodes.add(actual_index)
        update_visible_lines
      end
    end

    def collapse_current_node
      return if @visible_lines.empty?

      actual_index = @visible_lines[@cursor_pos]
      if has_children?(actual_index) && is_expanded?(actual_index)
        @expanded_nodes.delete(actual_index)
        update_visible_lines

        # If we collapsed and cursor is beyond visible lines, adjust
        if @cursor_pos >= @visible_lines.size
          @cursor_pos = [@visible_lines.size - 1, 0].max
        end
      end
    end

    def enter_current_call
      return if @visible_lines.empty?

      actual_index = @visible_lines[@cursor_pos]
      current_node = @tree[actual_index]

      # Only allow entering calls that have children
      return unless has_children?(actual_index)

      # Save current state to stack (including computed state to avoid recomputation)
      @tree_stack.push({
        tree: @tree,
        expanded_nodes: @expanded_nodes.dup,
        cursor_pos: @cursor_pos,
        scroll_pos: @scroll_pos,
        node_children: @node_children.dup,
        lines: @lines.dup,
        visible_lines: @visible_lines.dup
      })

      # Create new filtered tree starting from the selected call
      new_tree = extract_subtree(actual_index)
      return if new_tree.empty?

      # Update tree and reset state
      @tree = new_tree
      @expanded_nodes = Set.new
      @node_children = {}
      @cursor_pos = 0
      @scroll_pos = 0

      # Rebuild tree structure and expand all
      analyze_tree_structure
      expand_all_initially
      prepare_lines
      update_visible_lines
    end

    def go_back
      return if @tree_stack.empty?

      # Restore previous state (including computed state to avoid expensive recomputation)
      previous_state = @tree_stack.pop
      @tree = previous_state[:tree]
      @expanded_nodes = previous_state[:expanded_nodes]
      @cursor_pos = previous_state[:cursor_pos]
      @scroll_pos = previous_state[:scroll_pos]
      @node_children = previous_state[:node_children] || {}
      @lines = previous_state[:lines] || []
      @visible_lines = previous_state[:visible_lines] || []

      # Only rebuild if cached state is missing (for backward compatibility)
      if @node_children.empty? || @lines.empty?
        analyze_tree_structure
        prepare_lines
        update_visible_lines
      end
    end

        def extract_subtree(root_index)
      return [] unless has_children?(root_index)

      root_node = @tree[root_index]
      children_indices = @node_children[root_index]

      # Create new tree with adjusted depths
      new_tree = []
      root_depth = root_node.depth

      # Add the root call
      new_tree << TreeNode.new(
        root_node.event,
        root_node.method_name,
        root_node.parameters,
        root_node.return_value,
        0,  # New root starts at depth 0
        root_node.defined_class,
        root_node.path,
        root_node.lineno,
        root_node.start_time,
        root_node.end_time
      )

      # Add all children with adjusted depths
      children_indices.each do |child_index|
        child_node = @tree[child_index]
        new_depth = child_node.depth - root_depth

        new_tree << TreeNode.new(
          child_node.event,
          child_node.method_name,
          child_node.parameters,
          child_node.return_value,
          new_depth,
          child_node.defined_class,
          child_node.path,
          child_node.lineno,
          child_node.start_time,
          child_node.end_time
        )
      end

      # Find and add the return event for the root call
      return_index = find_matching_return(root_index)
      if return_index
        return_node = @tree[return_index]
        new_tree << TreeNode.new(
          return_node.event,
          return_node.method_name,
          return_node.parameters,
          return_node.return_value,
          0,  # Return at same depth as root call
          return_node.defined_class,
          return_node.path,
          return_node.lineno,
          return_node.start_time,
          return_node.end_time
        )
      end

      new_tree
    end

        def find_matching_return(call_index)
      root_node = @tree[call_index]
      return nil if root_node.event != :call

      # Look for the return event at the same depth with the same method name
      # It should come after all the children
      children_indices = @node_children[call_index]
      search_start = children_indices.any? ? children_indices.max + 1 : call_index + 1

      (search_start...@tree.length).each do |i|
        node = @tree[i]
        if node.event == :return &&
           node.method_name == root_node.method_name &&
           node.depth == root_node.depth  # Return events are at the same depth as their call
          return i
        end
        # Stop if we encounter a node at a shallower depth (we've gone too far)
        break if node.depth < root_node.depth
      end

      nil
    end

    def expand_all
      @node_children.each_key do |index|
        @expanded_nodes.add(index) if has_children?(index)
      end
      update_visible_lines

      # Adjust cursor if it's beyond the new visible range
      if @cursor_pos >= @visible_lines.size
        @cursor_pos = [@visible_lines.size - 1, 0].max
      end
    end

    def collapse_all
      @expanded_nodes.clear
      update_visible_lines

      # Adjust cursor if it's beyond the new visible range
      if @cursor_pos >= @visible_lines.size
        @cursor_pos = [@visible_lines.size - 1, 0].max
      end
    end

    def move_up
      new_pos = @cursor_pos - 1

      # Skip return events in visible lines
      while new_pos >= 0
        actual_index = @visible_lines[new_pos]
        break if @tree[actual_index].event != :return
        new_pos -= 1
      end

      @cursor_pos = new_pos if new_pos >= 0
    end

    def move_down
      new_pos = @cursor_pos + 1

      # Skip return events in visible lines
      while new_pos < @visible_lines.size
        actual_index = @visible_lines[new_pos]
        break if @tree[actual_index].event != :return
        new_pos += 1
      end

      @cursor_pos = new_pos if new_pos < @visible_lines.size
    end
  end
end