# Uncomment the next line to define a global platform for your project
platform :ios, '17.0'

target 'guanzhi' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  pod 'Alamofire'
  pod 'WechatOpenSDK-XCFramework'
  # Pods for guanzhi

  # Suppress the warning about the unused master specs repo
  warn_for_unused_master_specs_repo = false
end

# 在 Pods xcconfig 中引入 Secrets.xcconfig（包含 AMAP_API_KEY 等敏感配置）
post_install do |installer|
  secrets_path = "#{Dir.pwd}/guanzhi/Config/Secrets.xcconfig"

  # 修改主 App 的 Pods xcconfig 文件
  ['Debug', 'Release'].each do |config_name|
    xcconfig_path = "#{Dir.pwd}/Pods/Target Support Files/Pods-guanzhi/Pods-guanzhi.#{config_name.downcase}.xcconfig"

    if File.exist?(xcconfig_path)
      xcconfig_content = File.read(xcconfig_path)

      # 检查是否已经引入了 Secrets.xcconfig
      unless xcconfig_content.include?("Secrets.xcconfig")
        # 在文件开头添加 #include
        new_content = "#include \"#{secrets_path}\"\n#{xcconfig_content}"
        File.write(xcconfig_path, new_content)
        puts "✅ Added Secrets.xcconfig to Pods-guanzhi.#{config_name.downcase}.xcconfig"
      end
    end
  end
end