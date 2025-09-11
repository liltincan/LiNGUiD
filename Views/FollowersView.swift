//
//  FollowersView.swift
//  LiNGUiD
//
//  Created by Tahmidul Karim on 9/10/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct UserProfile: Identifiable {
    let id: String
    let username: String?
    let userName: String?
    let displayName: String?
    let photoURL: String?
    let isPro: Bool

    var primaryName: String {
        if let u = username, !u.isEmpty { return u }
        if let u = userName, !u.isEmpty { return u }
        if let d = displayName, !d.isEmpty { return d }
        return id
    }
}

@MainActor
final class FollowersViewModel: ObservableObject {
    @Published var followers: [UserProfile] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorText: String? = nil
    @Published var reachedEnd: Bool = false

    private let db = Firestore.firestore()
    private let pageSize: Int
    private let ownerUid: String
    private var allFollowerIds: [String] = []
    private var nextIndex: Int = 0

    init(ownerUid: String, pageSize: Int = 25) {
        self.ownerUid = ownerUid
        self.pageSize = pageSize
    }

    func resetAndLoad() {
        followers.removeAll()
        errorText = nil
        reachedEnd = false
        allFollowerIds = []
        nextIndex = 0
        Task {
            await loadFollowersIdList()
            await loadNextPage()
        }
    }

    func loadMoreIfNeeded(currentItem item: UserProfile?) {
        guard !isLoadingMore, !reachedEnd else { return }
        guard let item = item, let last = followers.last?.id, item.id == last else { return }
        Task { await loadNextPage() }
    }

    private func loadFollowersIdList() async {
        isLoading = true
        defer { isLoading = false }

        guard !ownerUid.isEmpty else {
            errorText = "No owner uid."
            return
        }
        do {
            let snap = try await db.collection("users").document(ownerUid).getDocument()
            let data = snap.data() ?? [:]

            var ids: [String] = []
            if let arr = data["followers"] as? [String] {
                ids = arr
            } else if let refs = data["followers"] as? [DocumentReference] {
                ids = refs.map { $0.documentID }
            } else if let arrObj = data["followers"] as? [[String: Any]] {
                ids = arrObj.compactMap { dict in
                    if let uid = dict["uid"] as? String { return uid }
                    if let id = dict["id"] as? String { return id }
                    if let ref = dict["ref"] as? DocumentReference { return ref.documentID }
                    return nil
                }
            } else if let dict = data["followers"] as? [String: Any] {
                ids = Array(dict.keys)
            }

            self.allFollowerIds = ids
            self.reachedEnd = ids.isEmpty
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func loadNextPage() async {
        guard !allFollowerIds.isEmpty, nextIndex < allFollowerIds.count else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let end = min(nextIndex + pageSize, allFollowerIds.count)
        let pageIds = Array(allFollowerIds[nextIndex..<end])

        let chunks: [[String]] = stride(from: 0, to: pageIds.count, by: 10).map { i in
            Array(pageIds[i..<min(i+10, pageIds.count)])
        }

        var fetched: [String: UserProfile] = [:]
        do {
            for chunk in chunks where !chunk.isEmpty {
                let snap = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                for doc in snap.documents {
                    let data = doc.data()
                    let photo =
                        (data["profilePhotoUrl"] as? String) ??
                        (data["photoURL"] as? String) ??
                        (data["photoUrl"] as? String)
                    let rawIsPro = data["isPro"]
                    let isPro =
                        (rawIsPro as? Bool) ??
                        ((rawIsPro as? String)?.lowercased() == "true")
                    let profile = UserProfile(
                        id: doc.documentID,
                        username: data["username"] as? String,
                        userName: data["userName"] as? String,
                        displayName: data["displayName"] as? String,
                        photoURL: photo,
                        isPro: isPro ?? false
                    )
                    fetched[doc.documentID] = profile
                }

            }

            let ordered = pageIds.compactMap { fetched[$0] }

            followers.append(contentsOf: ordered)
            nextIndex = end
            if nextIndex >= allFollowerIds.count { reachedEnd = true }
        } catch {
            errorText = error.localizedDescription
        }
    }
}


struct FollowersView: View {
    @StateObject private var vm: FollowersViewModel

    init(ownerUid: String) {
        _vm = StateObject(wrappedValue: FollowersViewModel(ownerUid: ownerUid))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let error = vm.errorText, !error.isEmpty {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                if vm.followers.isEmpty && vm.reachedEnd && !vm.isLoading {
                    Text("No followers yet")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }

                ForEach(vm.followers) { user in
                    HStack(spacing: 12) {
                        Avatar(urlString: user.photoURL)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 1) {
                                Text(user.primaryName)
                                    .font(.headline)
                                if user.isPro {
                                    Image(systemName: "checkmark.seal.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color.appPrimaryColor)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 5)
                    .onAppear { vm.loadMoreIfNeeded(currentItem: user) }
                    
                    Divider()
                }

                if vm.isLoadingMore {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if !vm.reachedEnd && !vm.followers.isEmpty {
                    HStack {
                        Spacer()
                        Text("Scroll to load more…")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(.top, 20)
        }
        .navigationTitle("Followers")
        .task { vm.resetAndLoad() }
        .refreshable { vm.resetAndLoad() }
        .overlay {
            if vm.isLoading && vm.followers.isEmpty {
                ProgressView().scaleEffect(1.2)
            }
        }
    }
}

struct Avatar: View {
    let urlString: String?
    var body: some View {
        Group {
            if let s = urlString, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty: ProgressView()
                    case .success(let img): img.resizable().scaledToFill()
                    case .failure: placeholder
                    @unknown default: placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }
    private var placeholder: some View {
        Circle().fill(Color.gray.opacity(0.2))
            .overlay(Image(systemName: "person.fill").foregroundColor(.gray))
    }
}
