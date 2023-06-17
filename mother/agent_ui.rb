# frozen_string_literal: true

class AgentUI
  def initialize
    @queue = Queue.new
    @agent_manager = AgentManager.new
    @window_manager = WindowManager.new
    @window_manager.agents_count = agent_manager.agents.count
    @listening_thread = nil
  end

  def run
    agent_manager.start_agents(@queue)
    listen_to_user_input

    loop do
      event = @queue.pop # This will block until there is an event.
      break if event == 'exit'

      process_event(event)
    end

    shutdown
  end

  def shutdown
    # Stop listening to user input
    @listening_thread.exit if @listening_thread

    # Stop all running agents
    agent_manager.stop_agents if agent_manager.respond_to?(:stop_agents)

    # Close the UI
    Curses.close_screen
  end

  def listen_to_user_input
    @listening_thread = Thread.new do
      loop do
        user_input = window_manager.get_input
        if user_input == 'exit'
          @queue.push('exit') # Push 'exit' to the queue so main loop will break
          break
        end

        window_manager.agents_count = agent_manager.agents.count

        @queue.push({ type: :user_input, message: user_input })
      end
    end
  end

  def process_event(event)
    return if event == 'exit' # Don't process if 'exit'

    case event[:type]
    when :new_message
      refresh_agent_message(event[:agent])
    when :user_input
      window_manager.write_to_chat_window("User: #{event[:message]}")
    end
    window_manager.refresh!
  end

  def refresh_agent_message(agent)
    window_manager.agents_subwindow.setpos(window_manager.inset_y + agent.row, window_manager.inset_x)
    window_manager.agents_subwindow.addstr("#{agent.name}: #{agent.message}")
  end

  private

  attr_reader :window_manager, :agent_manager, :listening_thread
end
