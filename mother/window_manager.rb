class WindowManager
  include Curses

  BORDER_WIDTH = 1
  PADDING_WIDTH = 2
  PADDING_HEIGHT = 1
  INTERNAL_PADDING = 2
  CHILD_PADDING = 1
  BORDER_SPACE = 2

  attr_reader :main_window, :agents_subwindow

  def initialize
    init_screen
    start_color
    curs_set(0)
    noecho
    @main_window = create_main_window
    @agents_subwindow = create_agents_subwindow
  end

  def refresh
    @main_window.refresh
    @agents_subwindow.refresh
  end

  def inset_x
    PADDING_WIDTH + INTERNAL_PADDING
  end

  def inset_y
    PADDING_HEIGHT
  end

  private

  def create_main_window
    init_pair(1, COLOR_WHITE, COLOR_BLACK)
    main_window_width = cols - (BORDER_WIDTH * 2) - (PADDING_WIDTH * 2)
    main_window_height = lines - (BORDER_WIDTH * 2) - (PADDING_WIDTH * 2)
    window = Curses::Window.new(main_window_height, main_window_width, PADDING_WIDTH, PADDING_WIDTH)
    window.attron(color_pair(1))
    Frame.new(window, 'The Agency').framed_window
  end

  def create_agents_subwindow
    agents_subwindow_width = @main_window.maxx - (INTERNAL_PADDING * BORDER_SPACE)
    agents_subwindow_height = BORDER_SPACE + (PADDING_HEIGHT + INTERNAL_PADDING + BORDER_WIDTH)
    window = @main_window.subwin(agents_subwindow_height, agents_subwindow_width, PADDING_HEIGHT + INTERNAL_PADDING, INTERNAL_PADDING + PADDING_WIDTH)
    Frame.new(window, '<<*** AGENTS ***').framed_window
  end
end
