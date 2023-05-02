//
//  ViewController.swift
//  RecordReport
//
//  Created by Howard-Zjun on 2023/5/1.
//

import UIKit
import ReplayKit

class ViewController: UIViewController {

    var notes: [String] = []
    
    var assetWriter: AVAssetWriter?
    
    var videoInput: AVAssetWriterInput?
    
    var audioInput: AVAssetWriterInput?
    
    var captureDirectionPath: String {
        let ret = documentPath.appending("/capture")
        if !FileManager.default.fileExists(atPath: ret) {
            try? FileManager.default.createDirectory(atPath: ret, withIntermediateDirectories: true)
        }
        return ret
    }
    
    var assetPath: String {
        captureDirectionPath.appending("/test1.mp4")
    }
    
    lazy var writeQueue: DispatchQueue = {
       DispatchQueue(label: "output-queue")
    }()
    
    // MARK: - view
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .init(x: 0, y: 0, width: view.width, height: 200))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: NSStringFromClass(UITableViewCell.self))
        tableView.delegate = self
        tableView.dataSource = self
        return tableView
    }()
    
    lazy var controlRecordBtn: UIButton = {
        let controlRecordBtn = UIButton(frame: .init(x: (view.width - 100) * 0.5, y: 150, width: 100, height: 50))
        controlRecordBtn.backgroundColor = .init(hexValue: 0xC1C9D9)
        controlRecordBtn.layer.cornerRadius = controlRecordBtn.height * 0.5
        controlRecordBtn.layer.borderWidth = 1
        controlRecordBtn.layer.borderColor = UIColor(hexValue: 0x52555C).cgColor
        controlRecordBtn.titleLabel?.font = .systemFont(ofSize: 15)
        controlRecordBtn.titleLabel?.adjustsFontSizeToFitWidth = true
        controlRecordBtn.setTitle("软件内录屏", for: .normal)
        controlRecordBtn.setTitle("结束录屏", for: .selected)
        controlRecordBtn.setTitleColor(.init(hexValue: 0x46AA5F), for: .normal)
        controlRecordBtn.addTarget(self, action: #selector(touchControlRecordBtn), for: .touchUpInside)
        return controlRecordBtn
    }()
    
    lazy var captureBtn: UIButton = {
        let captureBtn = UIButton(frame: .init(x: (view.width - 100) * 0.5, y: controlRecordBtn.maxY + 30, width: 100, height: 50))
        captureBtn.backgroundColor = .init(hexValue: 0xC1C9D9)
        captureBtn.layer.cornerRadius = controlRecordBtn.height * 0.5
        captureBtn.layer.borderWidth = 1
        captureBtn.layer.borderColor = UIColor(hexValue: 0x52555C).cgColor
        captureBtn.titleLabel?.font = .systemFont(ofSize: 15)
        captureBtn.titleLabel?.adjustsFontSizeToFitWidth = true
        captureBtn.setTitle("软件内直播", for: .normal)
        captureBtn.setTitle("结束直播", for: .selected)
        captureBtn.setTitleColor(.init(hexValue: 0x46AA5F), for: .normal)
        captureBtn.addTarget(self, action: #selector(touchCaptureBtn), for: .touchUpInside)
        return captureBtn
    }()
    
    lazy var clearNote: UIButton = {
        let clearNote = UIButton(frame: .init(x: (view.width - 100) * 0.5, y: captureBtn.maxY + 30, width: 100, height: 50))
        clearNote.backgroundColor = .init(hexValue: 0xC1C9D9)
        clearNote.layer.cornerRadius = clearNote.height * 0.5
        clearNote.layer.borderWidth = 1
        clearNote.layer.borderColor = UIColor(hexValue: 0x52555C).cgColor
        clearNote.titleLabel?.font = .systemFont(ofSize: 15)
        clearNote.titleLabel?.adjustsFontSizeToFitWidth = true
        clearNote.setTitle("软件内直播", for: .normal)
        clearNote.setTitle("结束直播", for: .selected)
        clearNote.setTitleColor(.init(hexValue: 0x46AA5F), for: .normal)
        clearNote.addTarget(self, action: #selector(touchClearBtn), for: .touchUpInside)
        return clearNote
    }()
    
    lazy var panView: UIView = {
        let panView = UIView(frame: .init(x: 0, y: 0, width: 100, height: 100))
        panView.backgroundColor = .red
        panView.addGestureRecognizer({
            UIPanGestureRecognizer(target: self, action: #selector(panGesture(_:)))
        }())
        return panView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        RPScreenRecorder.shared().delegate = self
        configUI()
    }

    // MARK: - config
    func configUI() {
        view.backgroundColor = .white
        view.addSubview(tableView)
        view.addSubview(panView)
        view.addSubview(controlRecordBtn)
        view.addSubview(captureBtn)
        view.addSubview(clearNote)
    }
    
    // MARK: - target
    @objc func touchControlRecordBtn() {
        weak var weakSelf = self
        controlRecordBtn.isSelected = !controlRecordBtn.isSelected
        if controlRecordBtn.isSelected {
            noteNewStatus(text: "开始录屏")
            RPScreenRecorder.shared().isMicrophoneEnabled = true
            RPScreenRecorder.shared().startRecording { error in
                if let error = error {
                    weakSelf?.noteNewStatus(text: "错误: \(error)")
                }
            }
        } else {
            noteNewStatus(text: "结束录屏")
            RPScreenRecorder.shared().isMicrophoneEnabled = false
            if !RPScreenRecorder.shared().isRecording {
                return
            }
            RPScreenRecorder.shared().stopRecording { pvc, error in
                if let error = error {
                    weakSelf?.noteNewStatus(text: "错误: \(error)")
                    return
                }
                if let pvc = pvc {
                    pvc.previewControllerDelegate = self
                    weakSelf?.present(pvc, animated: true)
                }
            }
        }
    }
    
    @objc func touchCaptureBtn() {
        weak var weakSelf = self
        captureBtn.isSelected = !captureBtn.isSelected
        if captureBtn.isSelected {
            noteNewStatus(text: "开始直播")
            RPScreenRecorder.shared().isMicrophoneEnabled = true
            RPScreenRecorder.shared().startCapture { buffer, type, error in
                if let error = error {
                    weakSelf?.noteNewStatus(text: "\(error)")
                    return
                }
                weakSelf?.writeQueue.sync {
                    if weakSelf?.assetWriter == nil {
                        weakSelf?.prepareWriter(buffer: buffer)
                    }
                    if weakSelf?.assetWriter?.status == .unknown {
                        let startTime = CMSampleBufferGetPresentationTimeStamp(buffer)
                        weakSelf?.assetWriter?.startWriting()
                        weakSelf?.assetWriter?.startSession(atSourceTime: startTime)
                    } else if weakSelf?.assetWriter?.status == .failed {
                        weakSelf?.noteNewStatus(text: "直播写入失效")
                        return
                    }
                    
                    if CMSampleBufferDataIsReady(buffer) == true {
                        if type == .audioMic {
                            if let audioInput = weakSelf?.audioInput, audioInput.isReadyForMoreMediaData {
                                audioInput.append(buffer)
                            }
                        } else if type == .video {
                            if let videoInput = weakSelf?.videoInput, videoInput.isReadyForMoreMediaData {
                                videoInput.append(buffer)
                            }
                        }
                    }
                }
            } completionHandler: { error in
                if let error = error {
                    weakSelf?.noteNewStatus(text: "\(error)")
                    return
                }
            }
        } else {
            noteNewStatus(text: "结束直播")
            RPScreenRecorder.shared().isMicrophoneEnabled = false
            if !RPScreenRecorder.shared().isRecording {
                return
            }
            RPScreenRecorder.shared().stopCapture { error in
                if let error = error {
                    weakSelf?.noteNewStatus(text: "\(error)")
                    return
                }
                weakSelf?.writeQueue.sync {
                    weakSelf?.assetWriter?.finishWriting {
                        if let assetPath = weakSelf?.assetPath {
                            UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(assetPath)
                        }
                    }
                }
            }
        }
    }
    
    @objc func touchClearBtn() {
        notes.removeAll(keepingCapacity: false)
        tableView.reloadData()
    }
    
    @objc func panGesture(_ sender: UIPanGestureRecognizer) {
        let location = sender.location(in: view)
        if sender.state == .began {
            
        } else if sender.state == .changed {
            panView.center = location
        } else {
            
        }
    }
}

extension ViewController {

    func noteNewStatus(text: String) {
        DispatchQueue.main.async {
            self.notes.append(text)
            self.tableView.insertRows(at: [.init(row: self.notes.count - 1, section: 0)], with: .bottom)
        }
    }
    
    func prepareWriter(buffer: CMSampleBuffer) {
        if FileManager.default.fileExists(atPath: assetPath) {
            try? FileManager.default.removeItem(atPath: assetPath)
        }
        assetWriter = try? AVAssetWriter(outputURL: assetPath.fileUrl, fileType: .mov)
        
        let writerOutputSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: UIScreen.main.bounds.width,
            AVVideoHeightKey: UIScreen.main.bounds.height,
        ] as [String : Any]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerOutputSettings)
        videoInput.expectsMediaDataInRealTime = true
        
        if assetWriter?.canAdd(videoInput) ?? false {
            assetWriter?.add(videoInput)
        }
        self.videoInput = videoInput
        
        if let format = CMSampleBufferGetFormatDescription(buffer), let stream = CMAudioFormatDescriptionGetStreamBasicDescription(format) {
            let audioOutputSettings = [
                AVFormatIDKey : kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey : stream.pointee.mChannelsPerFrame,
                AVSampleRateKey : stream.pointee.mSampleRate,
                AVEncoderBitRateKey : 64000
            ] as [String : Any]
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
            audioInput.expectsMediaDataInRealTime = true
            
            if assetWriter?.canAdd(audioInput) ?? false {
                assetWriter?.add(audioInput)
            }
            self.audioInput = audioInput
        }
    }
}

// MARK: - RPScreenRecorderDelegate
extension ViewController: RPScreenRecorderDelegate {
 
    func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWith previewViewController: RPPreviewViewController?, error: Error?) {
        if let pvc = previewViewController {
            present(pvc, animated: true)
        }
        if let error = error {
            noteNewStatus(text: "异常终止:\(error)")
        }
    }
    
    func screenRecorderDidChangeAvailability(_ screenRecorder: RPScreenRecorder) {
        noteNewStatus(text: "外部录屏可行性变更:\(screenRecorder.isAvailable)")
    }
}

// MARK: - RPPreviewViewControllerDelegate
extension ViewController: RPPreviewViewControllerDelegate {
    
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        noteNewStatus(text: "结束预览")
    }
    
    func previewController(_ previewController: RPPreviewViewController, didFinishWithActivityTypes activityTypes: Set<String>) {
        noteNewStatus(text: "\(activityTypes.joined(separator: "-"))")
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension ViewController: UITableViewDelegate, UITableViewDataSource {
 
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        notes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: NSStringFromClass(UITableViewCell.self), for: indexPath)
        cell.textLabel?.text = notes[indexPath.item]
        cell.textLabel?.textColor = .black
        return cell
    }
}
