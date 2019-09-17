# _________        .__  .__ __________        .__.__
# \_   ___ \_____  |  | |  |\______   \_____  |__|  |
# /    \  \/\__  \ |  | |  | |       _/\__  \ |  |  |
# \     \____/ __ \|  |_|  |_|    |   \ / __ \|  |  |__
#  \______  (____  /____/____/____|_  /(____  /__|____/
#         \/     \/                 \/      \/
#
# Provides a base class for all tasks that interact with targetprocess
#

require_relative "multi_channel_logger"

require "dotenv/load"
require "active_support"
require "active_support/core_ext/object/blank.rb"
require "active_support/core_ext/time/zones"
require "active_support/core_ext/numeric/time"

require "httparty"

require "yaml"

class BaseTask
  ROOT = File.expand_path("..", __dir__)

  DEFAULT_TP_ORG = "callrail".freeze

  HEADERS = {
    "Content-Type": "application/json",
    "Accept" => "application/json"
  }

  include HTTParty
  headers HEADERS

  attr_accessor :logger, :config

  def initialize
    @fixed_params = { access_token: access_token, resultFormat: "json" }

    logger.debug("Setting base URI: #{base_uri}")
    self.class.base_uri(base_uri)
  end

  private

  def access_token
    @access_token ||= ENV["TP_ACCESS_TOKEN"]
  end

  def base_uri
    @base_uri ||= "https://#{tp_org}.tpondemand.com"
  end

  def tp_org
    return DEFAULT_TP_ORG.downcase unless defined?(@opts)
    (@opts[:tp_org] || DEFAULT_TP_ORG).downcase
  end

  def setup_logger
    # TODO: Avoid using `caller` in the future
    # We use it to get the name of the invoking class/file so we can
    # use it in our logfile name
    previous_file = caller.first.split(":").first

    logfile = File.join(
      ROOT,
      "log",
      File.basename(previous_file, File.extname(previous_file)) + ".log"
    )

    @logger = MultiChannelLogger.new([logfile, STDOUT], "monthly")
    @logger.level = @opts[:verbose] ? :debug : :info
    @logger.info("Logging to logfile: #{logfile}")
  end

  def validate_environment
    logger.debug("Checking if ENV variables are set")

    if access_token.blank?
      logger.fatal("Env not set correctly")
      puts "Please set `TP_ACCESS_TOKEN`"
      exit
    end
  end

  def get(path, opts = {})
    responses = []
    take = 250
    skip = 0

    opts.merge!(@fixed_params)

    loop do
      qp = opts.merge(take: take, skip: skip)

      logger.debug("\tGET #{path} (#{qp})")
      response = self.class.get(path, query: qp)

      unless (200..299).member?(response.code)
        logger.fatal("Request failed: (#{response.code}) #{response.body}")
        exit
      end

      json_body = JSON.parse(response.body)
      responses << json_body
      skip += take

      break unless next_page?(json_body)
    end

    responses.flatten
  end

  def post(path, payload = {})
    qp = @fixed_params

    logger.debug("\tPOST #{path} (#{qp}) (#{payload})")
    response = self.class.post(path, query: qp, body: payload.to_json)

    unless (200..299).member?(response.code)
      logger.fatal("Request failed: (#{response.code}) #{response.body}")
      exit
    end

    JSON.parse(response.body)
  end

  def next_page?(response_body)
    # TargetProcess returns a "link" param that specifies the next paginated
    # value.
    #
    # "Prev": "http://localhost/Targetprocess/api/v1/UserStories?take=10&skip=0"
    # "Next": "http://localhost/Targetprocess/api/v1/UserStories?take=20&skip=30"
    #
    # Note: We don't use the URL provided by TP, we just keep track of our
    # own skip/take counter
    response_body.key?("Next")
  end
end
