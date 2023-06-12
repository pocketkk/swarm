
require 'docker'
require 'pry'


hello_bot = Docker::Container.create('Cmd' => ['ruby', 'hello_bot.rb', 'From Mother'], 'Image' => 'hello_bot', 'Tty' => true)
hello_bot.start

binding.pry

logs_new = hello_bot.logs(stdout: true).gsub("\0", '').gsub("\n", "").gsub(/\^A9/, '')
puts logs_new
