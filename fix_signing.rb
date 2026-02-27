require 'xcodeproj'
project_path = 'apps/regatta-mac/RegattaPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
    config.build_settings.delete('CODE_SIGN_IDENTITY')
  end
end
project.save
puts "Successfully reset RegattaPro signing to Automatic."
