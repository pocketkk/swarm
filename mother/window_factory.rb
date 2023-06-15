# frozen_string_literal: true

class WindowFactory
  include Curses

  def initialize(parent: nil, height: nil, width: nil, pos_y: nil, pos_x: nil, title: nil)
    @parent = parent
    @height = height || (parent ? parent.maxy : lines)
    @width = width || (parent ? parent.maxx : cols)
    @pos_y = pos_y || ::ChatUI::PADDING_HEIGHT
    @pos_x = pos_x || ::ChatUI::PADDING_WIDTH
    @title = title || 'The Agencys'
  end

  def build
    init_pair(1, COLOR_WHITE, COLOR_BLACK)

    window = if @parent
               @parent.subwin(@height, @width, @pos_y, @pos_x)
             else
               Curses::Window.new(@height, @width, @pos_y, @pos_x)
             end
    window.attron(color_pair(1))  # Apply color pair to the window

    Frame.new(window, @title).framed_window
  end
end
