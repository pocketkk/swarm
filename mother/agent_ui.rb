# frozen_string_literal: true
require_relative 'windows/manager'
require_relative '../metal/services/bark'

class AgentUI
  def initialize
    @queue = Queue.new
    @agent_manager = AgentManager.new
    @window_manager = Windows::Manager.new(@agent_manager.agents.count)
    @listening_thread = nil
    @listening_agents = nil
    @logger = Logger.new('/home/pocketkk/ai/agents/swarm/logs/agent_ui.log')
    @redis = Redis.new(host: '0.0.0.0', port: 6379)
  end

  def run
    agent_manager.start_agents(@queue)
    listen_to_user_input
    listen_to_agents

    sleep 2

    Bark.call(text: 'Hello, Jason.  I am back online.', voice: 'al_franken')

    loop do
      event = @queue.pop # This will block until there is an event.
      break if event == 'exit'

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

    logger.info("Looking for icon for agent: #{agent}")
    found_agent = agent_manager.agents.select { |a| a.name.to_s == agent }.first

    return agent unless found_agent

    found_agent.icon
  end

  def color_for_agent(agent)
    return 2 if agent == 'mother'

    logger.info("Looking for color for agent: #{agent}")
    found_agent = agent_manager.agents.select { |a| a.name.to_s == agent }.first

    return 1 unless found_agent

    found_agent.color
  end

  def listen_to_user_input
    @redis.publish('eleven_labs', { type: :user_input, agent: 'mother', message: "Ahh, i'm back.  Hi Jason, How can i help?" }.to_json)

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
          @redis.publish('pg_chat', { type: :user_input, agent: 'mother', message: user_input.split(' ')[-1] }.to_json)
        elsif user_input.start_with?('pq ')
          @redis.publish('pg_query', { type: :user_input, agent: 'mother', message: user_input.split('pq ')[-1] }.to_json)
        elsif user_input.start_with?('weather ')
          @redis.publish('weather', { type: :user_input, agent: 'mother', message: user_input.split('weather ')[-1] }.to_json)
        elsif user_input.start_with?('weather')
          @redis.publish('weather', { type: :user_input, agent: 'mother', message: 'brush prairie,wa,usa'}.to_json)
        elsif user_input.start_with?('news ')
          @redis.publish('news', { type: :user_input, agent: 'mother', message: user_input.split('news ')[-1] }.to_json)
        elsif user_input.start_with?('say ')
          Bark.call(text: user_input.split('say ')[-1], voice: 'al_franken')
        elsif user_input == 'pd'
          window_manager.scroll_down(50)
        elsif user_input == 'pu'
          window_manager.scroll_up(50)
        else
          @redis.publish('openai_chat', { type: :user_input, agent: 'mother', message: user_input}.to_json)
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
    max_name_length = agent_manager.max_name_length
    padded_name = "#{agent.icon} #{agent.name.upcase}:".ljust(max_name_length).force_encoding('UTF-8')

    window_width = window_manager.agents_window.maxx - 2
    message_space = window_width - max_name_length - 4 # magic number
    trimmed_message = agent.message[0, message_space].force_encoding('UTF-8')

    window_manager.agents_window.attrset(Curses.color_pair(agent.color))  # Set color here
    window_manager.agents_window.setpos(window_manager.inset_y + agent.row, window_manager.inset_x - 2)
    window_manager.agents_window.addstr("#{padded_name} #{trimmed_message}")
    window_manager.agents_window.attrset(Curses::A_NORMAL)  # Reset color
  end

  private

  attr_reader :window_manager, :agent_manager, :listening_thread, :logger
end
