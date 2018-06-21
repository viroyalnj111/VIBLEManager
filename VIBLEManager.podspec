#
# Be sure to run `pod lib lint VIBLEManager.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'VIBLEManager'
  s.version          = '0.1'
  s.summary          = '远御语音助手蓝牙指令封装'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
包含蓝牙设备的配对、指令下发
                       DESC

  s.homepage         = 'https://github.com/guofengld/VIBLEManager'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'guofengld' => 'guofengld@gmail.com' }
  s.source           = { :git => 'https://github.com/guofengld/VIBLEManager.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'

  s.source_files = 'VIBLEManager/*'

  s.frameworks = 'CoreBluetooth'

end
