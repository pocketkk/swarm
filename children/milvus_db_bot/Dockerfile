# Dockerfile

FROM ruby:3.0.2

WORKDIR /app

COPY . /app

RUN apt-get update
RUN apt-get install -y vim
RUN bundle install
RUN mkdir /app/logs


CMD ["ruby", "milvus_db_bot.rb"]

VOLUME ["/app/logs"]
