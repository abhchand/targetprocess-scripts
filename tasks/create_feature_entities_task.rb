# _________        .__  .__ __________        .__.__
# \_   ___ \_____  |  | |  |\______   \_____  |__|  |
# /    \  \/\__  \ |  | |  | |       _/\__  \ |  |  |
# \     \____/ __ \|  |_|  |_|    |   \ / __ \|  |  |__
#  \______  (____  /____/____/____|_  /(____  /__|____/
#         \/     \/                 \/      \/
#
# Programmatically create targetprocess entities

require_relative "../shared/base_task"

class CreateFeatureEntities < BaseTask
  def self.run!(opts = {})
    new(opts).run!
  end

  def initialize(opts = {})
    @opts = opts

    setup_logger
    validate_environment
    read_file

    super()
  end

  def run!
    data = {}

    @cached_projects = {}
    @cached_features = {}
    created = []

    @file["create_feature_entities"].each do |entity_type, entities|
      logger.info("==== Processing #{entity_type}")

      entities.each do |entity|
        logger.info("-> #{entity['name']}")

        project_id = project_id_for(entity["project"])
        feature_id = feature_id_for(entity["feature"])

        payload = {
          "Name" => entity["name"],
          "Project" => { "Id" => project_id },
          "Feature" => { "Id" => feature_id },
          "Description" => entity["description"]
        }

        created << create_entity(entity_type, payload)
      end
    end

    puts render_template_with(created)
  end

  private

  def validate_environment
    super

    unless @opts[:file]
      logger.fatal("Missing :file")
      puts "Please set --file"
      exit
    end
  end

  def read_file
    file = File.expand_path(@opts[:file], ROOT)

    unless File.exist?(file)
      raise "Could not find input file `#{file}`!"
    end

    @file = YAML.load(File.read(file))
    logger.debug "Mapping is: #{@file}"

    @file
  end

  def project_id_for(name)
    return @cached_projects[name] if @cached_projects.key?(name)

    path = "/api/v1/Projects"
    opts = { where: "(Name eq '#{name}')" }

    response = get(path, opts)

    parse_id_from(response).tap do |id|
      logger.debug "\tFound id: #{id}"
      @cached_projects[name] = id
    end
  end

  def feature_id_for(name)
    return @cached_features[name] if @cached_features.key?(name)

    path = "/api/v1/Features"
    opts = { where: "(Name eq '#{name}')" }

    response = get(path, opts)

    parse_id_from(response).tap do |id|
      logger.debug "\tFound id: #{id}"
      @cached_features[name] = id
    end
  end

  def create_entity(entity_type, payload)
    path = "/api/v1/#{entity_type}"
    post(path, payload)
  end

  def render_template_with(data)
    template = File.join(ROOT, "templates", "create-feature-entities.erb")
    ERB.new(File.read(template)).result(binding).tap do |output|
      output.gsub!(/\n{2,}/, "")
    end
  end
end
