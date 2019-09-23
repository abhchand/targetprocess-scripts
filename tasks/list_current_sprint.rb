# _________        .__  .__ __________        .__.__
# \_   ___ \_____  |  | |  |\______   \_____  |__|  |
# /    \  \/\__  \ |  | |  | |       _/\__  \ |  |  |
# \     \____/ __ \|  |_|  |_|    |   \ / __ \|  |  |__
#  \______  (____  /____/____/____|_  /(____  /__|____/
#         \/     \/                 \/      \/
#
# List stories in the current sprint

require_relative "../shared/base_task"

class ListCurrentSprint < BaseTask
  def self.run!(opts = {})
    new(opts).run!
  end

  def initialize(opts = {})
    @opts = opts

    setup_logger
    validate_environment

    super()
  end

  def run!
    data = {}

    @opts[:teams].each do |team|
      team_id = team_id_for(team)
      team_iteration_id = current_iteration_for(team_id)
      assignables = assignables_for(team_iteration_id)

      data[team] = assignables.map do |assignable|
        {
          id: assignable["Id"],
          name: assignable["Name"],
          entity_type: assignable["EntityType"]["Name"],
          entity_state: assignable["EntityState"]["Name"],
          points: assignable["Effort"],
          devs: parse_developers_from_assignable(assignable).join(", ")
        }
      end
    end

    puts render_template_with(data)
  end

  private

  def validate_environment
    super

    unless @opts[:teams]
      logger.fatal("Missing :teams")
      puts "Please set --teams"
      exit
    end
  end

  def team_id_for(name)
    path = "/api/v1/Teams"
    opts = { where: "(Name eq '#{name}')" }

    response = get(path, opts)

    parse_id_from(response).tap do |id|
      logger.debug "\tFound id: #{id}"
    end
  end

  def current_iteration_for(team_id)
    path = "/api/v1/Teamiterations"
    opts = { where: "(Team.ID eq #{team_id})and(IsCurrent eq 'true')" }

    response = get(path, opts)

    parse_id_from(response).tap do |id|
      logger.debug "\tFound id: #{id}"
    end
  end

  def assignables_for(team_iteration_id)
    path = "/api/v1/Assignables"
    opts = {
      where: "(TeamIteration.ID eq #{team_iteration_id})",
      include: "[Name,EntityType[Name],EntityState[Name],Effort,Assignments[GeneralUser,Role]]"
    }

    response = get(path, opts)

    response.first["Items"]
  end

  def parse_developers_from_assignable(assignable)
    developers = assignable["Assignments"]["Items"].select do |assignment|
      assignment["Role"]["Name"] == "Developer"
    end

    developers.map do |dev|
      [dev["GeneralUser"]["FirstName"], dev["GeneralUser"]["LastName"]].join(" ")
    end
  end

  def render_template_with(data)
    template = File.join(ROOT, "templates", "list-current-sprint.erb")
    ERB.new(File.read(template)).result(binding)
  end
end
