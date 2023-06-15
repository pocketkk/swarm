# frozen_string_literal: true

require 'curses'
require 'docker'
require 'pry'
require 'forwardable'
require_relative 'frame'
require_relative 'agent'
require_relative 'agent_ui'

AgentUI.new.run
