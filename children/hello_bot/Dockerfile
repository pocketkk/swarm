# Dockerfile

# Start from a Ruby base image
FROM ruby:3.0.2

# Set the working directory in the container
WORKDIR /app

# Copy the Gemfile and Gemfile.lock into the Docker image
COPY Gemfile Gemfile.lock ./

# Install the gems specified in the Gemfile
RUN bundle install

# Copy the current directory contents into the container at /app
COPY . /app

# Run the Ruby script when the container launches
CMD ["ruby", "hello_bot.rb"]
