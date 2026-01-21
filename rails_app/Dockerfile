FROM ruby:3.3.10

# Install build dependencies and SQLite development libraries
RUN apt-get update -qq && apt-get install -y \
    libpq-dev \
    build-essential \
    vim \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN bundle install
