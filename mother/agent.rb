# frozen_string_literal: true

class Agent
  extend Forwardable

  attr_accessor :container,
                :name,
                :messages,
                :previous_message,
                :row

  def initialize(container:, name:, row:)
    @container = container
    @name = name
    @row = row
    @messages = messages
    @previous_message = ''
  end

  def start
    container.start
  end

  def raw_message
    logs(stdout: true, tail: 1)
  end

  def message
    raw_message.gsub("\0", '').gsub("\r\n", '').gsub(/\^A9/, '')
  end

  def_delegator :@container, :logs
end

