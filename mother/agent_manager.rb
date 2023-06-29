class AgentManager
  Docker.options[:read_timeout] = 500
  Docker.options[:write_timeout] = 500

  attr_reader :agents

  def initialize
    #system('docker network create agent_network') unless system('docker network inspect agent_network')

    # NOTE: If this stops working check the ip addresses
    system('docker rm redis_container')

    @redis = Agent.new(
      name: :redis_container,
      row: 1,
      color: 1,
      container: Docker::Container.create(
        'name' => 'redis_container',
        'Cmd' => ['redis-server', '--appendonly', 'yes'],
        'Image' => 'redis',
        'Tty' => true,
        'ExposedPorts' => { '6379/tcp' => {} },
        'HostConfig' => {
          'PortBindings' => { '6379/tcp' => [{ 'HostPort' => '6379' }] },
          'NetworkMode' => 'agent_network'
        }
      )
    )

    @redis.container.start

    sleep(5)

openai_chat_bot = \
      Agent.new(
        name: :openai_chat_bot,
        row: 1,
        color: 1,
        container: Docker::Container.create(
          'Cmd' => ['ruby', 'openai_chat_bot.rb'],
          'Image' => 'openai_chat_bot',
          'Tty' => true,
          'Env' => ["OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}"],
          'HostConfig' => {
            'NetworkMode' => 'agent_network',
            'Binds' => ['/home/pocketkk/ai/agents/swarm/logs:/app/logs']
          }
        )
      )

    chroma_db_bot = \
      Agent.new(
        name: :chroma_db_bot,
        row: 2,
        color: 2,
        container: Docker::Container.create(
          'Cmd' => ['ruby', 'chroma_db_bot.rb'],
          'Image' => 'chroma_db_bot',
          'Tty' => true,
          'Env' => ["OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}"],
          'HostConfig' => {
            'NetworkMode' => 'agent_network',
            'Binds' => ['/home/pocketkk/ai/agents/swarm/logs:/app/logs']
          }
        )
      )

    hello_bot = \
      Agent.new(
        name: :hello_bot,
        row: 3,
        color: 2,
        container: Docker::Container.create(
          'Cmd' => ['ruby', 'hello_bot.rb', 'From Mother'],
          'Image' => 'hello_bot',
          'Tty' => true,
          'HostConfig' => {
            'NetworkMode' => 'agent_network'
          }
        )
      )

    @agents = [hello_bot, openai_chat_bot, chroma_db_bot]
  end

  def start_agents(queue)
    @agents.each { |agent| agent.start(queue) }
  end

  def stop_agents
    @agents.each { |agent| agent.container.stop }
    @redis.container.stop
  end
end
