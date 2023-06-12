# hello_bot.rb

puts "Starting up ..."
count = 0

begin
  loop do
    puts "Hello #{count}"

    sleep 5
    count +=1
  end
  # Put the logic of your bot here.
rescue => e
  puts "Error: #{e.message}"
  raise e
end
