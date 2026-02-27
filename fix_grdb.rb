require 'xcodeproj'
project_path = 'apps/tracker-ios/RegattaTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

project.targets.each do |target|
  target.package_product_dependencies.each do |dep|
    if dep.product_name == 'GRDB.swift'
      puts "Found misnamed dependency: #{dep.product_name}"
      dep.product_name = 'GRDB'
    end
  end
end

project.save
puts "Successfully patched GRDB package product name."
