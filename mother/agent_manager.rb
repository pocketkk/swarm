class AgentManager
  Docker.options[:read_timeout] = 500
  Docker.options[:write_timeout] = 500

  ENVS = [

  ]

  #attr_reader :agents

  def initialize
    #system('docker network create agent_network') unless system('docker network inspect agent_network')

    # NOTE: If this stops working check the ip addresses
    system('docker stop redis_container')
    system('docker rm redis_container')

    system('docker stop postgres_container')
    system('docker rm postgres_container')

    system('../milvus/docker-compose up -d')

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

    %w(eleven_labs openai_chat milvus_db milvus_search pg_chat pg_query weather openai_embed news).each do |agent_name|
      system("docker stop #{agent_name}")
      system("docker rm #{agent_name}")
    end

    sleep(5)

    eleven_labs = \
      Agent.new(
        name: :eleven_labs,
        row: 8,
        color: 2,
        icon: "\u{26C5}",
        container: Docker::Container.create(
          'name' => 'eleven_labs',
          'Cmd' => ['ruby', 'eleven_labs_bot.rb'],
          'Image' => 'eleven_labs_bot',
          'Tty' => true,
          'Env' => [
            "OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}",
            "OPEN_WEATHER_API_KEY=#{ENV['OPEN_WEATHER_API_KEY']}",
            "CHANNEL_NAME=eleven_labs",
            "EVENT_TYPES=user_input,agent_input",
            "PERSIST=true",
            "ELEVEN_LABS_API_KEY=#{ENV['ELEVEN_LABS_API_KEY']}",
            "PULSE_SERVER=unix:/tmp/.pulse-socket"
          ],
          'HostConfig' => {
            'NetworkMode' => 'agent_network',
            'Binds' => [
              '/home/pocketkk/ai/agents/swarm/logs:/app/logs',
              '/tmp/.pulse-socket:/tmp/.pulse-socket'
            ],
            'Devices' => [
              {
                'PathOnHost' => '/dev/snd',
                'PathInContainer' => '/dev/snd',
                'CgroupPermissions' => 'rwm'
              }
            ]
          }
        )
      )


    milvus_db = \
      Agent.new(
        name: :milvus_db,
        row: 5,
        color: 1,
        icon: "\u{1F426}",
        container: Docker::Container.create(
          'name' => 'milvus_db',
          'Cmd' => ['ruby', 'milvus_db_bot.rb'],
          'Image' => 'milvus_db_bot',
          'Tty' => true,
          'Env' => [
            "OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}",
            "CHANNEL_NAME=milvus_db",
            "EVENT_TYPES=save_user_embeddings,save_agent_embeddings",
            "PERSIST=true"
          ],
          'HostConfig' => {
            'NetworkMode' => 'agent_network',
            'Binds' => ['/home/pocketkk/ai/agents/swarm/logs:/app/logs']
          }
        )
      )

    weather = \
      Agent.new(
        name: :weather,
        row: 7,
        color: 2,
        icon: "\u{26C5}",
        container: Docker::Container.create(
          'name' => 'weather',
          'Cmd' => ['ruby', 'weather_bot.rb'],
          'Image' => 'weather_bot',
          'Tty' => true,
          'Env' => [
            "OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}",
            "OPEN_WEATHER_API_KEY=#{ENV['OPEN_WEATHER_API_KEY']}",
            "CHANNEL_NAME=weather",
            "EVENT_TYPES=user_input,agent_input",
            "PERSIST=true"
          ],
          'HostConfig' => {
            'NetworkMode' => 'agent_network',
            'Binds' => ['/home/pocketkk/ai/agents/swarm/logs:/app/logs']
          }
        )
      )

    milvus_search = \
      Agent.new(
        name: :milvus_search,
        row: 4,
        color: 1,
        icon: "\u{1F426}",
        container: Docker::Container.create(
          'name' => 'milvus_search',
          'Cmd' => ['ruby', 'milvus_search_bot.rb'],
          'Image' => 'milvus_search_bot',
          'Tty' => true,
          'Env' => [
            "OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}",
            "CHANNEL_NAME=milvus_search",
            "EVENT_TYPES=user_input,agent_input",
            "PERSIST=true"
          ],
          'HostConfig' => {
            'NetworkMode' => 'agent_network',
            'Binds' => ['/home/pocketkk/ai/agents/swarm/logs:/app/logs']
          }
        )
      )

    pg_chat = \
      Agent.new(
        name: :pg_chat,
        row: 1,
        color: 3,
        icon: "\u{1F418}",
        container: Docker::Container.create(
          'name' => 'pg_chat',
          'Cmd' => ['ruby', 'postgres_chat_bot.rb'],
          'Image' => 'postgres_chat_bot',
          'Tty' => true,
          'Env' => [
            "OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}",
            "CHANNEL_NAME=pg_chat",
            "EVENT_TYPES=user_input",
            "PERSIST=true"
          ],
          'HostConfig' => {
            'NetworkMode' => 'agent_network',
            'Binds' => ['/home/pocketkk/ai/agents/swarm/logs:/app/logs']
          }
        )
      )

    news = \
      Agent.new(
        name: :news,
        row: 8,
        color: 6,
        icon: "\u{1F4F0}",
        container: Docker::Container.create(
          'name' => 'news',
          'Cmd' => ['ruby', 'news_bot.rb'],
          'Image' => 'news_bot',
          'Tty' => true,
          'Env' => [
            "NEWS_API_KEY=#{ENV['NEWS_API_KEY']}",
            "CHANNEL_NAME=news_bot",
            "EVENT_TYPES=user_input,agent_input",
            "PERSIST=true"
          ],
          'HostConfig' => {
            'NetworkMode' => 'agent_network',
            'Binds' => ['/home/pocketkk/ai/agents/swarm/logs:/app/logs']
          }
        )
      )

    pg_query = \
      Agent.new(
        name: :pg_query,
        row: 6,
        color: 3,
        icon: "\u{1F418}",
        container: Docker::Container.create(
          'name' => 'pg_query',
          'Cmd' => ['ruby', 'pg_query_bot.rb'],
          'Image' => 'pg_query_bot',
          'Tty' => true,
          'Env' => [
            "OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}",
            "CHANNEL_NAME=pg_query",
            "EVENT_TYPES=user_input",
            "PERSIST=true"
          ],
          'HostConfig' => {
            'NetworkMode' => 'agent_network',
            'Binds' => ['/home/pocketkk/ai/agents/swarm/logs:/app/logs']
          }
        )
      )

    openai_chat = \
      Agent.new(
        name: :openai_chat,
        row: 2,
        color: 5,
        icon: "\u{1F916}",
        container: Docker::Container.create(
          'name' => 'openai_chat',
          'Cmd' => ['ruby', 'openai_chat_bot.rb'],
          'Image' => 'openai_chat_bot',
          'Tty' => true,
          'Env' => [
            "OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}",
            "CHANNEL_NAME=openai_chat",
            "EVENT_TYPES=user_input",
            "PERSIST=true"
          ],
          'HostConfig' => {
            'NetworkMode' => 'agent_network',
            'Binds' => ['/home/pocketkk/ai/agents/swarm/logs:/app/logs']
          }
        )
      )

    openai_embedding = \
      Agent.new(
        name: :openai_embed,
        row: 3,
        color: 5,
        icon: "\u{1F916}",
        container: Docker::Container.create(
          'name' => 'openai_embed',
          'Cmd' => ['ruby', 'openai_embedding_bot.rb'],
          'Image' => 'openai_embedding_bot',
          'Tty' => true,
          'Env' => [
            "OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}",
            "CHANNEL_NAME=openai_embed",
            "EVENT_TYPES=embed_user_input,embed_agent_response",
            "PERSIST=true"
          ],
          'HostConfig' => {
            'NetworkMode' => 'agent_network',
            'Binds' => ['/home/pocketkk/ai/agents/swarm/logs:/app/logs']
          }
        )
      )

    @agents = [
      openai_chat,
      milvus_db,
      openai_embedding,
      milvus_search,
      pg_chat,
      pg_query,
      weather,
      news,
      eleven_labs,
    ]
  end

  def agents
    sorted = @agents.sort { |a, b| a.name <=> b.name}
    sorted.map { |agent| agent.row = sorted.index(agent) + 1; agent }
  end

  def add_agent(agent)
    @agents << agent
  end

  def max_name_length
    @agents.map { |agent| "#{agent.icon} #{agent.name}:".length }.max
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
