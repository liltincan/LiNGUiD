//
//  VideoCommentView.swift
//  LiNGUiD
//
//  Created by Soumil Voona on 7/14/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct VideoCommentView: View {
    let videoId: String
    let language: String?
    @Binding var commentCount: Int
    
    @State private var comments: [Comment] = []
    @State private var newCommentText = ""
    @State private var isPosting = false
    @State private var replyingToComment: Comment?
    @State private var showingReplyField = false
    @State private var replyText = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userSession: UserSessionViewModel
    
    private let db = Firestore.firestore()
    private let commentService = CommentService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("Comments")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Placeholder for balance
                    Button("") {}
                        .disabled(true)
                        .opacity(0)
                }
                .padding()
                .background(Color.black)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                
                // Comments List
                if isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Loading comments...")
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if comments.isEmpty {
                    VStack {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No comments yet")
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                        Text("Be the first to comment!")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(comments) { comment in
                                CommentRowView(
                                    comment: comment,
                                    onReply: { selectedComment in
                                        replyingToComment = selectedComment
                                        showingReplyField = true
                                    },
                                    onLike: { commentId in
                                        handleLikeComment(commentId: commentId)
                                    },
                                    onDislike: { commentId in
                                        handleDislikeComment(commentId: commentId)
                                    }
                                )
                                
                                // Show replies if any
                                if let replies = comment.replies {
                                    ForEach(replies) { reply in
                                        CommentRowView(
                                            comment: reply,
                                            isReply: true,
                                            onReply: { _ in },
                                            onLike: { commentId in
                                                handleLikeComment(commentId: commentId)
                                            },
                                            onDislike: { commentId in
                                                handleDislikeComment(commentId: commentId)
                                            }
                                        )
                                    }
                                }
                                
                                Divider()
                                    .background(Color.gray.opacity(0.2))
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                
                // Comment Input
                VStack(spacing: 0) {
                    if showingReplyField, let replyingComment = replyingToComment {
                        HStack {
                            Text("Replying to @\(replyingComment.username)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Button("Cancel") {
                                showingReplyField = false
                                replyingToComment = nil
                                replyText = ""
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    HStack(spacing: 12) {
                        // Current user profile picture
                        ProfilePictureView(
                            uploaderPfp: userSession.currentUser?.profilePhotoUrl,
                            size: 32
                        )
                        
                        // Text input
                        TextField(
                            showingReplyField ? "Reply..." : "Add a comment...",
                            text: showingReplyField ? $replyText : $newCommentText
                        )
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(20)
                        .foregroundColor(.white)
                        
                        // Send button
                        Button(action: {
                            if showingReplyField {
                                postReply()
                            } else {
                                postComment()
                            }
                        }) {
                            if isPosting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(isPosting || (showingReplyField ? replyText.isEmpty : newCommentText.isEmpty))
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color.black)
            }
            .background(Color.black)
        }
        .navigationBarHidden(true)
        .onAppear {
            loadComments()
        }
    }
    
    private func loadComments() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let loadedComments = try await commentService.fetchComments(for: videoId, language: language)
                await MainActor.run {
                    self.comments = loadedComments
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load comments: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func postComment() {
        guard !newCommentText.isEmpty,
              let currentUser = userSession.currentUser,
              let userId = currentUser.id,
              let username = currentUser.userName else { return }
        
        isPosting = true
        errorMessage = nil
        
        let commentData = CommentData(
            videoId: videoId,
            userId: userId,
            username: username,
            userProfilePicture: currentUser.profilePhotoUrl,
            text: newCommentText,
            language: language
        )
        
        Task {
            do {
                let newComment = try await commentService.postComment(commentData)
                await MainActor.run {
                    self.comments.insert(newComment, at: 0)
                    self.newCommentText = ""
                    self.isPosting = false
                }
                await FirestoreService.shared.updateNumberOfComments(videoId: videoId, language: language ?? "")
                commentCount += 1
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to post comment: \(error.localizedDescription)"
                    self.isPosting = false
                }
            }
        }
        
    }
    
    private func postReply() {
        guard !replyText.isEmpty,
              let currentUser = userSession.currentUser,
              let userId = currentUser.id,
              let username = currentUser.userName,
              let parentComment = replyingToComment else { return }
        
        isPosting = true
        errorMessage = nil
        
        let replyData = CommentData(
            videoId: videoId,
            userId: userId,
            username: username,
            userProfilePicture: currentUser.profilePhotoUrl,
            text: replyText,
            language: language,
            isReply: true,
            parentCommentId: parentComment.id
        )
        
        Task {
            do {
                let newReply = try await commentService.postReply(replyData)
                await MainActor.run {
                    // Find the parent comment and add reply
                    if let index = self.comments.firstIndex(where: { $0.id == parentComment.id }) {
                        var updatedComment = self.comments[index]
                        var replies = updatedComment.replies ?? []
                        replies.append(newReply)
                        updatedComment = Comment(
                            id: updatedComment.id,
                            videoId: updatedComment.videoId,
                            userId: updatedComment.userId,
                            username: updatedComment.username,
                            userProfilePicture: updatedComment.userProfilePicture,
                            text: updatedComment.text,
                            timestamp: updatedComment.timestamp,
                            likes: updatedComment.likes,
                            dislikes: updatedComment.dislikes,
                            replies: replies,
                            isReply: updatedComment.isReply,
                            parentCommentId: updatedComment.parentCommentId
                        )
                        self.comments[index] = updatedComment
                    }
                    
                    self.replyText = ""
                    self.showingReplyField = false
                    self.replyingToComment = nil
                    self.isPosting = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to post reply: \(error.localizedDescription)"
                    self.isPosting = false
                }
            }
        }
    }
    
    private func handleLikeComment(commentId: String) {
        guard let currentUser = userSession.currentUser,
              let userId = currentUser.id else { return }
        
        Task {
            do {
                try await commentService.toggleLike(commentId: commentId, userId: userId)
                // Don't refresh - let the UI handle the state
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to update like: \(error.localizedDescription)"
                }
            }
        }
    }

    private func handleDislikeComment(commentId: String) {
        guard let currentUser = userSession.currentUser,
              let userId = currentUser.id else { return }
        
        Task {
            do {
                try await commentService.toggleDislike(commentId: commentId, userId: userId)
                // Don't refresh - let the UI handle the state
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to update dislike: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Comment Service
class CommentService {
    static let shared = CommentService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func fetchComments(for videoId: String, language: String?) async throws -> [Comment] {
        let snapshot = try await db.collection("comments")
            .whereField("videoId", isEqualTo: videoId)
            .whereField("isReply", isEqualTo: false)
            .order(by: "timestamp", descending: true)
            .getDocuments()
        
        var comments: [Comment] = []
        
        for document in snapshot.documents {
            let comment = try parseComment(from: document)
            
            // Fetch replies for this comment
            let replies = try await fetchReplies(for: comment.id)
            
            let commentWithReplies = Comment(
                id: comment.id,
                videoId: comment.videoId,
                userId: comment.userId,
                username: comment.username,
                userProfilePicture: comment.userProfilePicture,
                text: comment.text,
                timestamp: comment.timestamp,
                likes: comment.likes,
                dislikes: comment.dislikes,
                replies: replies.isEmpty ? nil : replies,
                isReply: comment.isReply,
                parentCommentId: comment.parentCommentId
            )
            
            comments.append(commentWithReplies)
        }
        
        return comments
    }
    
    private func fetchReplies(for commentId: String) async throws -> [Comment] {
        let snapshot = try await db.collection("comments")
            .whereField("parentCommentId", isEqualTo: commentId)
            .order(by: "timestamp", descending: false)
            .getDocuments()
        
        return try snapshot.documents.map { try parseComment(from: $0) }
    }
    
    func postComment(_ commentData: CommentData) async throws -> Comment {
        let commentDoc = [
            "videoId": commentData.videoId,
            "userId": commentData.userId,
            "username": commentData.username,
            "userProfilePicture": commentData.userProfilePicture ?? "",
            "text": commentData.text,
            "timestamp": FieldValue.serverTimestamp(),
            "likes": 0,
            "dislikes": 0,
            "likedBy": [],
            "dislikedBy": [],
            "isReply": commentData.isReply,
            "language": commentData.language ?? "unknown"
        ] as [String: Any]
        
        let docRef = try await db.collection("comments").addDocument(data: commentDoc)
        
        return Comment(
            id: docRef.documentID,
            videoId: commentData.videoId,
            userId: commentData.userId,
            username: commentData.username,
            userProfilePicture: commentData.userProfilePicture,
            text: commentData.text,
            timestamp: Date(),
            likes: 0,
            dislikes: 0,
            isReply: commentData.isReply,
            parentCommentId: commentData.parentCommentId
        )
    }
    
    func postReply(_ replyData: CommentData) async throws -> Comment {
        var replyDoc = [
            "videoId": replyData.videoId,
            "userId": replyData.userId,
            "username": replyData.username,
            "userProfilePicture": replyData.userProfilePicture ?? "",
            "text": replyData.text,
            "timestamp": FieldValue.serverTimestamp(),
            "likes": 0,
            "dislikes": 0,
            "likedBy": [],
            "dislikedBy": [],
            "isReply": true,
            "language": replyData.language ?? "unknown"
        ] as [String: Any]
        
        if let parentCommentId = replyData.parentCommentId {
            replyDoc["parentCommentId"] = parentCommentId
        }
        
        let docRef = try await db.collection("comments").addDocument(data: replyDoc)
        
        return Comment(
            id: docRef.documentID,
            videoId: replyData.videoId,
            userId: replyData.userId,
            username: replyData.username,
            userProfilePicture: replyData.userProfilePicture,
            text: replyData.text,
            timestamp: Date(),
            likes: 0,
            dislikes: 0,
            isReply: true,
            parentCommentId: replyData.parentCommentId
        )
    }
    
    func toggleLike(commentId: String, userId: String) async throws {
        let docRef = db.collection("comments").document(commentId)
        
        try await db.runTransaction { transaction, errorPointer in
            let document: DocumentSnapshot
            do {
                document = try transaction.getDocument(docRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let data = document.data() else {
                let error = NSError(domain: "CommentService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Comment not found"])
                errorPointer?.pointee = error
                return nil
            }
            
            var likedBy = data["likedBy"] as? [String] ?? []
            var dislikedBy = data["dislikedBy"] as? [String] ?? []
            var likes = data["likes"] as? Int ?? 0
            var dislikes = data["dislikes"] as? Int ?? 0
            
            // Remove from disliked if present
            if let dislikeIndex = dislikedBy.firstIndex(of: userId) {
                dislikedBy.remove(at: dislikeIndex)
                dislikes = max(0, dislikes - 1)
            }
            
            // Toggle like
            if let likeIndex = likedBy.firstIndex(of: userId) {
                likedBy.remove(at: likeIndex)
                likes = max(0, likes - 1)
            } else {
                likedBy.append(userId)
                likes += 1
            }
            
            let updateData: [String: Any] = [
                "likedBy": likedBy,
                "dislikedBy": dislikedBy,
                "likes": likes,
                "dislikes": dislikes
            ]
            
            transaction.updateData(updateData, forDocument: docRef)
            return nil
        }
    }
    
    func toggleDislike(commentId: String, userId: String) async throws {
        let docRef = db.collection("comments").document(commentId)
        
        try await db.runTransaction { transaction, errorPointer in
            let document: DocumentSnapshot
            do {
                document = try transaction.getDocument(docRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let data = document.data() else {
                let error = NSError(domain: "CommentService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Comment not found"])
                errorPointer?.pointee = error
                return nil
            }
            
            var likedBy = data["likedBy"] as? [String] ?? []
            var dislikedBy = data["dislikedBy"] as? [String] ?? []
            var likes = data["likes"] as? Int ?? 0
            var dislikes = data["dislikes"] as? Int ?? 0
            
            // Remove from liked if present
            if let likeIndex = likedBy.firstIndex(of: userId) {
                likedBy.remove(at: likeIndex)
                likes = max(0, likes - 1)
            }
            
            // Toggle dislike
            if let dislikeIndex = dislikedBy.firstIndex(of: userId) {
                dislikedBy.remove(at: dislikeIndex)
                dislikes = max(0, dislikes - 1)
            } else {
                dislikedBy.append(userId)
                dislikes += 1
            }
            
            let updateData: [String: Any] = [
                "likedBy": likedBy,
                "dislikedBy": dislikedBy,
                "likes": likes,
                "dislikes": dislikes
            ]
            
            transaction.updateData(updateData, forDocument: docRef)
            return nil
        }
    }
    
    private func parseComment(from document: DocumentSnapshot) throws -> Comment {
        let data = document.data() ?? [:]
        
        guard let videoId = data["videoId"] as? String,
              let userId = data["userId"] as? String,
              let username = data["username"] as? String,
              let text = data["text"] as? String else {
            throw NSError(domain: "CommentService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid comment data"])
        }
        
        let userProfilePicture = data["userProfilePicture"] as? String
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        let likes = data["likes"] as? Int ?? 0
        let dislikes = data["dislikes"] as? Int ?? 0
        let isReply = data["isReply"] as? Bool ?? false
        let parentCommentId = data["parentCommentId"] as? String
        
        return Comment(
            id: document.documentID,
            videoId: videoId,
            userId: userId,
            username: username,
            userProfilePicture: userProfilePicture,
            text: text,
            timestamp: timestamp,
            likes: likes,
            dislikes: dislikes,
            isReply: isReply,
            parentCommentId: parentCommentId
        )
    }
}

// MARK: - Comment Data Structure
struct CommentData {
    let videoId: String
    let userId: String
    let username: String
    let userProfilePicture: String?
    let text: String
    let language: String?
    let isReply: Bool
    let parentCommentId: String?
    
    init(videoId: String, userId: String, username: String, userProfilePicture: String?, text: String, language: String?, isReply: Bool = false, parentCommentId: String? = nil) {
        self.videoId = videoId
        self.userId = userId
        self.username = username
        self.userProfilePicture = userProfilePicture
        self.text = text
        self.language = language
        self.isReply = isReply
        self.parentCommentId = parentCommentId
    }
}

struct CommentRowView: View {
    let comment: Comment
    let isReply: Bool
    let onReply: (Comment) -> Void
    let onLike: (String) -> Void
    let onDislike: (String) -> Void
    
    @State private var isLiked = false
    @State private var isDisliked = false
    @State private var likeCount: Int
    @State private var dislikeCount: Int
    
    @EnvironmentObject var userSession: UserSessionViewModel
    
    init(
        comment: Comment,
        isReply: Bool = false,
        onReply: @escaping (Comment) -> Void,
        onLike: @escaping (String) -> Void,
        onDislike: @escaping (String) -> Void
    ) {
        self.comment = comment
        self.isReply = isReply
        self.onReply = onReply
        self.onLike = onLike
        self.onDislike = onDislike
        self._likeCount = State(initialValue: comment.likes)
        self._dislikeCount = State(initialValue: comment.dislikes)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isReply {
                Spacer()
                    .frame(width: 32)
            }
            
            // Profile picture
            ProfilePictureView(
                uploaderPfp: comment.userProfilePicture,
                size: isReply ? 28 : 32
            )
            
            VStack(alignment: .leading, spacing: 4) {
                // Username and time
                HStack {
                    Text(comment.username)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(comment.relativeTime)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                
                // Comment text
                Text(comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Action buttons
                HStack(spacing: 20) {
                    Button(action: {
                        onLike(comment.id)
                        
                        if isLiked {
                            // Already liked, so unlike
                            isLiked = false
                            likeCount = max(0, likeCount - 1)
                        } else {
                            // Not liked, so like
                            isLiked = true
                            likeCount += 1
                            
                            // If disliked, remove dislike
                            if isDisliked {
                                isDisliked = false
                                dislikeCount = max(0, dislikeCount - 1)
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 12))
                                .foregroundColor(isLiked ? .red : .gray)
                            
                            if likeCount > 0 {
                                Text("\(likeCount)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Button(action: {
                        onDislike(comment.id)
                        
                        if isDisliked {
                            // Already disliked, so remove dislike
                            isDisliked = false
                            dislikeCount = max(0, dislikeCount - 1)
                        } else {
                            // Not disliked, so dislike
                            isDisliked = true
                            dislikeCount += 1
                            
                            // If liked, remove like
                            if isLiked {
                                isLiked = false
                                likeCount = max(0, likeCount - 1)
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                .font(.system(size: 12))
                                .foregroundColor(isDisliked ? .blue : .gray)
                        }
                    }
                    
                    if !isReply {
                        Button(action: {
                            onReply(comment)
                        }) {
                            Text("Reply")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onAppear {
            // Initialize the like/dislike state based on current user
            if let currentUser = userSession.currentUser,
               let userId = currentUser.id {
                // Check if current user has already liked/disliked this comment
                // You'll need to add likedBy and dislikedBy arrays to your Comment model
                // and update your parseComment function to include these fields
                isLiked = comment.likedBy?.contains(userId) ?? false
                isDisliked = comment.dislikedBy?.contains(userId) ?? false
            }
        }
    }
}
