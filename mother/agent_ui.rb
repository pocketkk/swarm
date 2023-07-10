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
    @listening_thread.exit if @listening_thread
    @listening_agents.exit if @listening_agents

    agent_manager.stop_agents

    Curses.close_screen
  end

  def icon_for_agent(agent)
    return '🤖' if agent == 'mother'

    found_agent = agent_manager.agents.select { |a| a.name.to_s == agent }.first

    return agent unless found_agent

    found_agent.icon
  end

  def color_for_agent(agent)
    return 2 if agent == 'mother'

    found_agent = agent_manager.agents.select { |a| a.name.to_s == agent }.first

    return 1 unless found_agent

    found_agent.color
  end

  def listen_to_user_input
    @listening_thread = Thread.new do
      loop do
        user_input = window_manager.get_input
        if user_input == 'exit'
          @logger.info('User requested exit')
          @queue.push('exit')
          break
        end

        if user_input.start_with?('search ')
          @redis.publish('milvus_search', { type: :user_input, agent: 'mother', message: user_input}.to_json)
        elsif user_input.start_with?('pg ')
          @redis.publish('postgres_chat_bot', { type: :user_input, agent: 'mother', message: user_input.split(' ')[-1] }.to_json)
        else
          @redis.publish('events', { type: :user_input, agent: 'mother', message: user_input}.to_json)
        end

        window_manager.agents_count = agent_manager.agents.count

        @queue.push({ type: :user_input, agent: 'mother', message: user_input })
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
          unless ['user_input', 'new_user_embedding', 'new_agent_embedding'].include?(event['type'])
            @queue.push({ type: :agent_input, agent: event['agent'], message: event['message'] })
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
      window_manager.write_to_chat_window("Agent: (#{icon_for_agent(event[:agent])}): #{event[:message]}", color_for_agent(event[:agent]))
    end
    window_manager.refresh!
  end

  def refresh_agent_message(agent)
    window_manager.agents_subwindow.attrset(Curses.color_pair(agent.color))  # Set color here
    window_manager.agents_subwindow.setpos(window_manager.inset_y + agent.row, window_manager.inset_x)
    window_manager.agents_subwindow.addstr("#{agent.icon} #{agent.name.upcase}: #{agent.message}")
    window_manager.agents_subwindow.attrset(Curses::A_NORMAL)  # Reset color
  end

  private

  attr_reader :window_manager, :agent_manager, :listening_thread, :logger
end
