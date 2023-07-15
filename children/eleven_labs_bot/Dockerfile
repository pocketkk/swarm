# Dockerfile

FROM ruby:3.0.2

RUN apt-get update -y && \
    apt-get install -y alsa-utils mpg123 pulseaudio-utils ffmpeg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . /app

RUN bundle install
RUN mkdir /app/logs

CMD ["ruby", "openai_chat_bot.rb"]

VOLUME [ "/app/logs" ]
