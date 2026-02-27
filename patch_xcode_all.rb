require 'xcodeproj'
project_path = '/Users/oscarkinnala/.gemini/antigravity/Regatta_Race/regatta-suite/apps/regatta-mac/RegattaPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first
group = project.main_group.find_subpath('RegattaPro', true)

Dir.glob('/Users/oscarkinnala/.gemini/antigravity/Regatta_Race/regatta-suite/apps/regatta-mac/RegattaPro/**/*.swift').each do |file_path|
  unless project.files.any? { |f| f.real_path.to_s == file_path }
    file_ref = group.new_reference(file_path)
    target.source_build_phase.add_file_reference(file_ref)
    puts "Added #{file_path}"
  end
end
project.save
