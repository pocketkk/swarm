# frozen_string_literal: true

require 'curses'
require 'docker'
require 'pry'
require 'forwardable'

class Agent
  extend Forwardable

  attr_accessor :container, :name, :messages, :previous_message, :container_bus, :row

  def initialize(container:, name:, row:)
    @container = container
    @name = name
    @row = row
    @messages = messages
  end

  def start
    container.start
  end

  def_delegator :@container, :logs
end

class ChatUI
  include Curses

  BORDER_WIDTH = 1
  PADDING_WIDTH = 2
  PADDING_HEIGHT = 1
  INTERNAL_PADDING = 2
  CHILD_PADDING = 1

  LEFT_TOP_CORNER = '┌'
  RIGHT_TOP_CORNER = '┐'
  LEFT_BOTTOM_CORNER = '└'
  RIGHT_BOTTOM_CORNER = '┘'
  HORIZONTAL_LINE = '─'
  VERTICAL_LINE = '│'

  def create_chatbots_subwindow(main_window)
    chatbots_subwindow_width = main_window.maxx - (INTERNAL_PADDING * 2)

    chatbots_subwindow_height = 2 + (PADDING_HEIGHT + INTERNAL_PADDING + BORDER_WIDTH)

    chatbots_subwindow = main_window.subwin(chatbots_subwindow_height, chatbots_subwindow_width, PADDING_HEIGHT + INTERNAL_PADDING, INTERNAL_PADDING + PADDING_WIDTH)

    chatbots_subwindow_title = '<<*** AGENTS ***>>'
    dashes_count = (chatbots_subwindow_width - 2 - chatbots_subwindow_title.length) / 2

    offset_count = 0
    offset_count += 1 if dashes_count * 2 + chatbots_subwindow_title.size != chatbots_subwindow_width
    chatbots_subwindow.addstr(LEFT_TOP_CORNER + HORIZONTAL_LINE * dashes_count + chatbots_subwindow_title + HORIZONTAL_LINE * (dashes_count + offset_count) + RIGHT_TOP_CORNER)

    (1..chatbots_subwindow_height - 2).each do |row|
      chatbots_subwindow.setpos(row, 0)
      chatbots_subwindow.addstr(VERTICAL_LINE)
      chatbots_subwindow.setpos(row, chatbots_subwindow_width - 1)
      chatbots_subwindow.addstr(VERTICAL_LINE)
    end

    chatbots_subwindow.setpos(chatbots_subwindow_height - 1, 0)
    chatbots_subwindow.addstr(LEFT_BOTTOM_CORNER + HORIZONTAL_LINE * (chatbots_subwindow_width - 2) + RIGHT_BOTTOM_CORNER)
    chatbots_subwindow.setpos(chatbots_subwindow_height, chatbots_subwindow_width)
    chatbots_subwindow.attrset(A_NORMAL)

    chatbots_subwindow
  end

  def wrapper
    init_pair(1, Curses::COLOR_WHITE, Curses::COLOR_BLACK)

    # Calculate the dimensions of the window based on border, padding, and internal padding
    main_window_width = cols - (BORDER_WIDTH * 2) - (PADDING_WIDTH * 2)
    main_window_height = lines - (BORDER_WIDTH * 2) - (PADDING_WIDTH * 2)

    text_area_width = main_window_width - (INTERNAL_PADDING * 2)
    text_area_height = main_window_height - (INTERNAL_PADDING * 2)

    main_window = Curses::Window.new(main_window_height, main_window_width, PADDING_WIDTH, PADDING_WIDTH)
    main_window.attron(color_pair(1))  # Apply color pair to the main_window

    # Draw the border manually
    main_window.setpos(0, 0)
    main_window.attrset(A_BOLD)
    main_window_title = ' MOTHER '
    dashes_count = ((main_window_width - 2) - main_window_title.size) / 2
    main_window.addstr(LEFT_TOP_CORNER + HORIZONTAL_LINE * dashes_count + main_window_title + HORIZONTAL_LINE * (dashes_count + 1) + RIGHT_TOP_CORNER)

    (1..main_window_height-2).each do |row| # note the change in the range
      main_window.setpos(row, 0)
      main_window.addstr(VERTICAL_LINE)
      main_window.setpos(row, main_window_width - 1)
      main_window.addstr(VERTICAL_LINE)
    end

    main_window.setpos(main_window_height-1, 0)
    main_window.addstr(LEFT_BOTTOM_CORNER + HORIZONTAL_LINE * (main_window_width - 2) + HORIZONTAL_LINE + RIGHT_BOTTOM_CORNER)
    main_window.setpos(main_window_height, main_window_width)
    main_window.addstr(RIGHT_BOTTOM_CORNER)
    main_window.attrset(A_NORMAL)
    main_window
  end

  LEFT_TOP_CORNER = "┌"
  RIGHT_TOP_CORNER = "┐"
  LEFT_BOTTOM_CORNER = "└"
  RIGHT_BOTTOM_CORNER = "┘"
  HORIZONTAL_LINE = "─"
  VERTICAL_LINE = "│"


  def agent_message(agent, old)
    message = agent.logs(stdout: true, tail: 1).gsub("\0", '').gsub("\r\n", "").gsub(/\^A9/, '')

    message == old ? old : message
  end

  def run
    init_screen
    start_color
    curs_set(0)
    noecho

    begin
      main_window = wrapper
      chatbot_window = create_chatbots_subwindow(main_window)

      # Set the starting position for the text area
      text_area_start_x = PADDING_WIDTH + INTERNAL_PADDING
      text_area_start_y = PADDING_HEIGHT

      bot1_row = 1
      bot2_row = 2

      bot1_message = "starting ..."
      bot2_message = "starting ..."

      count = 0

      Docker.options[:read_timeout] = 500
      Docker.options[:write_timeout] = 500

      bot1_message_old = ''
      bot2_message_old = ''
      logs_old = ""

      openai_chat_bot = \
        Agent.new(
          name: :openai_chat_bot,
          row: 1,
          container: Docker::Container.create(
            'Cmd' => ['ruby', 'openai_chat_bot.rb', 'What is the capitol of France?', ENV['OPENAI_API_KEY']],
            'Image' => 'openai_chat_bot',
            'Tty' => true
          )
        )

      hello_bot = \
        Agent.new(
          name: :hello_bot,
          row: 2,
          container: Docker::Container.create(
            'Cmd' => ['ruby', 'hello_bot.rb', 'From Mother'],
            'Image' => 'hello_bot',
            'Tty' => true
          )
        )

      agents = [hello_bot, openai_chat_bot]
      puts agents.map(&:start)

      loop do

        agents.each do |agent|
          chatbot_window.setpos(text_area_start_y + agent.row, text_area_start_x)
          message = agent_message(agent, agent.previous_message)

          chatbot_window.addstr("#{agent.name}: #{message}")
        end

        main_window.refresh
        chatbot_window.refresh

        bot1_message_old = bot1_message
        bot2_message_old = bot2_message
        count += 1
        sleep 0.25
      end
    ensure
      close_screen
    end
  end
end

ChatUI.new.run
