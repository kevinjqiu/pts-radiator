require 'logger'
require 'teamcity'
require 'byebug'

LOG = Logger.new(STDOUT)


def update_builds(project_id, excluded_buildtypes)
  LOG.info("Pulling build status for #{project_id}")

  builds = []

  project = TeamCity.project(id: project_id)
  build_types = []

  project.buildTypes.buildType.each do |build_type|
    if not excluded_buildtypes.include?(build_type[:id])

      build_type_obj_builds = TeamCity.builds(count: 1, buildType: build_type[:id])
      unless build_type_obj_builds.nil?
        last_build = build_type_obj_builds.first

        build_types << {
          id:         build_type.id,
          name:       build_type.name,
          last_build: {
            id:     last_build.id,
            number: last_build.number,
            state:  last_build.state,
            status: last_build.status,
          }
        }
      end
    end
  end

  project = {
    name:        project.name,
    id:          project.id,
    description: project.description,
  }

  build_types.each do |build_type_obj|
    build_type_obj_builds = TeamCity.builds(count: 1, buildType: build_type_obj[:id])
    unless build_type_obj_builds.nil?
      last_build = build_type_obj_builds.first

      build_type_obj[:last_build] = {
        id:     last_build.id,
        number: last_build.number,
        state:  last_build.state,
        status: last_build.status,
      }
    end
  end

  project[:build_type] = build_types
  success = build_types.all? { |build_type| build_type[:last_build][:status] == 'SUCCESS' }
  if not success
    project[:build_step_to_show] = build_types.find { |build_type| build_type[:last_build][:status] != 'SUCCESS' }
  else
    last_step = build_types[-1]
    # make a synthetic build step so the dashboard can display ALL GOOD
    project[:build_step_to_show] = {
      id:         '',
      name:       'ALL GOOD',
      last_build: last_step[:last_build],
    }
  end

  project[:status] = project[:build_step_to_show][:last_build][:status]

  project
end

config_file = File.dirname(File.expand_path(__FILE__)) + '/../config/teamcity.yml'
config = YAML::load(File.open(config_file))

TeamCity.configure do |teamcity|
  teamcity.endpoint = config['api_url']
  teamcity.http_user = config['http_user']
  teamcity.http_password = config['http_password']
end

spread = 5
if config['projects'].nil?
  LOG.warn('You need at least one TeamCity project!')
else
  config['projects'].each_with_index do |project, i|
    data_id, build_id = project
    delay = spread * (i + 1)
    LOG.info("Scheduling #{build_id} to pull in #{delay}s")
    SCHEDULER.every '45s', first_in: "#{delay}s" do
      send_event(data_id, {project: update_builds(build_id, config['excluded_buildtypes'])})
    end
  end
end
