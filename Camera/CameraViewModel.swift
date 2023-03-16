//
//  CameraViewModel.swift
//  Camera
//
//  Created on 1/27/23.
//

import SwiftUI
import AVFoundation

// MARK: Camera View Model
class CameraViewModel: NSObject,ObservableObject,AVCaptureFileOutputRecordingDelegate, AVCapturePhotoCaptureDelegate{
    
    @Published var session = AVCaptureSession()
    @Published var alert = false
    @Published var output = AVCaptureMovieFileOutput()
    @Published var preview : AVCaptureVideoPreviewLayer!
    
    // MARK: Video Recorder Properties
    @Published var isRecording: Bool = false
    @Published var recordedURLs: [URL] = []
    @Published var previewURL: URL?
    @Published var showPreview: Bool = false
    
    // Top Progress Bar
    @Published var recordedDuration: CGFloat = 0
    // Maximum 15 seconds
    @Published var maxDuration: CGFloat = 15
    
    //for photo
    // since were going to read pic data....
    @Published var photoOutput = AVCapturePhotoOutput()
    @Published var isTaken = false
    @Published var picData = Data(count: 0)
    @Published var thumbnailData = Data(count: 0)

    @Published var flashOn = false
  
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    private let sessionQueue = DispatchQueue(label: "session queue")
    // MARK: Device Configuration Properties
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified)
  
    @AppStorage("camerapermission") var camerapermission = 0

    func checkPermission(){
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
          self.checkAudioPermission()
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { (status) in
                
                if status{
                  self.checkAudioPermission()
                }
            }
        case .denied:
            self.camerapermission = 2
            self.alert.toggle()
            return
        default:
            return
        }
    }
  
    func checkAudioPermission() {
      switch AVAudioSession.sharedInstance().recordPermission {
        case .granted :
            print("permission granted")
            self.camerapermission = 1
            setUp()
        case .denied:
            print("permission denied")
            self.camerapermission = 2
            self.alert.toggle()
        case .undetermined:
            print("request permission here")
            AVAudioSession.sharedInstance().requestRecordPermission({ granted in
              if granted {
                print("permission granted here")
                DispatchQueue.main.async {
                  self.camerapermission = 1
                }
                self.setUp()
              }
            })
      default:
          print("unknown")
        

      }
      
    }
    
    func setUp(){
        
        do{
            self.session.beginConfiguration()
          
            let cameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            
          if cameraDevice != nil {
            
            
              let videoInput = try AVCaptureDeviceInput(device: cameraDevice!)
//              let audioDevice = AVCaptureDevice.default(for: .audio)
//              let audioInput = try AVCaptureDeviceInput(device: audioDevice!)
//              if self.session.canAddInput(videoInput) && self.session.canAddInput(audioInput){ //MARK: Audio Input
//                  self.session.addInput(videoInput)
//                  self.session.addInput(audioInput)
//                  self.videoDeviceInput = videoInput
//              }
//
              /* mixing code buggy  */
              if self.session.canAddInput(videoInput) {
                  self.session.addInput(videoInput)
                  self.videoDeviceInput = videoInput
              }
              
              
              if self.session.canAddOutput(self.output){
                  self.session.addOutput(self.output)
              }
              if self.session.canAddOutput(self.photoOutput){
                  self.session.addOutput(self.photoOutput)
              }
              //for audio mixing, make sure this is default set to true
              self.session.automaticallyConfiguresApplicationAudioSession = true
              self.session.commitConfiguration()
          }

        }
        catch{
            print(error.localizedDescription)
        }
    }
    public func set(zoom: CGFloat){
        let factor = zoom < 1 ? 1 : zoom
        let device = self.videoDeviceInput.device
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = factor
            device.unlockForConfiguration()
        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    
    func changeCamera() {
      sessionQueue.async {
          if self.videoDeviceInput != nil {
            let currentVideoDevice = self.videoDeviceInput.device
            let currentPosition = currentVideoDevice.position
            
            let preferredPosition: AVCaptureDevice.Position
            let preferredDeviceType: AVCaptureDevice.DeviceType
            
            switch currentPosition {
            case .unspecified, .front:
                preferredPosition = .back
                preferredDeviceType = .builtInWideAngleCamera
                
            case .back:
                preferredPosition = .front
                preferredDeviceType = .builtInWideAngleCamera
                
            @unknown default:
                print("Unknown capture position. Defaulting to back, dual-camera.")
                preferredPosition = .back
                preferredDeviceType = .builtInWideAngleCamera
            }
            let devices = self.videoDeviceDiscoverySession.devices
            var newVideoDevice: AVCaptureDevice? = nil
            
            // First, seek a device with both the preferred position and device type. Otherwise, seek a device with only the preferred position.
            if let device = devices.first(where: { $0.position == preferredPosition && $0.deviceType == preferredDeviceType }) {
                newVideoDevice = device
            } else if let device = devices.first(where: { $0.position == preferredPosition }) {
                newVideoDevice = device
            }
            if let videoDevice = newVideoDevice {
                do {
                  let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                  self.session.beginConfiguration()
                  
                  // Remove the existing device input first, because AVCaptureSession doesn't support
                  // simultaneous use of the rear and front cameras.
                  self.session.removeInput(self.videoDeviceInput)
                  
                  // MARK: Audio Input
                  
                  if self.session.canAddInput(videoDeviceInput){
                      self.session.addInput(videoDeviceInput)
                    self.videoDeviceInput = videoDeviceInput
                    
                  }

                  if self.session.canAddOutput(self.output){
                      self.session.addOutput(self.output)
                  }
                  if self.session.canAddOutput(self.photoOutput){
                      self.session.addOutput(self.photoOutput)
                  }
                  self.session.commitConfiguration()
                } catch {
                  print("Error occurred while creating video device input: \(error)")
                }
            }

          }
      }

    }
 
    
  // take and retake functions...
  func switchFlash() {
    self.flashOn.toggle()
  }
    
    func takePic(){
      let settings = AVCapturePhotoSettings()
      if flashOn {
        settings.flashMode = .on

      } else {
        settings.flashMode = .off

      }
      //Need to correct image orientation before moving further
      if let photoOutputConnection = photoOutput.connection(with: .video) {
          //For frontCamera settings to capture mirror image
        if self.videoDeviceInput.device.position == .front {
              photoOutputConnection.automaticallyAdjustsVideoMirroring = false
              photoOutputConnection.isVideoMirrored = true
          } else {
              photoOutputConnection.automaticallyAdjustsVideoMirroring = true
          }
          
      }
      
      self.photoOutput.capturePhoto(with: settings, delegate: self)
      print("retaking a photo taken...")

        DispatchQueue.global(qos: .background).async {
            
            //self.session.stopRunning()
            
            DispatchQueue.main.async {
                
                withAnimation{self.isTaken.toggle()}
            }
        }
    }
  
    func reTake(){

        DispatchQueue.global(qos: .background).async {
            
            self.session.startRunning()
            
            DispatchQueue.main.async {
                withAnimation{self.isTaken.toggle()}
                //clearing ...
                self.flashOn = false

                self.picData = Data(count: 0)
            }
        }
    }
  
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        if error != nil{
            return
        }
        
        print("pic taken...")
        
        guard let imageData = photo.fileDataRepresentation() else{return}
        
        self.picData = imageData
    }
    
    func startRecording() {
        /* mixing code buggy */
        do
        {
            try AVAudioSession.sharedInstance().setActive(false)
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.ambient)
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: AVAudioSession.CategoryOptions.mixWithOthers)
            try AVAudioSession.sharedInstance().setMode(AVAudioSession.Mode.videoRecording)
            try AVAudioSession.sharedInstance().setActive(true)

            let audioDevice = AVCaptureDevice.default(for: .audio)
            let audioInput = try AVCaptureDeviceInput(device: audioDevice!)
            if self.session.canAddInput(audioInput){
                self.session.automaticallyConfiguresApplicationAudioSession = false
                self.session.addInput(audioInput)
            }

        } catch {
            print("Can't Set Audio Session Category: \(error)")
        }
         
        
        // MARK: Temporary URL for recording Video
        let tempURL = NSTemporaryDirectory() + "\(Date()).mov"
        //Need to correct image orientation before moving further
        if let videoOutputConnection = output.connection(with: .video) {

            //For frontCamera settings to capture mirror image
          if self.videoDeviceInput.device.position == .front {

              videoOutputConnection.automaticallyAdjustsVideoMirroring = false
              videoOutputConnection.isVideoMirrored = true
            } else {
              videoOutputConnection.automaticallyAdjustsVideoMirroring = true
            }
            
        }
        output.startRecording(to: URL(fileURLWithPath: tempURL), recordingDelegate: self)
        isRecording = true
    }
    
    func stopRecording(){
        output.stopRecording()
        isRecording = false
        self.flashOn = false
        
        /* mixing code buggy */

        do{
            try AVAudioSession.sharedInstance().setActive(false)
            let audioDevice = AVCaptureDevice.default(for: .audio)
            let audioInput = try AVCaptureDeviceInput(device: audioDevice!)
            self.session.removeInput(audioInput)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])

            try AVAudioSession.sharedInstance().setActive(true)

        } catch {
            print("Error occurred while removing audio device input: \(error)")
        }
         
    }
  
  func generateThumbnail() {
    let image = self.imageFromVideo(url: previewURL!, at: 0)

       DispatchQueue.main.async {
         self.thumbnailData = image?.pngData() ?? Data(count: 0)
       }
  }
    
  func imageFromVideo(url: URL, at time: TimeInterval) -> UIImage? {
      let asset = AVURLAsset(url: url)

      let assetIG = AVAssetImageGenerator(asset: asset)
      assetIG.appliesPreferredTrackTransform = true
    assetIG.apertureMode = AVAssetImageGenerator.ApertureMode.encodedPixels

      let cmTime = CMTime(seconds: time, preferredTimescale: 60)
      let thumbnailImageRef: CGImage
      do {
          thumbnailImageRef = try assetIG.copyCGImage(at: cmTime, actualTime: nil)
        print("SUCESS: THUMBNAIL")
      } catch let error {
          print("Error: \(error)")
          return nil
      }

      return UIImage(cgImage: thumbnailImageRef)
  }
  
    func restartSession() {
      if !self.session.isRunning {
        DispatchQueue.global(qos: .background).async {
          self.session.startRunning()
        }
      }
      
    }
    
    func stopSession() {
     // DispatchQueue.global(qos: .background).async {
          self.session.stopRunning()
     // }
    }
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            return
        }
        
        // CREATED SUCCESSFULLY
        print(outputFileURL)
      guard let data = try? Data(contentsOf: outputFileURL) else {
          return
      }

      print("File size before compression: \(Double(data.count / 1048576)) mb")
        self.recordedURLs.append(outputFileURL)
        if self.recordedURLs.count == 1{
          
            self.previewURL = outputFileURL
          
            self.generateThumbnail()
            return
        }
        
        
        /*
         Below code can be ignored because only recording one url
         */
        
        
        // CONVERTING URLs TO ASSETS
        let assets = recordedURLs.compactMap { url -> AVURLAsset in
            return AVURLAsset(url: url)
        }
        
        self.previewURL = nil
        // MERGING VIDEOS
        mergeVideos(assets: assets) { exporter in
            exporter.exportAsynchronously {
                if exporter.status == .failed{
                    // HANDLE ERROR
                    print(exporter.error!)
                }
                else{
                    if let finalURL = exporter.outputURL{
                        print(finalURL)
                        DispatchQueue.main.async {
                            self.previewURL = finalURL
                          print("inside final url")
                        }
                    }
                }
            }
        }
    }
    
    func mergeVideos(assets: [AVURLAsset],completion: @escaping (_ exporter: AVAssetExportSession)->()){
        
        let compostion = AVMutableComposition()
        var lastTime: CMTime = .zero
        
        guard let videoTrack = compostion.addMutableTrack(withMediaType: .video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else{return}
        guard let audioTrack = compostion.addMutableTrack(withMediaType: .audio, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else{return}
        
        for asset in assets {
            // Linking Audio and Video
            do{
                try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: asset.tracks(withMediaType: .video)[0], at: lastTime)
                // Safe Check if Video has Audio
                if !asset.tracks(withMediaType: .audio).isEmpty{
                    try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: asset.tracks(withMediaType: .audio)[0], at: lastTime)
                }
            }
            catch{
                // HANDLE ERROR
                print(error.localizedDescription)
            }
            
            // Updating Last Time
            lastTime = CMTimeAdd(lastTime, asset.duration)
        }
        
        // MARK: Temp Output URL
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory() + "Reel-\(Date()).mp4")
        
        // VIDEO IS ROTATED
        // BRINGING BACK TO ORIGNINAL TRANSFORM
        
        let layerInstructions = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        
        // MARK: Transform
        var transform = CGAffineTransform.identity
        transform = transform.rotated(by: 90 * (.pi / 180))
        transform = transform.translatedBy(x: 0, y: -videoTrack.naturalSize.height)
        layerInstructions.setTransform(transform, at: .zero)

        let instructions = AVMutableVideoCompositionInstruction()
        instructions.timeRange = CMTimeRange(start: .zero, duration: lastTime)
        instructions.layerInstructions = [layerInstructions]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = CGSize(width: videoTrack.naturalSize.height, height: videoTrack.naturalSize.width)
        videoComposition.instructions = [instructions]
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        
        guard let exporter = AVAssetExportSession(asset: compostion, presetName: AVAssetExportPresetHighestQuality) else{return}
        exporter.outputFileType = .mp4
        exporter.outputURL = tempURL
        exporter.videoComposition = videoComposition
        completion(exporter)
    }



  func compressVideo(inputURL: URL,
                     outputURL: URL,
                     handler:@escaping (_ exportSession: AVAssetExportSession?) -> Void) {
      let urlAsset = AVURLAsset(url: inputURL, options: nil)
      guard let exportSession = AVAssetExportSession(asset: urlAsset,
                                                     presetName: AVAssetExportPresetMediumQuality) else {
          handler(nil)

          return
      }

      exportSession.outputURL = outputURL
      exportSession.outputFileType = .mp4
      exportSession.exportAsynchronously {
          handler(exportSession)
      }
  }
}
