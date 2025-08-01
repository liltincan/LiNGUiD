//
//  CustomProgessView.swift
//  LiNGUiD
//
//  Created by Tahmidul Karim on 8/7/25.
//
import SwiftUI

struct CustomProgressView: View {
    var progress: Double  // from 0.0 to 1.0

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                .frame(width: 45, height: 45)

            // Progress circle
            Circle()
                .trim(from: 0.0, to: progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 45, height: 45)
                .rotationEffect(.degrees(-90)) // Start from top

            // Percentage text
            Text("\(Int(progress * 100))%")
                .foregroundColor(.white)
                .font(.system(size: 15, weight: .medium))
                .bold()
        }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = 8
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
