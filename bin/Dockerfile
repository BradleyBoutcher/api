FROM ubuntu:latest

WORKDIR /work

# Install speccy, used for linting
RUN apt update -y && \
    apt install -y nodejs npm ruby bundler

RUN npm i -g speccy

# Install jekyll-openapi, used for serving
RUN git clone https://github.com/robertlove/jekyll-openapi.git && \
    cd jekyll-openapi && \
    bundle install
