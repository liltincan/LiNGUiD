//
//  VideoCache.swift
//  LiNGUiD
//
//  Created by Jackson Sanders on 5/27/25.
//

import Foundation
import SwiftUI
import AVKit

final class VideoCache {
    static let shared = VideoCache() //singleton
   
    private init() {}
    
    private var cache = NSCache<NSURL, AVPlayer>()
    
    func player(for url: URL) -> AVPlayer? { //video url is passed in
        if let cached = cache.object(forKey: url as NSURL) { //check if video player already exists for given URL
            return cached //return the player if already in cache
        }
        
        let player = AVPlayer(url: url) //create video player for given URL
        player.actionAtItemEnd = .none //ensures that nothing happens upon video completion (pause, etc)
        cache.setObject(player, forKey: url as NSURL) //save current video player to cache with URL as key
        
        return player //return the new player
    }
}
