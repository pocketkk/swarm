# frozen_string_literal: true

require 'thread'

class Agent
  extend Forwardable

  attr_accessor :name,
                :messages,
                :previous_message,
                :row,
                :icon,
                :offset,
                :color,
                :container,
                :channel_name,
                :event_types,
                :image

  def initialize(name:, color: 1, channel_name: '', icon: '', event_types: [], container: nil, image: nil)
    @color = color
    @channel_name = channel_name
    @name = name
    @image = image || "#{name}_bot"
    @event_types = event_types
    @container = container || container_by_name
    @row = 0
    @offset = 0
    @messages = messages
    @previous_message = ''
    @icon = icon
  end


  def container_by_name
    @container ||= Docker::Container.create(
      'name' => "#{name}",
      'Cmd' => ['ruby', "#{name}_bot.rb"],
      'Image' => image,
      'Tty' => true,
      'Env' => [
        "OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}",
        "OPEN_WEATHER_API_KEY=#{ENV['OPEN_WEATHER_API_KEY']}",
        "ELEVEN_LABS_API_KEY=#{ENV['ELEVEN_LABS_API_KEY']}",
        "NEWS_API_KEY=#{ENV['NEWS_API_KEY']}",
        "CHANNEL_NAME=#{channel_name}",
        "EVENT_TYPES=#{event_types.join(',')}",
        "PERSIST=true"
      ],
      'HostConfig' => {
        'NetworkMode' => 'agent_network',
        'Binds' => ['/home/pocketkk/ai/agents/swarm/logs:/app/logs']
      }
    )
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

