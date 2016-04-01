#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'

require 'marathon'
require 'httparty'
require 'cabin'

marathon_url            = ENV['MARATHON_URL'] || 'http://localhost:8080'
filter_label            = ENV['FILTER_LABEL'] || 'spread==true'
marathon_poll_interval  = ENV['MARATHON_POLL_INTERVAL'] || 10
logger                  = Cabin::Channel.new
logger.level            = ENV['LOG_LEVEL'] || :info
logger.subscribe(STDOUT)

logger.info("START marathon-spread helper", {
  marathon_url: marathon_url,
  filter_label: filter_label,
  poll_interval: marathon_poll_interval
})

loop do
  begin
    Marathon.url = marathon_url
    connection = Marathon::Connection.new(marathon_url)
    mesos_url = Marathon.info['marathon_config']['mesos_leader_ui_url']

    response = HTTParty.get("#{mesos_url}metrics/snapshot")
    logger.debug("mesos-metrics", {
      mesos_url: mesos_url,
      body:      response.body,
      code:      response.code,
      message:   response.message,
      headers:   response.headers
    })

    active_mesos_agents = response['master/slaves_active'].to_i
    raise "No mesos agents running" unless active_mesos_agents > 0
    # random_number_of_agents = rand(6)+1
    # puts "Emulating #{random_number_of_agents} agents"
    # active_mesos_agents= random_number_of_agents

    # apps = Marathon::Apps.new(connection)
    # puts apps.list(label: 'spread==true')

    query = {}
    query[:label] = filter_label
    json = connection.get('/v2/apps', query)['apps']
    apps = json.map { |j| Marathon::App.new(j) }

    apps.each do |app|
      if app.instances == active_mesos_agents
        logger.info("SKIP #{app.id}", {
          active_mesos_agents: active_mesos_agents,
          instances: app.instances
        })
      else
        logger.info("SCALE #{app.id}", {
          active_mesos_agents: active_mesos_agents,
          instances: app.instances
        })
        app.scale!(active_mesos_agents, true)
      end
    end
    sleep(marathon_poll_interval.to_i)
  rescue => e
    logger.error("An error occurred", :exception => e, :backtrace => e.backtrace)
  end
end
