//
//  AppTitleText.swift
//  LiNGUiD
//
//  Created by Dev Gohil on 5/28/25.
//

import SwiftUI

struct AppTitleText: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 24, weight: .bold))
    }
}
