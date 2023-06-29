# frozen_string_literal: true

require 'curses'
require 'docker'
require 'pry'
require 'forwardable'
require 'redis'
require_relative 'frame'
require_relative 'agent'
require_relative 'agent_ui'
require_relative 'window_manager'
require_relative 'agent_manager'

AgentUI.new.run
