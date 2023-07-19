class AgentManager
  Docker.options[:read_timeout] = 500
  Docker.options[:write_timeout] = 500

  def initialize
    prepare_resources
    sleep(5)

    #eleven_labs = \
      #Agent.new(
        #name: :eleven_labs,
        #color: 2,
        #icon: "\u{1F60A}",
        #container: Docker::Container.create(
          #'name' => 'eleven_labs',
          #'Cmd' => ['ruby', 'eleven_labs_bot.rb'],
          #'Image' => 'eleven_labs_bot',
          #'Tty' => true,
          #'Env' => [
            #"OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}",
            #"OPEN_WEATHER_API_KEY=#{ENV['OPEN_WEATHER_API_KEY']}",
            #"CHANNEL_NAME=eleven_labs",
            #"EVENT_TYPES=user_input,agent_input",
            #"PERSIST=true",
            #"ELEVEN_LABS_API_KEY=#{ENV['ELEVEN_LABS_API_KEY']}",
            #"PULSE_SERVER=unix:/tmp/.pulse-socket",
            #"VOICE=MF3mGyEYCl7XYWbV9V6O"
          #],
          #'HostConfig' => {
            #'NetworkMode' => 'agent_network',
            #'Binds' => [
              #'/home/pocketkk/ai/agents/swarm/logs:/app/logs',
              #'/tmp/.pulse-socket:/tmp/.pulse-socket'
            #],
            #'Devices' => [
              #{
                #'PathOnHost' => '/dev/snd',
                #'PathInContainer' => '/dev/snd',
                #'CgroupPermissions' => 'rwm'
              #}
            #]
          #}
        #)
      #)

    milvus_db = Agent.new(
      name: :milvus_db,
      color: 1,
      icon: "\u{1F426}",
      channel_name: 'milvus_db',
      event_types: ['save_user_embeddings', 'save_agent_embeddings']
    )
    weather = Agent.new(
      name: :weather,
      color: 2,
      icon: "\u{26C5}",
      channel_name: 'weather',
      event_types: ['user_input', 'agent_input']
    )

    milvus_search = Agent.new(
      name: :milvus_search,
      color: 1,
      icon: "\u{1F426}",
      channel_name: 'milvus_search',
      event_types: ['user_input', 'agent_input']
    )

    pg_chat = Agent.new(
      name: :pg_chat,
      color: 3,
      icon: "\u{1F418}",
      channel_name: 'pg_chat',
      event_types: ['user_input']
    )

    news = Agent.new(
      name: :news,
      color: 6,
      icon: "\u{1F4F0}",
      channel_name: 'news',
      event_types: ['user_input', 'agent_input']
    )

    pg_query = Agent.new(
      name: :pg_query,
      color: 3,
      icon: "\u{1F418}",
      channel_name: 'pg_query',
      event_types: ['user_input']
    )

    openai_chat = Agent.new(
      name: :openai_chat,
      color: 5,
      icon: "\u{1F916}",
      channel_name: 'openai_chat',
      event_types: ['user_input', 'agent_input']
    )

    openai_embedding = Agent.new(
      name: :openai_embed,
      color: 5,
      icon: "\u{1F916}",
      channel_name: 'openai_embed',
      event_types: ['embed_user_input', 'embed_agent_response']
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
      #eleven_labs,
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

  def prepare_resources
    system('docker stop redis_container')
    system('docker rm redis_container')

    system('docker stop postgres_container')
    system('docker rm postgres_container')

    system('../milvus/docker-compose up -d')

    @redis = Agent.new(
      name: :redis_container,
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
  end
end
