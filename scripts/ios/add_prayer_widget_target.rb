#!/usr/bin/env ruby
# Ajoute l'extension WidgetKit « PrayerWidget » au projet Xcode.
#
# Idempotent : sans effet si la cible existe déjà. Le résultat est commité ;
# ce script sert à le reproduire (ou à le vérifier) sans ouvrir Xcode.
#   gem install xcodeproj && ruby scripts/ios/add_prayer_widget_target.rb
require 'xcodeproj'

PROJECT = File.expand_path('../../ios/Runner.xcodeproj', __dir__)
TARGET = 'PrayerWidgetExtension'
BUNDLE_ID = 'com.elboazzati.muslimapp.PrayerWidget'

project = Xcodeproj::Project.open(PROJECT)
if project.targets.any? { |t| t.name == TARGET }
  puts "#{TARGET} existe déjà : rien à faire."
  exit 0
end
runner = project.targets.find { |t| t.name == 'Runner' } or abort 'Cible Runner introuvable'

# --- Extension -------------------------------------------------------------
ext = project.new_target(:app_extension, TARGET, :ios, '16.0', nil, :swift)
ext.add_build_configuration('Profile', :release) unless ext.build_configurations.any? { |c| c.name == 'Profile' }

group = project.main_group.new_group('PrayerWidget', 'PrayerWidget')
swift = group.new_file('PrayerWidget.swift')
group.new_file('Info.plist')
group.new_file('PrayerWidget.entitlements')
base_xc = group.new_file('PrayerWidget.xcconfig')
release_xc = group.new_file('PrayerWidgetRelease.xcconfig')
ext.add_file_references([swift])
ext.add_system_frameworks(%w[WidgetKit SwiftUI])

ext.build_configurations.each do |config|
  config.base_configuration_reference = config.name == 'Release' ? release_xc : base_xc
  s = config.build_settings
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = BUNDLE_ID
  s['INFOPLIST_FILE'] = 'PrayerWidget/Info.plist'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['CODE_SIGN_ENTITLEMENTS'] = 'PrayerWidget/PrayerWidget.entitlements'
  # Pas de CODE_SIGN_STYLE ici : il est dans PrayerWidget.xcconfig, pour que
  # le CI puisse passer en signature manuelle (un réglage de cible
  # l'emporterait sur le xcconfig).
  s.delete('CODE_SIGN_STYLE')
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['SKIP_INSTALL'] = 'YES'
  s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  s['SWIFT_OPTIMIZATION_LEVEL'] = config.name == 'Debug' ? '-Onone' : '-O'
end

# --- App (Runner) ----------------------------------------------------------
runner_group = project.main_group.children.find { |g| g.display_name == 'Runner' } or abort 'Groupe Runner introuvable'
bridge = runner_group.new_file('PrayerWidgetBridge.swift')
runner.add_file_references([bridge])
runner_group.new_file('Runner.entitlements')
runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

# WidgetKit en lien faible : l'app accepte encore iOS 13 (WidgetKit = 14+).
widgetkit = project.frameworks_group.new_file('System/Library/Frameworks/WidgetKit.framework', :sdk_root)
runner.frameworks_build_phase.add_file_reference(widgetkit, true).settings = { 'ATTRIBUTES' => ['Weak'] }

# Embarque l'extension dans l'app.
runner.add_dependency(ext)
embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.add_file_reference(ext.product_reference, true).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# [⚠️ PROD] Avant « Thin Binary » (script Flutter), sinon Xcode signale un
# cycle de dépendances (« Cycle inside Runner »).
thin = runner.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
if thin
  runner.build_phases.delete(embed)
  runner.build_phases.insert(runner.build_phases.index(thin), embed)
end

project.save
puts "#{TARGET} ajoutée (#{BUNDLE_ID})."
