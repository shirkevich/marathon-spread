FROM ruby:2.3-onbuild

RUN wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.0.1/dumb-init_1.0.1_amd64
RUN chmod +x /usr/local/bin/dumb-init

CMD ["/usr/local/bin/dumb-init", "ruby", "./marathon_spread.rb"]
