# openai_whisper_bot.rb
begin
  require_relative 'nanny/lib/nanny'

  LOG_PATH = '/app/logs/openai_whisper_bot_'

  class OpenAIWhisperBot < Nanny::NannyBot

    subscribe_to_channel ENV['CHANNEL_NAME'],
      types: ENV['EVENT_TYPES'].split(',').map(&:to_sym),
      callback: :process_event

    private

    def process_event(event)
      tell_mother('Processing event ...')

      file_path = event['message']

      response = transcribe_audio(file_path)

      publish_response(response)
    end

    def transcribe_audio(file_path)
      sleep(5)

      tell_mother("Files in /app/audio_in: #{Dir.entries('/app/audio_in')}")
      tell_mother("File exists?: #{File.exist?(file_path)}")

      uri = URI('https://api.openai.com/v1/audio/transcriptions')
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{ENV['OPENAI_API_KEY']}"

      file = File.open(file_path, 'rb')  # Open the file in binary mode
      form_data = [['file', file], ['model', 'whisper-1']]

      request.set_form form_data, 'multipart/form-data'
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
      file.close  # Close the file
      tell_mother("Full API response: #{response.inspect}")
      tell_mother("Response body: #{response.body}")

      transcription = JSON.parse(response.body)['text']

      tell_mother("Transcription response: #{response.inspect}")
      tell_mother("Transcription: #{transcription}")

      transcription.gsub('jarvis', '')
    rescue => e
      tell_mother("Transcription error: #{e.message}")
    end

    def publish_response(response)
      result = publish(channel: 'openai_chat', message: { type: :agent_input, agent: 'openai_whisper_bot', message: response}.to_json)

      tell_mother("Published message: #{response}, Publish result: #{result}")

      response
    end
  end

  OpenAIWhisperBot.new.run
rescue => e
  Logger.new(LOG_PATH).error(e.message)
  Logger.new(LOG_PATH).error(e.backtrace.join("\n"))
  Logger.new(LOG_PATH).info("Rescue me please!, waiting ...")

  loop { sleep 100 }
end
