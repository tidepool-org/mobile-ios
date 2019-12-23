source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '11.0'

use_frameworks!

def available_pods
  pod 'TPHealthKitUploader', :git => 'https://github.com/tidepool-org/healthkit-uploader', :tag => '0.9.5'
  pod 'Alamofire', '4.7.3'
  pod 'SwiftyJSON', '4.2'
  pod 'CocoaLumberjack/Swift', '~> 3.4.2'
  pod 'twitter-text', '~> 2.0.5'
  pod 'FLAnimatedImage', '~> 1.0.12'
end

target 'TidepoolMobile' do
  available_pods
end

target 'TidepoolMobileTests' do
  available_pods
end

target 'BGMTool' do
  pod 'TPHealthKitUploader', :git => 'https://github.com/tidepool-org/healthkit-uploader', :tag => '0.9.5'
  pod 'Alamofire', '4.7.3'
  pod 'SwiftyJSON', '4.2'
  pod 'CocoaLumberjack/Swift', '~> 3.4.2'
end
