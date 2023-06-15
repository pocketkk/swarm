# frozen_string_literal: true

require 'curses'
require 'docker'
require 'pry'
require 'forwardable'
require_relative 'frame'
require_relative 'window_manager'
require_relative 'agent_manager'

class AgentUI
  def initialize
    @window_manager = WindowManager.new
    @agent_manager = AgentManager.new
  end

  def run
    agent_manager.start_agents
    main_loop
  ensure
    Curses.close_screen
  end

  def main_loop
    loop do
      refresh_agent_messages
      window_manager.refresh
      sleep 0.25
    end
  end

  def refresh_agent_messages
    agent_manager.agents.each do |agent|
      window_manager.agents_subwindow.setpos(window_manager.inset_y + agent.row, window_manager.inset_x)
      window_manager.agents_subwindow.addstr("#{agent.name}: #{agent.message}")
    end
  end

  private

  attr_reader :window_manager, :agent_manager
end
