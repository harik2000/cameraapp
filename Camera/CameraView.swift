//
//  CameraView.swift
//  Camera
//
//  Created on 1/27/23.
//

import SwiftUI
import AVKit

struct CameraView: View {
   
    // MARK: cameraModel makes use of the view model to handle the necessary camera functionality
    @StateObject var cameraModel = CameraViewModel()
    // MARK: below variables are to register both a tap for photo click as well as press for video recording
    // drag to make sure that users can stray away from the shutter button to record but the recording stops when
    // they let go of their finger on the camera view
    @GestureState var longPress = false
    @GestureState var longDrag = false
    @State private var originalImage: UIImage?
    @State private var image: UIImage?
    @State private var sheetIsPresented = false

    var body: some View {
        
        // MARK: Camera View
        ZStack {
            Color.black.ignoresSafeArea()
            
            CameraHelper()
                .environmentObject(cameraModel)
                .ignoresSafeArea()
          
            // MARK: camera controls with photo gallery button shutter button and switch camera button
            if cameraModel.camerapermission == 1 { //show the controls if successfully have permissions
                makeCameraControls()
            }
        }
        .onAppear{
            cameraModel.restartSession()
        }
        .fullScreenCover(isPresented: $cameraModel.showPreview, content: {
          if let url = cameraModel.previewURL {
            if let thumbnailData = cameraModel.thumbnailData {
                // MARK: toggle new post view and stop the camera session on appear with the user taken camera video
                // restart once it's done and reset the video url all back to initial state
                PreviewView(url: url, photoData: Data(count: 0), thumbnailData: thumbnailData)
                    .onAppear {
                        cameraModel.stopSession()
                    }
                    .onDisappear {
                        cameraModel.restartSession()
                        cameraModel.recordedDuration = 0
                        cameraModel.previewURL = nil
                        cameraModel.recordedURLs.removeAll()
                    }
            }
          }
          if let photoData = cameraModel.picData {
            if photoData.count != 0 {
                // MARK: toggle new post view and stop the camera session on appear with the user taken camera photo
                // restart once it's closed along with resetting the camera's current take
                PreviewView(url: URL(string: "http://www.example.com/image.jpg")!, photoData: photoData, thumbnailData: Data(count: 0))
                    .onAppear {
                        cameraModel.stopSession()
                    }
                    .onDisappear {
                        cameraModel.restartSession()
                        cameraModel.reTake()
                    }


            }
          }
        })
    }
    
    func makeCameraControls() -> some View {
        // MARK: Controls
        ZStack {
            
            // MARK: below handles logic for taking a picture as well as show the flash for a second
            let longPressGestureDelay = DragGesture(minimumDistance: 0)
            .updating($longDrag) { currentstate, gestureState, transaction in
                gestureState = true
            }
            .onEnded { value in
                //user has let go of finger on camera so stop recording and show the recorded video preview
                cameraModel.stopRecording()
            }

            // MARK: below handles logic for taking a picture as well as show the flash for a second
            let shortPressGesture = LongPressGesture(minimumDuration: 0)
            .onEnded { _ in
                if cameraModel.isRecording {
                    cameraModel.stopRecording()
                } else {
                    cameraModel.takePic()
                    if cameraModel.flashOn {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            cameraModel.showPreview.toggle()
                        }
                    } else {
                        cameraModel.showPreview.toggle()
                    }
                }
            }

            let longTapGesture = LongPressGesture(minimumDuration: 0.25)
              .updating($longPress) { currentstate, gestureState, transaction in
                  gestureState = true
            }
            .onEnded { _ in
                cameraModel.startRecording()
            }

            // MARK: below handles the shutter button along with the tap gesture to
            // take a photo and long press gesture to start and stop recording
            // create a big transparent rectangle to have a wider frame for shutter
            let tapBeforeLongGestures = longTapGesture.sequenced(before:longPressGestureDelay).exclusively(before: shortPressGesture)
            ZStack {
                ZStack {
                    Rectangle()
                    .frame(width: 150, height: 150)
                    .background(Color.white)
                    .opacity(0.0001)
                    .highPriorityGesture(tapBeforeLongGestures)
                    .disabled(cameraModel.showPreview)
                }
                
                ZStack {
                    Circle()
                    .fill(cameraModel.isRecording ? .red : .white)
                    .frame(width: 35, height: 35)

                    Circle()
                    .stroke(cameraModel.isRecording ? .red : .white, lineWidth: 4)

                }
                .frame(width: 70, height: 70)
            }
          

            // MARK: button to toggle between front and back camera
            Button(action: {
                if !cameraModel.isRecording {
                    cameraModel.changeCamera()
                }
            }) {
                VStack {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .foregroundColor(Color(.white))
                }
                .frame(width: 100, height: 100)
            }
            .frame(maxWidth: .infinity,alignment: .center)
            .padding(.leading, 200)
          
            // Preview Button to handle video url
            Button {
                if let _ = cameraModel.previewURL{
                    let avAsset = AVURLAsset(url: cameraModel.previewURL!, options: nil)
                    let imageGenerator = AVAssetImageGenerator(asset: avAsset)
                    imageGenerator.appliesPreferredTrackTransform = true
                    var thumbnail: UIImage?

                    do {
                        thumbnail = try UIImage(cgImage: imageGenerator.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: 1), actualTime: nil))
                        print("generated thumbnail \(String(describing: thumbnail))")
                    } catch let e as NSError {
                        print("Error: \(e.localizedDescription)")
                    }
                    //userData.resetCrewSelected()
                    cameraModel.showPreview.toggle()
                }
            } label: {
                // MARK: below group creates the preview url for an instant after the user stops recording
                Group {
                    if cameraModel.previewURL == nil && !cameraModel.recordedURLs.isEmpty{
                    // Merging Videos
                        ProgressView()
                            .tint(.black)
                    }
                    else{
                        if let _ = cameraModel.previewURL{
                            Label {
                                Image(systemName: "camera.aperture")
                                .font(.callout).foregroundColor(.white)
                            } icon: {
                                Text("")
                                .onAppear{
                                    //userData.resetCrewSelected()
                                    cameraModel.showPreview.toggle()
                                }
                            }
                            .foregroundColor(.black)
                        } else {
                            Label {
                                Image(systemName: "chevron.right")
                                .font(.callout)
                            } icon: {
                                Text("loading ... ")
                            }
                            .foregroundColor(.black)
                        }
                    }
                }
                .padding(.horizontal,20)
                .padding(.vertical,8)
            }
            .frame(maxWidth: .infinity,alignment: .trailing)
            .padding(.trailing)
            .opacity((cameraModel.previewURL == nil && cameraModel.recordedURLs.isEmpty) || cameraModel.isRecording ? 0 : 1)
        }
        .padding(.bottom, UIScreen.main.bounds.size.height > 800 ? 30 : 20)
        .frame(maxHeight: .infinity,alignment: .bottom)
    }
  
}

// MARK: Final Video Preview
extension View {
    func onTouchDownGesture(callback: @escaping () -> Void) -> some View {
        modifier(OnTouchDownGestureModifier(callback: callback))
    }
}

private struct OnTouchDownGestureModifier: ViewModifier {
    @State private var tapped = false
    let callback: () -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !self.tapped {
                        self.tapped = true
                        self.callback()
                    }
                }
                .onEnded { _ in
                    self.tapped = false
                })
    }
}







import SwiftUI
import AVFoundation

struct CameraHelper: View {

    @EnvironmentObject var cameraModel: CameraViewModel

    // MARK: lastScaleValue captures the zoom factor of camera so that gesture isn't broken
    @State var lastScaleValue: CGFloat = 1.0

     
    
    var body: some View {
        
        GeometryReader{proxy in
            let size = proxy.size
            
            // MARK: Camera Preview uses the camera model to generate the full screen camera as well as enables pinch gesture for zooming in and out
            CameraPreview(size: size)
                .environmentObject(cameraModel)
                .gesture(MagnificationGesture().onChanged { val in
                    let delta = val / self.lastScaleValue
                    self.lastScaleValue = val
                    let newScale = self.lastScaleValue * delta
                    let zoomFactor: CGFloat = min(max(newScale, 1), 5)
                    if cameraModel.camerapermission == 1 { // make sure camera permission available before gesture setting
                        cameraModel.set(zoom: zoomFactor)
                    }
                }.onEnded { val in
                    self.lastScaleValue = 1.0
                })
                //.grayscale(userData.currentUserCrews.count == 0 ? 1 : 0)
                //.blur(radius: userData.currentUserCrews.count == 0 ? 5 : 0)
                //USER EMPTY CREWS
            
            VStack(alignment: .leading) {
                VStack() {
                    Rectangle()
                        .fill(.black.opacity(0.25))
                }
                .frame(height: UIScreen.main.bounds.size.height > 800 ? 111 : 60)
            }
            
            // MARK: camera title along with search and new crew button
            // camera title toggles flash on tap
            HStack {
                Text("flash")
                    .font(.system(size: UIScreen.main.bounds.size.height > 800 ? 28 : 24))
                    .fontWeight(.medium)
                    .foregroundColor(cameraModel.flashOn ? Color(#colorLiteral(red: 1, green: 0.8571129441, blue: 0.009053478017, alpha: 1)) : .white)
                    .onTapGesture {
                        cameraModel.switchFlash()
                    }
                
                Spacer()
                
            }
            .disabled(cameraModel.camerapermission != 1)
            .padding(.leading, 20)
            .padding(.trailing, 20)
            .padding(.top, UIScreen.main.bounds.size.height > 800 ? 60 : 20)
            
            // MARK: rectangle with gradient that shows progress of video recording
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.black.opacity(0.25))

                Rectangle()
                    .fill(Color.red)
                    .frame(width: size.width * (cameraModel.recordedDuration / cameraModel.maxDuration))
            }
            .frame(height: 8)
            .padding(.top, UIScreen.main.bounds.size.height > 800 ? 111 : 60)
        }
        .onAppear(perform: cameraModel.checkPermission)
        .onReceive(Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()) { _ in
            //start the camera session to record every 0.01 seconds for video
            if cameraModel.recordedDuration <= cameraModel.maxDuration && cameraModel.isRecording{
                cameraModel.recordedDuration += 0.01
            }
            
            //went over maximum current recording duration of 15.0 seconds
            if cameraModel.recordedDuration >= cameraModel.maxDuration && cameraModel.isRecording{
                cameraModel.stopRecording()
                cameraModel.isRecording = false
            }
        }
        //toggle between front and back camera on double tap
        .onTapGesture(count: 2) {
          if !cameraModel.isRecording {
            cameraModel.changeCamera()
          }
        }
       
    }
}

struct CameraPreview: UIViewRepresentable {
    
    @EnvironmentObject var cameraModel : CameraViewModel
    var size: CGSize
    
    //starts the camera session to start running
    func makeUIView(context: Context) ->  UIView {
     
        let view = UIView()
        
        cameraModel.preview = AVCaptureVideoPreviewLayer(session: cameraModel.session)
        cameraModel.preview.frame.size = size
        
        cameraModel.preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(cameraModel.preview)
        
        cameraModel.session.startRunning()

        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
    }
}
struct StaticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}


struct PreviewView: View {
    
    @Environment(\.dismiss) var dismiss

    // MARK: below variables are for the passed in media type from user
    // url contains a url to the video that the user recorded from the camera view < 15 sec
    // photo data contains the photo image data that the user either took from camera
    // thumbnail data contains the initial frame for the thumbnail to be used for the video preview
    var url: URL
    var photoData: Data
    var thumbnailData: Data
    
    var body: some View {
        ZStack {
            Color(#colorLiteral(red: 0.9594156146, green: 0.9598115087, blue: 0.9719882607, alpha: 1)).ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        VStack {
                            Image(systemName: "xmark")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 18, height: 18)
                                .foregroundColor(Color(#colorLiteral(red: 0.6823525429, green: 0.6823533177, blue: 0.6995556951, alpha: 1)))
                            
                        }
                    }
                    .padding(.leading, 20)
                    
                    Spacer()
                    
                }
                previewMedia
                
                Spacer()
                
            }
            
            if showModal {
                
                Rectangle()
                    .foregroundColor(Color.black.opacity(0.9))
                    .edgesIgnoringSafeArea(.all)
                    .frame(width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height)
                    .onTapGesture {
                        showModal = false
                    }
                
                VStack {
                    
                    PostPreviewView(url: url, photoData: photoData)
                        .padding(.top, 20)
                }
            }
        }
    }
    //for showing the preview image
    @State var showModal = false

    var previewMedia: some View {
        
        HStack {
            
            Spacer()
            
            VStack {
              if url.absoluteString != "http://www.example.com/image.jpg" {
                if thumbnailData.count != 0 {
                  Image(uiImage: UIImage(data: thumbnailData)!)
                      .resizable()
                      .scaledToFill()
                      .frame(width: 0.25 * UIScreen.main.bounds.size.width, height: 0.25 * 0.7295 * UIScreen.main.bounds.size.height)
                      .overlay(
                        Image(systemName: "play.fill")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 20, height: 20)
                        .foregroundColor(Color(#colorLiteral(red: 0.8196074367, green: 0.8196083307, blue: 0.8411096334, alpha: 1)))
                      )
                }
            } else if photoData.count != 0 {
                  Image(uiImage: UIImage(data: photoData)!)
                      .resizable()
                      .scaledToFill()
                      .frame(width: 0.25 * UIScreen.main.bounds.size.width, height: 0.25 * 0.7295 * UIScreen.main.bounds.size.height)
                      // .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                }
            }
            .padding(.top, 10)
            .onTapGesture {
                //USER EMPTY CREWS
                showModal = true
                
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}




struct PostPreviewView: View {
  
  var url: URL
  var photoData: Data
  //@Binding var data : Video
  
  private let player = AVPlayer(url:  URL(string: "http://www.example.com/image.jpg")!)
  

  var body: some View {
        ZStack {
            GeometryReader { proxy in
                let size = proxy.size

                VStack(alignment: .center) {

                    Spacer()
                    
                    if url.absoluteString != "http://www.example.com/image.jpg" {
                        IntermediaryView(data: [Video(id: 0, player: AVPlayer(url: url), replay: false)])
                            .frame( width: size.width, height: 0.7295 * size.height)
                    }
                    else if photoData.count != 0 {
                        Image(uiImage: UIImage(data: photoData)!)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size.width, height: 0.7295 * size.height)
                            .clipped()
                    }

                    Spacer()

                }
            }
        }
  }
}

struct IntermediaryView: View {
    @State var data: [Video]
    var body: some View {
        PlayerScrollView(data: self.$data)
    }
}

struct Video : Identifiable {
    
    var id : Int
    var player : AVPlayer
    var replay : Bool
}


struct PlayerScrollView : UIViewRepresentable {
    
    
    func makeCoordinator() -> Coordinator {
        
        return PlayerScrollView.Coordinator(parent1: self)
    }
    
    @Binding var data : [Video]
    
    func makeUIView(context: Context) -> UIScrollView{
        
        let view = UIScrollView()
        
        let childView = UIHostingController(rootView: PlayerView(data: self.$data))
        
        // each children occupies one full screen so height = count * height of screen...
      //(1400/1040) * UIScreen.main.bounds.width
        
      childView.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: 0.7295 * UIScreen.main.bounds.size.height * CGFloat((data.count)) )
        
        // same here...
        
        view.contentSize = CGSize(width: UIScreen.main.bounds.size.width, height: 0.7295 * UIScreen.main.bounds.size.height * CGFloat((data.count)) )
        
        view.addSubview(childView.view)
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        
        // to ignore safe area...
        view.contentInsetAdjustmentBehavior = .never
        view.isPagingEnabled = true
        view.delegate = context.coordinator
        
        return view
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        
        // to dynamically update height based on data...
        
        uiView.contentSize = CGSize(width: UIScreen.main.bounds.size.width, height: 0.7295 * UIScreen.main.bounds.size.height * CGFloat((data.count)))
        
        for i in 0..<uiView.subviews.count{
            
            uiView.subviews[i].frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: 0.7295 * UIScreen.main.bounds.size.height * CGFloat((data.count)))
        }
    }
    
    class Coordinator : NSObject,UIScrollViewDelegate{
        
        var parent : PlayerScrollView
        var index = 0
        
        init(parent1 : PlayerScrollView) {
            
            parent = parent1
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            
            let currenrindex = Int(scrollView.contentOffset.y / UIScreen.main.bounds.height)
            
            if index != currenrindex{
                
                index = currenrindex
                
                for i in 0..<parent.data.count{
                    
                    // pausing all other videos...
                    parent.data[i].player.seek(to: .zero)
                    parent.data[i].player.pause()
                }
                
                // playing next video...
                
                parent.data[index].player.play()
                
                parent.data[index].player.actionAtItemEnd = .none
                
                NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: parent.data[index].player.currentItem, queue: .main) { (_) in
                    
                    // notification to identify at the end of the video...
                    
                    // enabling replay button....
                    self.parent.data[self.index].replay = true
                }
            }
        }
    }
}

struct PlayerView : View {
    
    @Binding var data : [Video]
    
    var body: some View{
        
        VStack(spacing: 0){
            
            ForEach(0..<self.data.count, id: \.self){ i in
                
                ZStack {
                    
                    Player(player: self.data[i].player)
                        // full screensize because were going to make paging...
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                        .offset(y: -5)
                    
                    if self.data[i].replay {
                        
                        Button(action: {
                            
                            // playing the video again...
                            
                            self.data[i].replay = false
                            self.data[i].player.seek(to: .zero)
                            self.data[i].player.play()
                            
                        }) {
                            
                            Image(systemName: "goforward")
                            .resizable()
                            .frame(width: 55, height: 60)
                            .foregroundColor(.white)
                        }
                    }
                    
                }
            }
        }
        .onAppear {
            
            // doing it for first video because scrollview didnt dragged yet...
            
            self.data[0].player.play()
            
            self.data[0].player.actionAtItemEnd = .none
            
            NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.data[0].player.currentItem, queue: .main) { (_) in
                
                // notification to identify at the end of the video...
                
                // enabling replay button....
                self.data[0].replay = true
            }
        }
    }
}

struct Player : UIViewControllerRepresentable {
    
    var player : AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        
        let view = AVPlayerViewController()
        view.player = player
        view.showsPlaybackControls = false
        view.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        
        
    }
}
