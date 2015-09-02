require 'teamcity'
require 'byebug'

def update_builds(project_id)
  builds = []
  projects = []

  TeamCity.project(:id => project_id).projects.project.each do |project|
    build_types = []

    TeamCity.project_buildtypes(:id => project.id).each do |build_type|
      build_types.push({
          :id => build_type.id,
          :name => build_type.name
      })
    end

    build_types.each do |build_type_obj|
      build_type_obj_builds = TeamCity.builds(:count => 1, :buildType => build_type_obj[:id])
      unless build_type_obj_builds.nil?
        last_build = build_type_obj_builds.first

        build_type_obj['last_build'] = {
            :id => last_build.id,
            :number => last_build.number,
            :state => last_build.state,
            :status => last_build.status
        }
      end
    end

    projects.push({
      :name => project.name,
      :id => project.id,
      :description => project.description,
      :build_types => build_types
    })
  end

  build_info = {
      :title => project_id,
      :projects => projects
  }

  builds << build_info

  builds
end

config_file = File.dirname(File.expand_path(__FILE__)) + '/../config/teamcity.yml'
config = YAML::load(File.open(config_file))

TeamCity.configure do |c|
  c.endpoint = config['api_url']
  c.http_user = config['http_user']
  c.http_password = config['http_password']
end

SCHEDULER.every '33s', :first_in => '1s' do
  if config['repositories'].nil?
    puts 'No TeamCity repositories found :('
  else
    config['repositories'].each do |data_id, build_id|
      send_event(data_id, { :items => update_builds(build_id)})
    end
  end
end
