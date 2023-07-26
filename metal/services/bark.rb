#metal/services/bark.rb

class Bark
  def self.call(text:, path: 'audio_out', voice: 'al_franken')
    new(text, path, voice).bark
  end

  def initialize(text, path, voice)
    @text = text
    @path = path
    @voice = voice
  end

  def timestamp
    Time.now.strftime('%Y%m%d%H%M%S')
  end

  def file_path
    "#{@path}/#{timestamp}.wav"
  end

  def bark
    #system("python3 bark-with-voice-clone/write.py '#{@text}' '#{@file_path}' '#{@voice}' > /dev/null")
    @thread = Thread.new do
      system("python3 bark-with-voice-clone/write.py '#{@text}' '#{file_path}' '#{@voice}' > /dev/null 2>&1")
    end
  ensure
    @thread.join
  end
end
