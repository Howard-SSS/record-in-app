//
//  BufferWriterTool.swift
//  RecordReport
//
//  Created by Howard-Zjun on 2023/5/3.
//

import UIKit
import ReplayKit

class BufferWriterTool: NSObject {

    var isReady: Bool {
        handleFilePath != nil
    }
    
    var savePath: String {
        let ret = documentPath.appending("/video")
        if !FileManager.default.fileExists(atPath: ret) {
            try? FileManager.default.createDirectory(atPath: ret, withIntermediateDirectories: true)
        }
        return ret
    }
    
    var saveFileName: String {
        var max = 0
        for fileName in FileManager.default.subpaths(atPath: savePath) ?? [] {
            if fileName.hasPrefix("capture"), let num = Int(fileName.suffix(fileName.count - "capture".count)) {
                max = num > max ? num : max
            }
        }
        return "capture\(max + 1).mp4"
    }
    
    var handleFilePath: String?
    
    var assetWriter: AVAssetWriter?
    
    var videoInput: AVAssetWriterInput?
    
    var audioInput: AVAssetWriterInput?
    
    private func prepareWrite(buffer: CMSampleBuffer) {
        if !isReady {
            do {
                let handleFilePath = savePath + "/" + saveFileName
                assetWriter = try AVAssetWriter(outputURL: handleFilePath.fileUrl, fileType: .mov)
                self.handleFilePath = handleFilePath
            } catch {
                return
            }
        }
        
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
    
    func keepWrite(buffer: CMSampleBuffer, type: RPSampleBufferType) {
        if assetWriter == nil {
            prepareWrite(buffer: buffer)
            if assetWriter == nil {
                return
            }
        }
        if assetWriter?.status == .unknown {
            let startTime = CMSampleBufferGetPresentationTimeStamp(buffer)
            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: startTime)
        } else if assetWriter?.status == .failed {
            
        }
        if CMSampleBufferDataIsReady(buffer) == true {
            if type == .audioMic {
                if let audioInput = audioInput, audioInput.isReadyForMoreMediaData {
                    audioInput.append(buffer)
                }
            } else if type == .video {
                if let videoInput = videoInput, videoInput.isReadyForMoreMediaData {
                    videoInput.append(buffer)
                }
            }
        }
    }
    
    func finishWrite() {
        weak var weakSelf = self
        assetWriter?.finishWriting(completionHandler: {
            guard let handleFilePath = weakSelf?.handleFilePath else {
                return
            }
            UISaveVideoAtPathToSavedPhotosAlbum(handleFilePath, nil, nil, nil)
            weakSelf?.handleFilePath = nil
        })
    }
}
