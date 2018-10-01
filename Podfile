# Uncomment this line to define a global platform for your project
# platform :ios, '9.1'

target 'QuickChat' do
  # Comment this line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for QuickChat
pod 'Firebase/Database'
pod 'Firebase/Auth'
pod 'Firebase/Storage'
pod 'Firebase/Messaging'
pod 'Eureka', '~> 4.1.0'
pod 'ReachabilitySwift'
pod 'ViewRow', :git => 'https://github.com/EurekaCommunity/ViewRow'
pod 'Disk'
pod 'Cluster'
pod 'Parchment'
pod 'Alamofire'
pod 'NVActivityIndicatorView'
pod 'GeoFire'

post_install do |installer|
    # Your list of targets here.
    myTargets = ['Eureka']
    
    installer.pods_project.targets.each do |target|
        if myTargets.include? target.name
            target.build_configurations.each do |config|
                config.build_settings['SWIFT_VERSION'] = '4.0'
            end
        end
    end
end

end
