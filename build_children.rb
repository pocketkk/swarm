require 'find'

def build_containers(path)
  Find.find(path) do |dir|
    if File.directory?(dir)
      container_name = File.basename(dir)
      docker_build_cmd = "docker build -t #{container_name} #{dir} --no-cache"
      system(docker_build_cmd)
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

