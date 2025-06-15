# frozen_string_literal: true

require 'curses'
require_relative 'xml_formatter'
require_relative 'tree_node'

module TPTree
  class InteractiveViewer
    include XMLFormatter

    def initialize(tree)
      @tree = tree
      @lines = []
      @scroll_pos = 0
      @cursor_pos = 0
      @stdscr = Curses.init_screen
    end

    def show
      Curses.start_color
      init_color_pairs
      Curses.curs_set(0) # Hide cursor
      Curses.noecho
      @stdscr.keypad(true)

      prepare_lines
      main_loop
    ensure
      Curses.close_screen
    end

    private

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

      # Ensure we don't scroll past the end - but show ALL lines including unselectable ones
      max_scroll = [@tree.size - max_visible_lines, 0].max
      @scroll_pos = [@scroll_pos, max_scroll].min

      # Special case: if we're at the last selectable line, make sure final returns are visible
      last_selectable_idx = find_last_selectable_line
      if @cursor_pos == last_selectable_idx
        # Calculate scroll to show the cursor and as many final lines as possible
        desired_scroll = [@tree.size - max_visible_lines, 0].max
        @scroll_pos = [desired_scroll, @scroll_pos].max
      end
    end

    def find_last_selectable_line
      (@tree.size - 1).downto(0) do |i|
        return i if @tree[i].event != :return
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
        line_idx = @scroll_pos + i
        next unless line_idx < @lines.size

        display_line(@lines[line_idx], i, line_idx)
      end
    end

    def display_line(parts, row, line_idx)
      prefix_parts, content_xml = parts
      x = 0

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
      draw_xml_string(content_xml, row, x, line_idx == @cursor_pos)
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
      node = @tree[@cursor_pos]
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
      return 'N/A' if @tree.empty?

      node = @tree[@cursor_pos]
      node.method_name.to_s
    end

    def handle_input
      case @stdscr.getch
      when Curses::KEY_UP, 'k'
        move_up
      when Curses::KEY_DOWN, 'j'
        move_down
      when 'q'
        exit
      end
    end

    def move_up
      new_pos = @cursor_pos - 1

      # Normal logic: skip returns
      while new_pos >= 0 && @tree[new_pos].event == :return
        new_pos -= 1
      end
      @cursor_pos = new_pos if new_pos >= 0
    end

    def move_down
      new_pos = @cursor_pos + 1

      # Normal logic: skip returns
      while new_pos < @tree.size && @tree[new_pos].event == :return
        new_pos += 1
      end
      @cursor_pos = new_pos if new_pos < @tree.size
    end


  end
end