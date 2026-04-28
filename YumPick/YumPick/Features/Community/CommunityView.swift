import SwiftUI

struct CommunityView: View {
    @State private var viewModel = CommunityViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.posts) { post in
                            PostCard(post: post)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task {
            await viewModel.fetchPosts()
        }
    }
}

private struct PostCard: View {
    let post: PostSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.title)
                        .font(YPFont.body2Bold)
                        .foregroundStyle(YPColor.textPrimary)
                        .lineLimit(1)

                    Text(post.content)
                        .font(YPFont.body3)
                        .foregroundStyle(YPColor.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                if let imagePath = post.files.first {
                    CachedImage(path: imagePath)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            HStack(spacing: 12) {
                Text(post.creator.nick)
                    .font(YPFont.caption1)
                    .foregroundStyle(YPColor.textTertiary)

                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(YPColor.actionAccent)
                    Text("\(Int(post.like_count))")
                        .font(YPFont.caption1)
                        .foregroundStyle(YPColor.textTertiary)
                }
            }
        }
        .padding(16)
        .background(YPColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(
            color: Color(red: 123/255, green: 120/255, blue: 134/255).opacity(0.08),
            radius: 6, x: 0, y: 4
        )
    }
}
