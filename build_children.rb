#require 'find'

#def build_containers(path)
  #Find.find(path) do |dir|
    #next if dir =~ /\/\.git/ # Skip .git directories
    #next if dir =~ /\/nanny/ # Skip copied nanny directories
    #next if dir =~ /\/services/ # Skip services directories

    #next if dir =~ /\/hello_bot/
    #next if dir =~ /\/chroma_db_bot/

    #if File.directory?(dir)
      #container_name = File.basename(dir)

      #rm = "rm -rf #{dir}/nanny"
      #puts "Output of RM: #{system(rm)}"

      #cp = "cp -r ~/ai/agents/swarm/nanny #{dir}/nanny"
      #puts "Output of CP: #{system(cp)}"

      #docker_build_cmd = "docker build -t #{container_name} #{dir} --no-cache"
      #puts "Output of Docker Build: #{system(docker_build_cmd)}"
      #puts "Built container for #{container_name} at #{dir}"
    #end
  #end
#end

## Specify the folders to recursively build containers
#folders = [
  #"~/ai/agents/swarm/children/"
#]

#system("dstopall")
#system("dremoveall")

#folders.each do |folder|
  #expanded_path = File.expand_path(folder)
  #build_containers(expanded_path)
#end


require 'find'
require 'time'

CHANGELOG_PATH = "/home/pocketkk/ai/agents/swarm/logs/last_start_run.txt"

def read_last_update_time
  if File.exist?(CHANGELOG_PATH)
    Time.parse(File.read(CHANGELOG_PATH))
  else
    Time.at(0) # return Unix epoch if the file doesn't exist
  end
end

def write_last_update_time(time)
  File.write(CHANGELOG_PATH, time.to_s)
end

def nanny_changed?(last_update_time)
  nanny_dir = File.expand_path("~/ai/agents/swarm/nanny")
  last_modified = Dir.glob("#{nanny_dir}/**/*").map { |f| File.mtime(f) }.max
  last_modified > last_update_time
end

def build_containers(path, last_update_time)
  Find.find(path) do |dir|
    next if dir =~ /\/\.git/ # Skip .git directories
    next if dir =~ /\/nanny/ # Skip copied nanny directories
    next if dir =~ /\/services/ # Skip services directories

    next if dir =~ /\/hello_bot/
    next if dir =~ /\/chroma_db_bot/

    if File.directory?(dir)
      # If no file in the directory was modified since the last update, skip this directory
      last_modified = Dir.glob("#{dir}/**/*").map { |f| File.mtime(f) }.max
      next if last_modified < last_update_time && !nanny_changed?(last_update_time)

      container_name = File.basename(dir)

      if nanny_changed?(last_update_time)
        rm = "rm -rf #{dir}/nanny"
        puts "Output of RM: #{system(rm)}"

        cp = "cp -r ~/ai/agents/swarm/nanny #{dir}/nanny"
        puts "Output of CP: #{system(cp)}"
      end

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

last_update_time = read_last_update_time()

folders.each do |folder|
  expanded_path = File.expand_path(folder)
  build_containers(expanded_path, last_update_time)
end

write_last_update_time(Time.now)
