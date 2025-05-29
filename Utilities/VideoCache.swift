//
//  VideoCache.swift
//  LiNGUiD
//
//  Created by Jackson Sanders on 5/27/25.
//

import Foundation
import SwiftUI
import AVFoundation

final class VideoCache {
    static let shared = VideoCache() //singleton
   
    private init() {}
    
    private var cache = NSCache<NSURL, AVPlayer>() //cache that uses urls as keys and stores video players
    
    func player(for url: URL) -> AVPlayer? { //video url is passed in
        cache.object(forKey: url as NSURL) //will return a player if it exists, nil if not
    }
        
    func setPlayer(_ player: AVPlayer, for url: URL) {
        cache.setObject(player, forKey: url as NSURL) //adds player to the cache associated with the corresponding url
    }
            
}
