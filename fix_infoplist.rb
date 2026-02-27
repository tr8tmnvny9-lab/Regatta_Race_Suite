require 'xcodeproj'
project_path = '/Users/oscarkinnala/.gemini/antigravity/Regatta_Race/regatta-suite/apps/regatta-mac/RegattaPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)

project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  end
end

project.save
puts "Successfully enabled GENERATE_INFOPLIST_FILE for all targets."
