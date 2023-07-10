# window_manager.rb
require_relative 'windows/agents'
require_relative 'windows/main'
require_relative 'windows/chat'
require_relative 'windows/input'

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
    init_colors
    echo
    curs_set(1)
    @logger = Logger.new('/home/pocketkk/ai/agents/swarm/logs/window_manager.log')
    @messages = []
    @agents_count = 0
    @main_window = create_main_window
    @agents_subwindow = create_agents_subwindow
    @chat_window = create_chat_window
    @input_window = create_input_window
    @input_window.refresh
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

  def write_to_chat_window(message, color=1)
    @logger.info("Message for chat window: #{message}")
    window_width = @chat_window.maxx - 2
    message = message.gsub(/\n\n/, "\n\u00A0\n") # Using a non-breaking space for the dummy line

    user_message = message.start_with?("User:")

    paragraphs = message.split("\n\u00A0\n") # Splitting into paragraphs at the dummy line

    wrapped_message = paragraphs.flat_map do |paragraph|
      if paragraph.start_with?("Agent:") || paragraph.start_with?("User:")
        # Split paragraph into two columns at the first occurrence of a colon
        columns = paragraph.split(':', 2)
        columns[1] ||= "" # Set columns[1] to an empty string if it's nil

        # Padding the first column to a width of window_width/4
        columns[0] = (columns[0] + ":").ljust(window_width / 8)

        # Wrapping the second column
        columns[1] = columns[1].scan(/\S.{0,#{(window_width*3)/4-2}}\S(?=\s|$)|\S+/)

        # Prepending the first column to each line of columns[1]
        lines = columns[1].map.with_index do |line, index|
          if index == 0
            columns[0] + line.ljust((window_width*3) / 4)
          else
            (' ' * columns[0].length) + line.ljust((window_width*3) / 4)
          end
        end
        lines + [" "]
      else
        columns = ['', paragraph]
        # Padding the first column to a width of window_width/4
        columns[0] = columns[0].ljust(window_width / 8)
        # Just wrap the paragraph without splitting it into columns
        columns[1] = columns[1].scan(/\S.{0,#{(window_width*3)/4-2}}\S(?=\s|$)|\S+/)
        # Prepending the first column to each line of columns[1]
        lines = columns[1].map.with_index do |line, index|
          if index == 0
            columns[0] + line.ljust((window_width*3) / 4)
          else
            (' ' * columns[0].length) + line.ljust((window_width*3) / 4)
          end
        end
        lines + [" "]
      end
    end

    wrapped_message.each do |line|
      @messages << [line, color]
    end

    @messages = @messages.last(@chat_window.maxy - 2)

    @chat_window.clear
    @chat_window = Frame.new(@chat_window, ' CHAT ').framed_window

    @messages.each_with_index do |msg, i|
      @chat_window.attrset(Curses.color_pair(msg[1]))
      @chat_window.setpos(i+1, 1)
      @chat_window.addstr(msg[0])
      @chat_window.attrset(Curses::A_NORMAL)
    end
    @chat_window.refresh
    @input_window.setpos(1, 1) if user_message
  end

  private

  def init_colors
    start_color
    init_pair(1, COLOR_RED, COLOR_BLACK)
    init_pair(2, COLOR_GREEN, COLOR_BLACK)
    init_pair(3, COLOR_BLUE, COLOR_BLACK)
    init_pair(4, COLOR_YELLOW, COLOR_BLACK)
    init_pair(5, COLOR_MAGENTA, COLOR_BLACK)
    init_pair(6, COLOR_CYAN, COLOR_BLACK)
    init_pair(7, COLOR_BLACK, COLOR_GREEN)
    init_pair(8, COLOR_BLACK, COLOR_WHITE)
  end

  def create_main_window
    Windows::Main.new.window

    #init_pair(1, COLOR_WHITE, COLOR_BLACK)
    #main_window_width = cols - (BORDER_WIDTH * 2) - (PADDING_WIDTH * 2) - 1
    #main_window_height = lines - (BORDER_WIDTH * 2) - (PADDING_WIDTH * 2)
    #window = Curses::Window.new(main_window_height, main_window_width, PADDING_WIDTH, PADDING_WIDTH)
    #window.attron(color_pair(1))
    #Frame.new(window, '').framed_window
  end

  def create_agents_subwindow
    @agents_subwindow = Windows::Agents.new(@main_window, agents_count).window
    #agents_subwindow_width = @main_window.maxx - (INTERNAL_PADDING * BORDER_SPACE)
    #agents_subwindow_height = BORDER_SPACE + (PADDING_HEIGHT + INTERNAL_PADDING + BORDER_WIDTH) + agents_count + 3 # 3 works, don't ask me why
    #window = @main_window.subwin(agents_subwindow_height, agents_subwindow_width, PADDING_HEIGHT + INTERNAL_PADDING, INTERNAL_PADDING + PADDING_WIDTH)
    #Frame.new(window, ' AGENTS ').framed_window
  end

  def create_chat_window
    Windows::Chat.new(@main_window, @agents_subwindow).window

    #chat_window_width = @main_window.maxx - (INTERNAL_PADDING * BORDER_SPACE)
    #chat_window_height = @main_window.maxy - @agents_subwindow.maxy - (PADDING_HEIGHT + INTERNAL_PADDING + BORDER_WIDTH) * 2 + 3
    #window = @main_window.subwin(chat_window_height, chat_window_width, @agents_subwindow.maxy - 1 + PADDING_HEIGHT * 2 + INTERNAL_PADDING, INTERNAL_PADDING + PADDING_WIDTH)
    #Frame.new(window, ' CHAT ').framed_window
  end

  def create_input_window
    @input_window = Windows::Input.new(@main_window).window

    #input_window_width = @main_window.maxx - (INTERNAL_PADDING * BORDER_SPACE)
    #input_window_height = PADDING_HEIGHT + INTERNAL_PADDING + BORDER_WIDTH - 1
    #window = @main_window.subwin(input_window_height, input_window_width, @main_window.maxy + 2 - (PADDING_HEIGHT + INTERNAL_PADDING) - 1, INTERNAL_PADDING + PADDING_WIDTH)
    #window = Frame.new(window, ' INPUT ').framed_window
    #window.setpos(1, 1)
    #window.refresh
    #window
  end
end
