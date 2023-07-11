class ChatWriter
  include Curses

  attr_reader :chat_window, :messages

  def initialize(chat_window)
    @chat_window = chat_window
    @messages = []
  end

  def write(message, color=1)
    window_width = chat_window.maxx - 2
    processed_message = process_message(message, window_width)
    display_message(processed_message, color)
  end

  private

  def process_message(message, window_width)
    message = format_message(message)

    paragraphs = message.split("\n\u00A0\n") # Splitting into paragraphs at the dummy line

    paragraphs.flat_map do |paragraph|
      columns = format_paragraph(paragraph, window_width)
      wrap_message(columns, window_width)
    end
  end

  def format_message(message)
    message.gsub(/\n\n/, "\n\u00A0\n") # Using a non-breaking space for the dummy line
  end

  def format_paragraph(paragraph, window_width)
    if paragraph.start_with?("Agent:") || paragraph.start_with?("User:")
      columns = paragraph.split(':', 2)
    else
      columns = ['', paragraph]
    end
    columns[0] = (columns[0] + ":").ljust(window_width / 8)
    columns[1] ||= "" # Set columns[1] to an empty string if it's nil
    columns[1] = columns[1].scan(/\S.{0,#{(window_width*3)/4-2}}\S(?=\s|$)|\S+/)
    columns
  end

  def wrap_message(columns, window_width)
    columns[1].map.with_index do |line, index|
      if index == 0
        ' ' + columns[0] + line.ljust((window_width*3) / 4 + 1)
      else
        (' ' * columns[0].length) + line.ljust((window_width*3) / 4)
      end
    end + [' ']
  end

  def display_message(message, color)
    add_to_messages(message, color)
    render_messages
  end

  def add_to_messages(lines, color)
    lines.each do |line|
      @messages << [line, color]
    end
    @messages = @messages.last(chat_window.maxy - 2)
  end

  def render_messages
    chat_window.clear
    @chat_window = Frame.new(chat_window, ' CHAT ').framed_window

    @messages.each_with_index do |msg, i|
      chat_window.attrset(Curses.color_pair(msg[1]))
      chat_window.setpos(i+1, 1)
      chat_window.addstr(msg[0])
      chat_window.attrset(Curses::A_NORMAL)
    end
    chat_window.refresh
    chat_window
  end
end
