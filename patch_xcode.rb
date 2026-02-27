require 'xcodeproj'
project_path = '/Users/oscarkinnala/.gemini/antigravity/Regatta_Race/regatta-suite/apps/regatta-mac/RegattaPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group_conn = project.main_group.find_subpath('RegattaPro/Connection', true)
group_models = project.main_group.find_subpath('RegattaPro/Models', true)

files = {
  '/Users/oscarkinnala/.gemini/antigravity/Regatta_Race/regatta-suite/apps/regatta-mac/RegattaPro/Connection/UDPListener.swift' => group_conn,
  '/Users/oscarkinnala/.gemini/antigravity/Regatta_Race/regatta-suite/apps/regatta-mac/RegattaPro/Connection/RaceEngineClient.swift' => group_conn,
  '/Users/oscarkinnala/.gemini/antigravity/Regatta_Race/regatta-suite/apps/regatta-mac/RegattaPro/Models/RaceStateModel.swift' => group_models
}

files.each do |path, group|
  unless project.files.any? { |f| f.real_path.to_s == path }
    file_ref = group.new_reference(path)
    target.source_build_phase.add_file_reference(file_ref)
    puts "Added #{path}"
  end
end
project.save
