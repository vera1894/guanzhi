/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that displays controls to capture, switch cameras, and view the last captured media item.
*/

import SwiftUI
import PhotosUI
import Foundation
import Alamofire
import MapKit

/// A view that displays controls to capture, switch cameras, and view the last captured media item. 一个视图，显示用于捕获、切换相机和查看最近捕获的媒体项的控件。
struct MainToolbar<CameraModel: Camera, AppStateModel: AppState>: PlatformView {

    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State var camera: CameraModel
    @State var appState: AppStateModel
    @State private var textFieldPlaceholder: String = "发一条观之吧"
    @State private var locatedPosition : CLLocationCoordinate2D?
    @State private var locatedPositionName : String = ""
    @State private var isLocationAvailable = false
    @State private var nextPage: Bool = false //
        
    var cameraMainHeight: CGFloat = 180
    
    func getUserLocation() {
        let locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
        
        DispatchQueue.global().async {
            if CLLocationManager.locationServicesEnabled() {
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
                locationManager.startUpdatingLocation()
                
                if let location = locationManager.location?.coordinate {
                    // 使用修改后的 getAddressFromLocation 方法
                    getAddressFromLocation(for: location) { address in
                        if let address = address {
                            DispatchQueue.main.async {
                                locatedPositionName = address
                                isLocationAvailable = true
                                print("cardname:", locatedPositionName)
                            }
                        }
                    }
                    
                    // 更新位置信息
                    DispatchQueue.main.async {
                        withAnimation(Animation.spring()) {
                            locatedPosition = location
                        }
                        print("经纬度", location.latitude, location.longitude)
                    }
                }
            }
        }
    }
    
    // 根据坐标获取地址
    func getAddressFromLocation(for location: CLLocationCoordinate2D?, completion: @escaping (String?) -> Void) {
        guard let coordinate = location else {
            completion(nil)
            return
        }
        
        let converter = CoordinateConverter.shared
        var adjustedCoordinate = coordinate
        
        // 判断位置是否在中国大陆境内
        if !converter.isOutOfChina(coordinate) {
            // 在中国大陆境内，需要将 WGS-84 坐标转换为 GCJ-02 坐标
            adjustedCoordinate = converter.wgs84ToGcj02(coordinate)
        }
        
        let location = CLLocation(latitude: adjustedCoordinate.latitude, longitude: adjustedCoordinate.longitude)
        
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("定位错误：\(error.localizedDescription)")
                completion(nil)
            } else if let placemark = placemarks?.first {
                // 根据需要从 placemark 中获取地址信息
                let address = "\(placemark.name ?? "") \(placemark.locality ?? "") \(placemark.administrativeArea ?? "") \(placemark.country ?? "")"
                print("地址：", address)
                completion(address)
            } else {
                completion(nil)
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.clear // 最底层放置的收起键盘透明背景
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.endEditing()
                    print("点击底层")
                }
            
            VStack {
                HStack {
                    PhotosPreview(camera: camera, appState: appState)
                        .frame(height: 60)
    //                    .background(Color.blue)
                }
                Spacer()
                
                if appState.isReadyToPost == true { //改改改改改改改改改改改改改
                    VStack(spacing: 16) {
                        HStack {
                            Text("📍" + (isLocationAvailable ? locatedPositionName : "地点获取中..."))
                                .bold()
                            Spacer()
                        }
                        
                        RoundedRectangleTextField(placeholder: $textFieldPlaceholder, inputText: $appState.postText)
                            .frame(maxHeight: .infinity)
                        
                        HStack{
                            Button(action: {
                                        // 返回（白色）-胶囊按钮hug
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    appState.isReadyToPost = false
                                }
                                    }) {
                                        Text("🔙️ 返回")
                                    }
                                .buttonStyle(ButtonStyle_capsuleHugLeft(isEnabled: true))
                            
                                Button(action: {
                                        // 下一步（禁用）-胶囊按钮fill
                                        // 发布完成关闭页面，发布失败留在页面，发布时显示loading
                                    // 获取所有图片
                                    if isLocationAvailable == true {
                                                    // 执行下一步操作
                                        appState.isLoading = true
                                        
                                        let photos = camera.capturedMedia.compactMap { $0 as? Photo }

                                        // 上传所有 Photo 对象
                                        uploadImages(photos) { result in
                                            switch result {
                                            case .success(let imagePath):
                                                // 所有文件上传成功，调用分享发布方法
                                                shareInsert(
                                                    address: locatedPositionName,
                                                    cityCode: nil,
                                                    data: appState.postText,
                                                    deleted: nil,
                                                    districtCode: nil,
                                                    imagePath: imagePath,
                                                    latitude: locatedPosition?.latitude ?? 0.0,
                                                    longitude: locatedPosition?.longitude ?? 0.0,
                                                    provinceCode: nil,
                                                    title: "标题"
                                                )
                                                // 更新状态
                                                appState.isReadyToPost = false
                                                appState.isShowingCameraView = false
                                                appState.isShowingSearchView = true
                                                appState.isPushedGuanzhi = true
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                    appState.isLoading = false
                                                }
                                            case .failure(let error):
                                                // 上传失败，已在前面的代码中处理，无需在这里重复处理
                                                print("Failed to upload images: \(error)")
                                            }
                                        }
                                        
                                                } else {
                                                    // 显示错误消息或提醒用户等待
                                                    print("请先获取位置")
                                                }
                                    
                                    
                                    
                                        }) {
                                            Text("🔜 下一步")
                                        }
                                    .buttonStyle(ButtonStyle_capsuleFillPrimary(isEnabled: appState.postText.count != 0))
                                    .disabled(!(appState.postText.count != 0))
                                    .navigationDestination(isPresented: $nextPage) {
                                        
                                    }
                            }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    
                } else {
                    ZStack {
        //                ThumbnailButton(camera: camera)
                        Spacer()
                        
                        if camera.selectedMedia.firstIndex(of: true) != nil {
                            DeleteButton(camera: camera)
                        } else {
                            CaptureButton(camera: camera, appState: appState)
                                .disabled(camera.capturedMedia.count>3)
                                .opacity((camera.capturedMedia.count>3) ? 0.3 : 1)
            //                    .background(Color.red)  //height 68
                        }
                        
                        HStack {
                            Spacer()
                            
                            if camera.selectedMedia.firstIndex(of: true) != nil {
                            } else {
                                Button(action: {
                                            // 下一步-胶囊按钮hug
                                    appState.isReadyToPost = true
                                        }) {
                                            Text("🔜 下一步")
                                        }
                                        .buttonStyle(ButtonStyle_capsuleHugPrimary(isEnabled: (camera.capturedMedia.first != nil)))
                                    .padding(16)
                            }
                        }
        //                SwitchCameraButton(camera: camera) //修改并放置到上方
                    }
                    .padding(.bottom, 32)
                }
            }
            
            if (appState.isLoading || camera.captureboxIsLoading) {
                ProcessingView()
            }
        }
            .frame(maxHeight: appState.isReadyToPost ? .infinity : cameraMainHeight)  //改改改改改改改改改改改改改
            .frame(maxWidth: .infinity)
    //        .background(Color.gray) //
        .foregroundColor(.white)
        .onAppear {
                getUserLocation()
            }
        
//        .font(.system(size: 24))
//        .padding([.leading, .trailing])
    }
    
    // 根据设备尺寸类别确定工具栏的宽度。
    var width: CGFloat? { isRegularSize ? 250 : nil }
    // 设置工具栏的固定高度。
    var height: CGFloat? { 80 }
    
    struct UploadResponse: Codable {
        // Define the structure of the JSON response
        // based on your server's API response
        // For example, if your response is a simple JSON object like {"status": "success"},
        // you can define a corresponding struct like:
        // let status: String
        let datas: String?
        let respCode: Int
        let respMsg:String
    }
    
    /// 压缩图片用于上传：缩放到最大 2048px 边长 + JPEG 0.7 压缩
    /// 将原始相机输出（3-8MB）压缩到 300-800KB
    func compressImageForUpload(data: Data) -> Data {
        guard let image = UIImage(data: data) else {
            return data // 无法解码，返回原始数据
        }
        let maxDimension: CGFloat = 2048
        let size = image.size
        var targetSize = size

        if max(size.width, size.height) > maxDimension {
            let scale = maxDimension / max(size.width, size.height)
            targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        }

        // 缩放图片
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        let compressed = resizedImage.jpegData(compressionQuality: 0.7) ?? data
        #if DEBUG
        let originalKB = data.count / 1024
        let compressedKB = compressed.count / 1024
        print("📦 图片压缩: \(originalKB)KB → \(compressedKB)KB (缩放到 \(Int(targetSize.width))x\(Int(targetSize.height)))")
        #endif
        return compressed
    }

    func generateUniqueFileName() -> String {
        let userId = OTOLoginStatusManager.shared.getUserID()
        print("用户ID", userId)
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))  // 13位时间戳
        let randomNumber = String(format: "%05d", Int(arc4random_uniform(100000)))  // 5位随机数
        return "\(userId)_\(timestamp)_\(randomNumber)"
    }
    
    func uploadImages(_ photos: [Photo], completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(Constants.BASE_HOST)/api/guan/uploadImage") else {
            print("Invalid URL")
            return
        }

        let headers: HTTPHeaders = [
            "Content-Type": "multipart/form-data",
            "Authorization": OTOLoginStatusManager.shared.getToken()!
        ]

        let sortedPhotos = photos

        // ✅ 按照片索引预分配路径槽位，保证最终拼接顺序与拍摄顺序一致
        var photoPathGroups: [[String]] = Array(repeating: [], count: sortedPhotos.count)
        var thumbnailPath: String? = nil  // 缩略图路径单独存放
        let pathsLock = NSLock()

        // 第一个媒体文件的唯一文件名前缀，用于生成缩略图
        let firstMediaUniqueFileNamePrefix = generateUniqueFileName()

        // ✅ 基准时间戳 + 每张照片递增 1000ms，确保 parseMediaFiles 排序稳定
        let baseTimestamp = Int(Date().timeIntervalSince1970 * 1000)

        // 所有照片的全局 DispatchGroup
        let allPhotosGroup = DispatchGroup()
        var globalUploadError: Error?
        let errorLock = NSLock()

        func showErrorToUser(message: String) {
            DispatchQueue.main.async {
                appState.errorMessage = message
                appState.showErrorAlert = true
            }
        }

        let maxRetryCount = 3

        // 上传单个文件的方法（带自定义超时的 Alamofire Session）
        let uploadSessionConfig = URLSessionConfiguration.default
        uploadSessionConfig.timeoutIntervalForRequest = 120  // 上传超时 120 秒
        uploadSessionConfig.timeoutIntervalForResource = 300
        let uploadSession = Session(configuration: uploadSessionConfig)

        func uploadFile(data: Data, fileName: String, mimeType: String, photoIndex: Int? = nil, retryCount: Int = 0, completion: @escaping (Result<String, Error>) -> Void) {
            let formData = MultipartFormData()
            formData.append(data, withName: "multipartFile", fileName: fileName, mimeType: mimeType)

            #if DEBUG
            print("Starting upload for \(fileName) (\(data.count / 1024)KB)...")
            #endif

            uploadSession.upload(multipartFormData: formData, to: url, method: .post, headers: headers)
                .uploadProgress { progress in
                    DispatchQueue.main.async {
                        appState.uploadProgress = progress.fractionCompleted
                    }
                }
                .responseDecodable(of: UploadResponse.self) { response in
                    switch response.result {
                    case .success(let uploadResponse):
                        if let imagePath = uploadResponse.datas {
                            // ✅ 按照片索引写入对应槽位，保证顺序
                            pathsLock.lock()
                            if let idx = photoIndex {
                                photoPathGroups[idx].append(imagePath)
                            } else {
                                // 缩略图路径
                                thumbnailPath = imagePath
                            }
                            pathsLock.unlock()
                            print("Uploaded \(fileName): \(imagePath)")
                            completion(.success(imagePath))
                        } else {
                            let error = NSError(domain: "UploadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No image path returned in response"])
                            completion(.failure(error))
                        }
                    case .failure(let error):
                        if retryCount < maxRetryCount {
                            print("Retrying upload for \(fileName), attempt \(retryCount + 1)")
                            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                                uploadFile(data: data, fileName: fileName, mimeType: mimeType, photoIndex: photoIndex, retryCount: retryCount + 1, completion: completion)
                            }
                        } else {
                            print("Failed to upload \(fileName) after \(maxRetryCount) attempts")
                            completion(.failure(error))
                        }
                    }
                }
        }

        // ✅ 并行上传所有照片
        for (index, photo) in sortedPhotos.enumerated() {
            let uniqueFileName = (index == 0) ? firstMediaUniqueFileNamePrefix : generateUniqueFileName()
            // ✅ 递增时间戳：每张照片间隔 1000ms，确保 parseMediaFiles 排序稳定
            let suffixTimestamp = String(baseTimestamp + index * 1000)
            let isLivePhoto = photo.livePhotoMovieURL != nil

            allPhotosGroup.enter()  // 为每张照片 enter

            if isLivePhoto, let originalVideoURL = photo.livePhotoMovieURL {
                #if DEBUG
                print("🎬 MainToolbar: 并行上传 LivePhoto #\(index)")
                #endif

                let photoDispatchGroup = DispatchGroup()
                var photoUploadError: Error?

                photoDispatchGroup.enter()
                Task {
                    defer { photoDispatchGroup.leave() }

                    do {
                        let tempDir = FileManager.default.temporaryDirectory
                        let pairedImageURL = tempDir.appendingPathComponent("\(UUID().uuidString)_paired.heic")
                        let pairedVideoURL = tempDir.appendingPathComponent("\(UUID().uuidString)_paired.mov")

                        let assetId = try await LivePhotoPackager.packageLivePhoto(
                            imageData: photo.data,
                            videoURL: originalVideoURL,
                            outputImageURL: pairedImageURL,
                            outputVideoURL: pairedVideoURL
                        )

                        #if DEBUG
                        print("✅ MainToolbar: LivePhoto #\(index) 配对成功，AssetID: \(assetId)")
                        #endif

                        let pairedImageData = try Data(contentsOf: pairedImageURL)
                        let pairedVideoData = try Data(contentsOf: pairedVideoURL)

                        let compressedPairedImageData = compressImageForUpload(data: pairedImageData)
                        photoDispatchGroup.enter()
                        uploadFile(data: compressedPairedImageData, fileName: "\(uniqueFileName)_photo-\(suffixTimestamp).jpg", mimeType: "image/jpeg", photoIndex: index) { result in
                            if case .failure(let error) = result { photoUploadError = error }
                            photoDispatchGroup.leave()
                        }

                        photoDispatchGroup.enter()
                        uploadFile(data: pairedVideoData, fileName: "\(uniqueFileName)_livephoto-\(suffixTimestamp).mov", mimeType: "video/quicktime", photoIndex: index) { result in
                            if case .failure(let error) = result { photoUploadError = error }
                            photoDispatchGroup.leave()
                        }

                        try? FileManager.default.removeItem(at: pairedImageURL)
                        try? FileManager.default.removeItem(at: pairedVideoURL)

                    } catch {
                        print("❌ MainToolbar: LivePhoto #\(index) 配对失败: \(error)")
                        await MainActor.run {
                            photoDispatchGroup.enter()
                            uploadFile(data: photo.data, fileName: "\(uniqueFileName)_photo-\(suffixTimestamp).jpg", mimeType: "image/jpeg", photoIndex: index) { result in
                                if case .failure(let error) = result { photoUploadError = error }
                                photoDispatchGroup.leave()
                            }

                            do {
                                let videoData = try Data(contentsOf: originalVideoURL)
                                photoDispatchGroup.enter()
                                uploadFile(data: videoData, fileName: "\(uniqueFileName)_livephoto-\(suffixTimestamp).mov", mimeType: "video/quicktime", photoIndex: index) { result in
                                    if case .failure(let error) = result { photoUploadError = error }
                                    photoDispatchGroup.leave()
                                }
                            } catch {
                                photoUploadError = error
                            }
                        }
                    }
                }

                photoDispatchGroup.notify(queue: .main) {
                    if let error = photoUploadError {
                        errorLock.lock()
                        globalUploadError = error
                        errorLock.unlock()
                    }
                    allPhotosGroup.leave()
                }
            } else {
                // 普通照片，压缩后上传
                let compressedData = compressImageForUpload(data: photo.data)
                uploadFile(data: compressedData, fileName: "\(uniqueFileName)_photo-\(suffixTimestamp).jpg", mimeType: "image/jpeg", photoIndex: index) { result in
                    if case .failure(let error) = result {
                        errorLock.lock()
                        globalUploadError = error
                        errorLock.unlock()
                    }
                    allPhotosGroup.leave()
                }
            }
        }

        // 所有照片上传完成后 → 上传缩略图 → 回调
        allPhotosGroup.notify(queue: .main) {
            if let error = globalUploadError {
                appState.isLoading = false
                showErrorToUser(message: "上传失败：\(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            #if DEBUG
            print("✅ 所有照片并行上传完成，开始上传缩略图")
            #endif

            // 生成并上传缩略图
            guard let firstPhoto = sortedPhotos.first else {
                // ✅ 按照片索引顺序拼接路径
                let orderedPaths = photoPathGroups.flatMap { $0 }
                completion(.success(orderedPaths.joined(separator: ",")))
                return
            }

            let thumbnailImage: UIImage?
            if let livePhotoURL = firstPhoto.livePhotoMovieURL {
                let asset = AVAsset(url: livePhotoURL)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                let time = CMTime(seconds: 1, preferredTimescale: 60)
                thumbnailImage = (try? imageGenerator.copyCGImage(at: time, actualTime: nil)).map { UIImage(cgImage: $0) }
            } else {
                thumbnailImage = UIImage(data: firstPhoto.data)
            }

            guard let thumbnailData = thumbnailImage?.jpegData(compressionQuality: 0.5) else {
                let orderedPaths = photoPathGroups.flatMap { $0 }
                completion(.success(orderedPaths.joined(separator: ",")))
                return
            }

            let thumbTimestamp = String(Int(Date().timeIntervalSince1970 * 1000))
            let thumbnailFileName = "\(firstMediaUniqueFileNamePrefix)_thumbnail-\(thumbTimestamp).jpg"

            uploadFile(data: thumbnailData, fileName: thumbnailFileName, mimeType: "image/jpeg") { _ in
                // ✅ 按照片索引顺序拼接路径，缩略图路径追加在最后
                var orderedPaths = photoPathGroups.flatMap { $0 }
                if let thumb = thumbnailPath {
                    orderedPaths.append(thumb)
                }
                let combinedPaths = orderedPaths.joined(separator: ",")
                completion(.success(combinedPaths))
                #if DEBUG
                print("Combined image paths (ordered): \(combinedPaths)")
                #endif
            }
        }
    }
    
    
    func shareInsert(address: String, cityCode: Int?, data: String, deleted: Int?, districtCode: Int?, imagePath: String, latitude: Double, longitude: Double, provinceCode: Int?, title: String) {
        DispatchQueue.main.async {
            Task {
                do {
                    // 使用 try 来捕获网络请求错误
                    let responseData = try await OTONetwork.request(.insertShare(address: address, cityCode: cityCode, data: data, deleted: deleted, districtCode: districtCode, imagePath: imagePath, latitude: latitude, longitude: longitude, provinceCode: provinceCode, title: title))

                    // 使用 JSONDecoder 直接解码 Data
                    let decoder = JSONDecoder()
                    // 如果 `datas` 字段为空或不需要使用，使用 `EmptyData`
                    let response = try decoder.decode(OTOResponseModel<EmptyData>.self, from: responseData)
                    // 如果 `datas` 字段为其他类型，替换 `EmptyData` 为实际的模型类型

                    if response.respCode == 0 {
                        print("发布观之成功: \(imagePath)")
                    } else {
                        print("Failed to publish: \(String(describing: response.respMsg))")
                    }
                } catch {
                    // 捕获网络请求或其他错误
                    print("Error sending request: \(error)")
                }
            }
        }
    }
    
    
    func requestForImage(_ image: UIImage, completion: @escaping (Result<Data, Error>) -> Void) {
        
        do {
            // 创建要上传的图片数据
            guard let imageData = image.jpegData(compressionQuality: 0.5) else {  completion(.failure(NSError(domain: "com.example.app", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])))
                return}
            print("imagedata::",imageData)
            
            
            // 创建 URLComponents 并设置 URL
            if let url = URL(string: "\(Constants.BASE_HOST)/api/guan/uploadImage") {
                
                
                //body信息
                let boundary = UUID().uuidString
                var body = Data()
                
                body.appendString("--\(boundary)\r\n")
                body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n")
                body.appendString("Content-Type:image/jpeg\r\n\r\n")
                body.append(imageData)
                body.appendString("\r\n--\(boundary)--\r\n")
                
                // 创建 URLRequest
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                request.setValue(OTOLoginStatusManager.shared.getToken(), forHTTPHeaderField: "Authorization")
                request.httpBody = body
                
                let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        let statusCode = httpResponse.statusCode
                        print(statusCode)
                        // 处理状态码和其他响应信息
                        // ...
                    }
                    
                    if let data = data{
                        do {
                                let json = try JSONSerialization.jsonObject(with: data, options: [])
                                // 在这里处理解析后的 JSON 数据
                                print(json)
                            } catch {
                                print("Error parsing JSON: \(error)")
                            }
                    }
                }
                    task.resume()
            }
        }
    }
    
}

#if DEBUG
#Preview {
    Group {
        MainToolbar(camera: PreviewCameraModel(), appState: AppStateModel())
            .background(Color.blue)
    }
}
#endif
