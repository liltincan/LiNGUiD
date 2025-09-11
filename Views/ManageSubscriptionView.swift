//
//  ManageSubscriptionView.swift
//  LiNGUiD
//
//  Created by Tahmidul Karim on 8/11/25.
//

import SwiftUI
import StoreKit

struct ManageSubscriptionView: View {
    @State private var showManage = false
    @ObservedObject private var sk = StoreKitManager.shared
    @State private var flicker = false
    
    var body: some View {
        VStack{
            if let exp = sk.expirationDate {
              Text((sk.willAutoRenew ?? false) ? "Your subscription will auto-renew on \(dateString(exp))" : "Your subscription will expire on \(dateString(exp))")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .padding(.bottom, 10)
                    .padding(.horizontal, 10)
                    .multilineTextAlignment(.center)
            } else {
                Text("Loading Subscription Information...")
                      .font(.system(size: 25, weight: .medium))
                      .foregroundStyle(Color.primary)
                      .padding(.bottom, 10)
                      .padding(.horizontal, 10)
                      .multilineTextAlignment(.center)
                      .opacity(flicker ? 0.55 : 1.0)
                      .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: flicker)
                      .onAppear { flicker = true }
            }
            
            Text("Press the button below to manage subscription.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.gray)
                .padding(.bottom, 0)
            
            Text("You can also manage it directly from the App Store.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.gray)
                .padding(.bottom, 10)
        
            Button {
                showManage = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape.fill")
                        .imageScale(.medium)
                    Text("Manage Subscription")
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.appPrimaryColor.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 0)
            .foregroundColor(.white)
            .shadow(radius: 8, y: 3)
            .manageSubscriptionsSheet(isPresented: $showManage)
            .accessibilityLabel("Manage your subscription in the App Store")
        }
        .padding(.top, -75)
    }
    
    private func dateString(_ d: Date) -> String {
      let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: d)
    }
}
