class WindowManager
  include Curses

  BORDER_WIDTH = 1
  PADDING_WIDTH = 2
  PADDING_HEIGHT = 1
  INTERNAL_PADDING = 2
  CHILD_PADDING = 1
  BORDER_SPACE = 2

  attr_reader :main_window, :agents_subwindow, :chat_window, :input_window, :messages
  attr_accessor :agents_count

  def initialize
    init_screen
    start_color
    echo
    curs_set(1)
    @messages = []
    @agents_count = 0
    @main_window = create_main_window
    @agents_subwindow = create_agents_subwindow
    @chat_window = create_chat_window
    @input_window = create_input_window
    refresh!
  end

  def refresh!
    @main_window.refresh
    @agents_subwindow.refresh
    @chat_window.refresh
    @input_window.refresh
  end

  def inset_x
    PADDING_WIDTH + INTERNAL_PADDING
  end

  def inset_y
    PADDING_HEIGHT
  end

  def get_input
    str = @input_window.getstr
    @input_window.clear
    @input_window = create_input_window
    @input_window.refresh
    str
  end

  def write_to_chat_window(message)
    @messages << message
    @chat_window.clear
    @chat_window = Frame.new(@chat_window, ' CHAT ').framed_window  # Redraw the border after adding the message
    @messages.each_with_index do |msg, i|
      @chat_window.setpos(i+1, 1)
      @chat_window.addstr(msg)
    end
    @chat_window.refresh
    @input_window.setpos(1, 1)
  end

  private

  def create_main_window
    init_pair(1, COLOR_WHITE, COLOR_BLACK)
    main_window_width = cols - (BORDER_WIDTH * 2) - (PADDING_WIDTH * 2) - 1
    main_window_height = lines - (BORDER_WIDTH * 2) - (PADDING_WIDTH * 2)
    window = Curses::Window.new(main_window_height, main_window_width, PADDING_WIDTH, PADDING_WIDTH)
    window.attron(color_pair(1))
    Frame.new(window, '').framed_window
  end

  def create_agents_subwindow
    agents_subwindow_width = @main_window.maxx - (INTERNAL_PADDING * BORDER_SPACE)
    agents_subwindow_height = BORDER_SPACE + (PADDING_HEIGHT + INTERNAL_PADDING + BORDER_WIDTH) + agents_count + 1# 6 is the number of agents
    window = @main_window.subwin(agents_subwindow_height, agents_subwindow_width, PADDING_HEIGHT + INTERNAL_PADDING, INTERNAL_PADDING + PADDING_WIDTH)
    Frame.new(window, ' AGENTS ').framed_window
  end

   def create_chat_window
    chat_window_width = @main_window.maxx - (INTERNAL_PADDING * BORDER_SPACE)
    chat_window_height = @main_window.maxy - @agents_subwindow.maxy - (PADDING_HEIGHT + INTERNAL_PADDING + BORDER_WIDTH) * 2 + 3
    window = @main_window.subwin(chat_window_height, chat_window_width, @agents_subwindow.maxy - 1 + PADDING_HEIGHT * 2 + INTERNAL_PADDING, INTERNAL_PADDING + PADDING_WIDTH)
    Frame.new(window, ' CHAT ').framed_window
  end

  def create_input_window
    input_window_width = @main_window.maxx - (INTERNAL_PADDING * BORDER_SPACE)
    input_window_height = PADDING_HEIGHT + INTERNAL_PADDING + BORDER_WIDTH - 1
    window = @main_window.subwin(input_window_height, input_window_width, @main_window.maxy + 2 - (PADDING_HEIGHT + INTERNAL_PADDING) - 1, INTERNAL_PADDING + PADDING_WIDTH)
    window = Frame.new(window, ' INPUT ').framed_window
    window.setpos(1, 1)
    window.refresh
    window
  end
end
