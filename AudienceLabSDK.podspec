Pod::Spec.new do |s|
  s.name             = "AudienceLabSDK"
  s.version          = "1.1.11"
  s.summary          = "Native iOS SDK for AudienceLab by Geeklab."
  s.description      = <<-DESC
AudienceLabSDK is a native iOS analytics and attribution SDK that supports
runtime initialization, event tracking, retention metrics, creative token
management, offline queue replay, and user property enrichment.
                       DESC
  s.homepage         = "https://github.com/Geeklab-Ltd/audiencelab_ios_sdk"
  s.license          = { :type => "GEEKLAB SDK EULA" }
  s.author           = { "Geeklab Team" => "support@geeklab.app" }
  s.source           = { :git => "https://github.com/Geeklab-Ltd/audiencelab_ios_sdk.git", :tag => "v#{s.version}" }
  s.platform         = :ios, "14.0"
  s.swift_version    = "5.9"
  s.static_framework = true

  s.source_files = "Sources/AudienceLabSDK/**/*.swift"
  s.frameworks = "Foundation", "UIKit", "Network", "Metal"
end
