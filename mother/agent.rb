# frozen_string_literal: true

require 'thread'

class Agent
  extend Forwardable

  attr_accessor :container,
                :name,
                :messages,
                :previous_message,
                :row,
                :color

  def initialize(container:, name:, row:, color:)
    @container = container
    @color = color
    @name = name
    @row = row
    @messages = messages
    @previous_message = ''
  end

  def start(queue)
    container.start
    # Start a new thread that watches for new messages.
    Thread.new do
      loop do
        # Check for new message.
        if message != @previous_message
          @previous_message = message
          # Enqueue an event.
          queue.push({ type: :new_message, agent: self })
        end
        sleep 0.1
      end
    end
  end

  def raw_message
    logs(stdout: true, tail: 1)
  end

  def message
    raw_message.gsub("\0", '').gsub("\r\n", '').gsub(/\^A9/, '')
  end

  def_delegator :@container, :logs
end

