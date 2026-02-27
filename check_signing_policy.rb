require 'xcodeproj'
project_path = 'apps/regatta-mac/RegattaPro.xcodeproj'
project = Xcodeproj::Project.open(project_path)

project.targets.each do |target|
  # We can't easily detect the team type here, but we can make it an option
  # or just remove the capability and entitlements if it's blocking the build.
  # For now, let's keep the entitlements but suggest the user to use a paid team.
  # Alternatively, we can remove it for the 'Debug' config.
  
  target.build_configurations.each do |config|
    # If the user is on a personal team, this capability often fails.
    # We could try to disable it here, but it's better to tell the user.
  end
end

puts "Note: Sign In with Apple requires a paid Apple Developer Program membership for Mac apps."
puts "If you are using a Personal Team, you may need to remove the 'Sign in with Apple' capability in Xcode's 'Signing & Capabilities' tab to build successfully."
