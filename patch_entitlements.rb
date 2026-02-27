require 'xcodeproj'

def patch_entitlements(project_path, entitlements_file)
  project = Xcodeproj::Project.open(project_path)
  project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['CODE_SIGN_ENTITLEMENTS'] = entitlements_file
    end
  end
  project.save
  puts "Patched #{project_path}"
end

patch_entitlements('/Users/oscarkinnala/.gemini/antigravity/Regatta_Race/regatta-suite/apps/regatta-mac/RegattaPro.xcodeproj', 'RegattaPro/RegattaPro.entitlements')
patch_entitlements('/Users/oscarkinnala/.gemini/antigravity/Regatta_Race/regatta-suite/apps/tracker-ios/RegattaTracker.xcodeproj', 'RegattaTracker/RegattaTracker.entitlements')
