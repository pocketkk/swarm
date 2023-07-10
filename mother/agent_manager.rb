class AgentManager
  Docker.options[:read_timeout] = 500
  Docker.options[:write_timeout] = 500

  attr_reader :agents

  def initialize
    #system('docker network create agent_network') unless system('docker network inspect agent_network')

    # NOTE: If this stops working check the ip addresses
    system('docker stop redis_container')
    system('docker rm redis_container')

    system('docker stop postgres_container')
    system('docker rm postgres_container')

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

    @postgres = Agent.new(
      name: :postgres_container,
      row: 1,
      color: 1,
      container: Docker::Container.create(
        'name' => 'postgres_container',
        'Cmd' => ['postgres'],
        'Image' => 'postgres',
        'Tty' => true,
        'ExposedPorts' => { '5432/tcp' => {} },
        'Env' => [
          'POSTGRES_PASSWORD=postgres',
          'POSTGRES_USER=postgres'
        ],
        'HostConfig' => {
          'PortBindings' => { '5432/tcp' => [{ 'HostPort' => '5432' }] },
          'NetworkMode' => 'agent_network',
          'Binds' => ['/home/pocketkk/ai/agents/swarm/postgres_data:/var/lib/postgresql/data']
        }
      )
    )

    @postgres.container.start
    @redis.container.start

    sleep(5)

    milvus_db_bot = \
      Agent.new(
        name: :milvus_db_bot,
        row: 5,
        color: 1,
        icon: "\u{1F344}",
        container: Docker::Container.create(
          'Cmd' => ['ruby', 'milvus_db_bot.rb'],
          'Image' => 'milvus_db_bot',
          'Tty' => true,
          'Env' => ["OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}"],
          'HostConfig' => {
            'NetworkMode' => 'agent_network',
            'Binds' => ['/home/pocketkk/ai/agents/swarm/logs:/app/logs']
          }
        )
      )

    milvus_search_bot = \
      Agent.new(
        name: :milvus_search_bot,
        row: 4,
        color: 6,
        icon: "\u{1F33F}",
        container: Docker::Container.create(
          'Cmd' => ['ruby', 'milvus_search_bot.rb'],
          'Image' => 'milvus_search_bot',
          'Tty' => true,
          'Env' => ["OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}"],
          'HostConfig' => {
            'NetworkMode' => 'agent_network',
            'Binds' => ['/home/pocketkk/ai/agents/swarm/logs:/app/logs']
          }
        )
      )

    postgres_chat_bot = \
      Agent.new(
        name: :postgres_chat_bot,
        row: 1,
        color: 3,
        icon: "\u{1F334}",
        container: Docker::Container.create(
          'Cmd' => ['ruby', 'postgres_chat_bot.rb'],
          'Image' => 'postgres_chat_bot',
          'Tty' => true,
          'Env' => ["OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}"],
          'HostConfig' => {
            'NetworkMode' => 'agent_network',
            'Binds' => ['/home/pocketkk/ai/agents/swarm/logs:/app/logs']
          }
        )
      )

    openai_chat_bot = \
      Agent.new(
        name: :openai_chat_bot,
        row: 2,
        color: 4,
        icon: "\u{1F424}",
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

    openai_embedding_bot = \
      Agent.new(
        name: :openai_embedding_bot,
        row: 3,
        color: 5,
        icon: "\u{1F438}",
        container: Docker::Container.create(
          'Cmd' => ['ruby', 'openai_embedding_bot.rb'],
          'Image' => 'openai_embedding_bot',
          'Tty' => true,
          'Env' => ["OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}"],
          'HostConfig' => {
            'NetworkMode' => 'agent_network',
            'Binds' => ['/home/pocketkk/ai/agents/swarm/logs:/app/logs']
          }
        )
      )

    #chroma_db_bot = \
    #Agent.new(
    #name: :chroma_db_bot,
    #row: 3,
    #color: 2,
    #container: Docker::Container.create(
    #'Cmd' => ['ruby', 'chroma_db_bot.rb'],
    #'Image' => 'chroma_db_bot',
    #'Tty' => true,
    #'Env' => ["OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}"],
    #'HostConfig' => {
    #'NetworkMode' => 'agent_network',
    #'Binds' => ['/home/pocketkk/ai/agents/swarm/logs:/app/logs']
    #}
    #)
    #)

    @agents = [
      openai_chat_bot,
      milvus_db_bot,
      openai_embedding_bot,
      milvus_search_bot,
      postgres_chat_bot
    ]
  end

  def start_agents(queue)
    @agents.each { |agent| agent.start(queue) }
  end

  def stop_agents
    @agents.each { |agent| agent.container.stop }
    @redis.container.stop
    @postgres.container.stop
  end
end
