require 'find'

def build_containers(path)
  Find.find(path) do |dir|
    next if dir =~ /\/\.git/ # Skip .git directories
    next if dir =~ /\/nanny/ # Skip copied nanny directories
    next if dir =~ /\/services/ # Skip services directories

    next if dir =~ /\/hello_bot/
    next if dir =~ /\/chroma_db_bot/

    if File.directory?(dir)
      container_name = File.basename(dir)

      rm = "rm -rf #{dir}/nanny"
      puts "Output of RM: #{system(rm)}"

      cp = "cp -r ~/ai/agents/swarm/nanny #{dir}/nanny"
      puts "Output of CP: #{system(cp)}"

      docker_build_cmd = "docker build -t #{container_name} #{dir} --no-cache"
      puts "Output of Docker Build: #{system(docker_build_cmd)}"
      puts "Built container for #{container_name} at #{dir}"
    end
  end
end

# Specify the folders to recursively build containers
folders = [
  "~/ai/agents/swarm/children/"
]

system("dstopall")
system("dremoveall")

folders.each do |folder|
  expanded_path = File.expand_path(folder)
  build_containers(expanded_path)
end

