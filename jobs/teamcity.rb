require 'logger'
require 'teamcity'

LOG = Logger.new(STDOUT)


def update_builds(project_id)
  LOG.info("Pulling build status for #{project_id}")

  builds = []
  projects = []

  project = TeamCity.project(id: project_id)
  build_types = []

  project.buildTypes.buildType.each do |build_type|
    build_types << {
      id:   build_type.id,
      name: build_type.name
    }
  end

  build_types.each do |build_type_obj|
    build_type_obj_builds = TeamCity.builds(count: 1, buildType: build_type_obj[:id])
    unless build_type_obj_builds.nil?
      last_build = build_type_obj_builds.first

      build_type_obj['last_build'] = {
        id:     last_build.id,
        number: last_build.number,
        state:  last_build.state,
        status: last_build.status
      }
    end
  end

  projects << {
    name:        project.name,
    id:          project.id,
    description: project.description,
    build_types: build_types
  }

  builds << {
      title:    project_id,
      projects: projects
  }

  builds
end

config_file = File.dirname(File.expand_path(__FILE__)) + '/../config/teamcity.yml'
config = YAML::load(File.open(config_file))

TeamCity.configure do |c|
  c.endpoint = config['api_url']
  c.http_user = config['http_user']
  c.http_password = config['http_password']
end

spread = 5
if config['repositories'].nil?
  LOG.warn('You need at least one TeamCity repository!')
else
  config['repositories'].each_with_index do |repository, i|
    data_id, build_id = repository
    delay = spread * (i + 1)
    LOG.info("Scheduling #{build_id} to pull in #{delay}s")
    SCHEDULER.every '33s', first_in: "#{delay}s" do
      send_event(data_id, {items: update_builds(build_id)})
    end
  end
end
