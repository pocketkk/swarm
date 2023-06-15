class AgentManager
  Docker.options[:read_timeout] = 500
  Docker.options[:write_timeout] = 500

  attr_reader :agents

  def initialize
    openai_chat_bot = \
      Agent.new(
        name: :openai_chat_bot,
        row: 1,
        container: Docker::Container.create(
          'Cmd' => ['ruby', 'openai_chat_bot.rb', 'What is the capitol of France?', ENV['OPENAI_API_KEY']],
          'Image' => 'openai_chat_bot',
          'Tty' => true
        )
      )

    hello_bot = \
      Agent.new(
        name: :hello_bot,
        row: 2,
        container: Docker::Container.create(
          'Cmd' => ['ruby', 'hello_bot.rb', 'From Mother'],
          'Image' => 'hello_bot',
          'Tty' => true
        )
      )

    @agents = [hello_bot, openai_chat_bot]
  end

  def start_agents
    @agents.map(&:start)
  end
end
