Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8
require 'xcodeproj'

mac_proj = Xcodeproj::Project.open('apps/regatta-mac/RegattaPro.xcodeproj')
mac_group = mac_proj.main_group.find_subpath('RegattaPro/Views/Main', true)

file1 = mac_group.new_file('ManualPairingMatrix.swift')

mac_target = mac_proj.targets.find { |t| t.name == 'RegattaPro' }
mac_target.add_file_references([file1]) if mac_target
mac_proj.save
