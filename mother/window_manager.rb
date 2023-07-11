# window_manager.rb
require_relative 'windows/agents'
require_relative 'windows/main'
require_relative 'windows/chat'
require_relative 'windows/input'
require_relative 'chat_writer'

class WindowManager
  include Curses

  BORDER_WIDTH = 1
  PADDING_WIDTH = 2
  PADDING_HEIGHT = 1
  INTERNAL_PADDING = 2
  CHILD_PADDING = 1
  BORDER_SPACE = 2

  attr_reader :messages, :windows
  attr_accessor :agents_count

  def initialize
    init_screen
    init_colors
    @logger = Logger.new('/home/pocketkk/ai/agents/swarm/logs/window_manager.log')
    @messages = []
    @agents_count = 0
    @windows = [main_window, agents_window, chat_window, input_window]
    refresh!
  end

  def main_window
    @main_window ||= Windows::Main.new.window
  end

  def agents_window
    @agents_window ||= Windows::Agents.new(@main_window, agents_count).window
  end

  def chat_window
    @chat_window ||= Windows::Chat.new(@main_window, agents_window).window
  end

  def input_window
    @input_window ||= Windows::Input.new(@main_window).window
  end

  def refresh!
    windows.each(&:refresh)
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
    @input_window = nil
    input_window
    str
  end

  def chat_writer
    @chat_writer ||= ChatWriter.new(chat_window)
  end

  def write_to_chat_window(message, color=1)
    @chat_window = chat_writer.write(message, color)
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
end
