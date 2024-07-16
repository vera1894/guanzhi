//
//  CameraView.swift
//  guanzhi
//
//  Created by Vera on 2024/1/27.
//

import SwiftUI

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
                UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<CameraView>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        // 设置拍照界面为全屏
       // picker.modalPresentationStyle = .fullScreen
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<CameraView>) {
    }
}

struct ContentView: View {
    @State private var image: UIImage?
    @State private var isShowingImagePicker = false
    
    var body: some View {
        VStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("No Image")
            }
            
            Button("Take Photo") {
                isShowingImagePicker = true
            }
        }
        .padding()
        .sheet(isPresented: $isShowingImagePicker) {
            CameraView(image: $image)
        }
    }
}




#Preview {
    ContentView()
}
