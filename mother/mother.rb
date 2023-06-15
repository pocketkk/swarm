# frozen_string_literal: true

require 'curses'
require 'docker'
require 'pry'
require 'forwardable'
require_relative 'frame'

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

  BORDER_SPACE = 2

  def create_chatbots_subwindow(main_window)
    chatbots_subwindow_width = main_window.maxx - (INTERNAL_PADDING * BORDER_SPACE)
    chatbots_subwindow_height = BORDER_SPACE + (PADDING_HEIGHT + INTERNAL_PADDING + BORDER_WIDTH)

    chatbots_subwindow = main_window.subwin(
      chatbots_subwindow_height,
      chatbots_subwindow_width,
      PADDING_HEIGHT + INTERNAL_PADDING,
      INTERNAL_PADDING + PADDING_WIDTH
    )

    framed = Frame.new(
      chatbots_subwindow,
      '<<*** AGENTS ***'
    )

    framed.framed_window
  end

  def wrapper
    init_pair(1, Curses::COLOR_WHITE, Curses::COLOR_BLACK)

    # Calculate the dimensions of the window based on border, padding, and internal padding
    main_window_width = cols - (BORDER_WIDTH * 2) - (PADDING_WIDTH * 2)
    main_window_height = lines - (BORDER_WIDTH * 2) - (PADDING_WIDTH * 2)

    main_window = Curses::Window.new(main_window_height, main_window_width, PADDING_WIDTH, PADDING_WIDTH)
    main_window.attron(color_pair(1))  # Apply color pair to the main_window

    framed = Frame.new(
      main_window,
      'The Agencys'
    )

    framed.framed_window
  end

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

      bot1_message = 'starting ...'
      bot2_message = 'starting ...'

      count = 0

      Docker.options[:read_timeout] = 500
      Docker.options[:write_timeout] = 500

      bot1_message_old = ''
      bot2_message_old = ''

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
