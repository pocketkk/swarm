# frozen_string_literal: true

class AgentUI
  def initialize
    @queue = Queue.new
    @agent_manager = AgentManager.new
    @window_manager = WindowManager.new
    @window_manager.agents_count = agent_manager.agents.count
    @listening_thread = nil
    @listening_agents = nil
    @logger = Logger.new('/home/pocketkk/ai/agents/swarm/logs/agent_ui.log')
    @redis = Redis.new(host: '0.0.0.0', port: 6379)
  end

  def run
    logger.info('Starting Agent UI')
    agent_manager.start_agents(@queue)
    logger.info('Agents started')
    logger.info("Agents: #{agent_manager.agents}")
    listen_to_user_input
    logger.info("Listening to user input")
    listen_to_agents
    logger.info("Listening to agents")

    loop do
      event = @queue.pop # This will block until there is an event.
      break if event == 'exit'
      @logger.info("Event: #{event}")

      process_event(event)
    end

    shutdown
  ensure
    shutdown
  end

  def shutdown
    # Stop listening to user input
    @listening_thread.exit if @listening_thread
    @listening_agents.exit if @listening_agents

    # Stop all running agents
    agent_manager.stop_agents

    # Close the UI
    Curses.close_screen
  end

  def listen_to_user_input
    @listening_thread = Thread.new do
      loop do
        user_input = window_manager.get_input
        if user_input == 'exit'
          @logger.info('User requested exit')
          @queue.push('exit') # Push 'exit' to the queue so main loop will break
          break
        end

        window_manager.agents_count = agent_manager.agents.count

        @redis.publish('events', { type: :user_input, agent: 'mother', message: user_input}.to_json)
        @queue.push({ type: :user_input, message: user_input })
      end
    end
  end

  def listen_to_agents
    @listening_agents = Thread.new do
      redis_client = Redis.new(host: '0.0.0.0', port: 6379)

      logger.info("REDIS: #{redis_client}")
      redis_client.subscribe('events') do |on|
        on.message do |channel, message|
          event = JSON.parse(message)
          # handle the event
          unless event['type'] == 'user_input'
            @queue.push({ type: :agent_input, message: event['message'] })
          end
        end
      end
    end
end

  def process_event(event)
    return if event == 'exit' # Don't process if 'exit'

    case event[:type]
    when :new_message
      logger.info("New message: #{event[:message]}")
      refresh_agent_message(event[:agent])
    when :user_input
      logger.info("User input: #{event[:message]}")
      window_manager.write_to_chat_window("User: #{event[:message]}")
    when :agent_input
      logger.info("Agent input: #{event[:message]}")
      window_manager.write_to_chat_window("Agent: #{event[:message]}", 3)
    end
    window_manager.refresh!
  end

  def refresh_agent_message(agent)
    window_manager.agents_subwindow.attrset(Curses.color_pair(agent.color))  # Set color here
    window_manager.agents_subwindow.setpos(window_manager.inset_y + agent.row, window_manager.inset_x)
    window_manager.agents_subwindow.addstr("#{agent.name}: #{agent.message}")
    window_manager.agents_subwindow.attrset(Curses::A_NORMAL)  # Reset color
  end

  private

  attr_reader :window_manager, :agent_manager, :listening_thread, :logger
end
