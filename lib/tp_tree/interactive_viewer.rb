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
      status_parts = []

      # Class and method
      if node.defined_class
        class_name, separator = format_class_and_separator(node.defined_class)
        status_parts << "#{class_name}#{separator}#{node.method_name}"
      else
        status_parts << node.method_name.to_s
      end

      # File and line
      if node.path && node.lineno
        filename = File.basename(node.path)
        status_parts << "#{filename}:#{node.lineno}"
      end

      # Add navigation info
      status_parts << "#{@cursor_pos + 1}/#{@visible_lines.size}"

      # Add expand/collapse hint
      if has_children?(actual_index)
        hint = is_expanded?(actual_index) ? "Space: collapse" : "Space: expand"
        status_parts << hint
      end

      status_text = status_parts.join(' | ')
      @stdscr.attron(Curses::A_REVERSE)
      @stdscr.setpos(@stdscr.maxy - 1, 0)
      @stdscr.addstr(status_text.ljust(@stdscr.maxx))
      @stdscr.attroff(Curses::A_REVERSE)
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
      when ' ', Curses::KEY_ENTER, 10, 13  # Space, Enter, or Return
        toggle_current_node
      when 'T'
        collapse_all
      when 't'
        expand_all
      when 'q'
        exit
      end
    end

    def toggle_current_node
      return if @visible_lines.empty?

      actual_index = @visible_lines[@cursor_pos]
      toggle_expansion(actual_index)

      # If we collapsed and cursor is beyond visible lines, adjust
      if @cursor_pos >= @visible_lines.size
        @cursor_pos = [@visible_lines.size - 1, 0].max
      end
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