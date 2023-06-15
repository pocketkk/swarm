class WindowCreator
  PADDING_WIDTH = 2
  BORDER_WIDTH = 1
  INTERNAL_PADDING = 2

  attr_reader :height, :width, :color_pair

  def initialize(height:, width:, color_pair:)
    @height = height
    @width = width
    @color_pair = color_pair
  end

  def create_window
    window_width = width - (BORDER_WIDTH * 2) - (PADDING_WIDTH * 2)
    window_height = height - (BORDER_WIDTH * 2) - (PADDING_WIDTH * 2)

    main_window = Curses::Window.new(window_height, window_width, PADDING_WIDTH, PADDING_WIDTH)
    main_window.attron(color_pair)

    main_window
  end
end
