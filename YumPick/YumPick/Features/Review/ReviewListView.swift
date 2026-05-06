import SwiftUI

struct ReviewListView: View {
    @State private var viewModel: ReviewListViewModel

    init(storeId: String) {
        _viewModel = State(initialValue: ReviewListViewModel(storeId: storeId))
    }

    private let orderByOptions: [(label: String, value: String)] = [
        ("최신순", "latest"),
        ("별점 높은 순", "rating_high"),
        ("별점 낮은 순", "rating_low")
    ]

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.reviews.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                reviewContent
            }
        }
        .navigationTitle("리뷰")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private var reviewContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ratingHeader
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)

                YPDivider()

                Section {
                    reviewList
                } header: {
                    orderByPicker
                        .background(Color.white)
                }
            }
        }
    }

    // MARK: - Rating Header

    private var ratingHeader: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(spacing: 4) {
                Text(String(format: "%.1f", viewModel.averageRating))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(YPColor.textPrimary)
                starRow(rating: viewModel.averageRating)
                Text("리뷰 \(viewModel.totalCount)개")
                    .font(YPFont.body3)
                    .foregroundStyle(YPColor.textTertiary)
            }
            .frame(width: 120)

            VStack(spacing: 6) {
                let maxCount = viewModel.ratings.map(\.count).max() ?? 1
                ForEach(viewModel.ratings.sorted { $0.rating > $1.rating }, id: \.rating) { item in
                    ratingBar(item: item, maxCount: max(maxCount, 1))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func starRow(rating: Double) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: Double(i) <= rating ? "star.fill" : "star")
                    .font(.system(size: 14))
                    .foregroundStyle(YPColor.brandBrightForsythia)
            }
        }
    }

    private func ratingBar(item: ReviewRating, maxCount: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(item.rating)")
                .font(YPFont.caption1)
                .foregroundStyle(YPColor.textSecondary)
                .frame(width: 12)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(YPColor.backgroundSecondary)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(YPColor.brandBrightForsythia)
                        .frame(width: geo.size.width * CGFloat(item.count) / CGFloat(maxCount))
                }
            }
            .frame(height: 8)
            Text("\(item.count)")
                .font(YPFont.caption1)
                .foregroundStyle(YPColor.textTertiary)
                .frame(width: 24, alignment: .trailing)
        }
    }

    // MARK: - Order Picker

    private var orderByPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(orderByOptions, id: \.value) { option in
                    let isSelected = viewModel.selectedOrderBy == option.value
                    Button {
                        Task { await viewModel.changeOrder(option.value) }
                    } label: {
                        Text(option.label)
                            .font(YPFont.body3)
                            .foregroundStyle(isSelected ? YPColor.brandBlackSprout : YPColor.gray60)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(
                                        isSelected ? YPColor.brandBlackSprout : YPColor.gray30,
                                        lineWidth: isSelected ? 1.5 : 1
                                    )
                            }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Review List

    private var reviewList: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.reviews) { review in
                ReviewCell(review: review)
                YPDivider()
                    .padding(.horizontal, 20)
            }

            if viewModel.isLoadingMore {
                ProgressView()
                    .padding(.vertical, 16)
            }

            Color.clear
                .frame(height: 1)
                .onAppear {
                    Task { await viewModel.loadMore() }
                }
        }
    }
}

// MARK: - Review Cell

private struct ReviewCell: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                CachedImage(path: review.creator.profileImage)
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(review.creator.nick)
                        .font(YPFont.body2Bold)
                        .foregroundStyle(YPColor.textPrimary)
                    HStack(spacing: 4) {
                        Text("리뷰 \(review.user_total_review_count)개")
                            .font(YPFont.caption1)
                            .foregroundStyle(YPColor.textTertiary)
                        Text("·")
                            .font(YPFont.caption1)
                            .foregroundStyle(YPColor.textTertiary)
                        Text(String(format: "평균 %.1f", review.user_total_rating))
                            .font(YPFont.caption1)
                            .foregroundStyle(YPColor.textTertiary)
                    }
                }

                Spacer()

                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(YPColor.brandBrightForsythia)
                    Text("\(review.rating)")
                        .font(YPFont.body2Bold)
                        .foregroundStyle(YPColor.textPrimary)
                }
            }

            if !review.order_menu_list.isEmpty {
                Text(review.order_menu_list.joined(separator: ", "))
                    .font(YPFont.caption1)
                    .foregroundStyle(YPColor.textTertiary)
            }

            Text(review.content)
                .font(YPFont.body2)
                .foregroundStyle(YPColor.textPrimary)

            if !review.review_image_urls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(review.review_image_urls, id: \.self) { url in
                            CachedImage(path: url)
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            Text(DateFormatManager.shared.orderDate(from: review.createdAt))
                .font(YPFont.caption1)
                .foregroundStyle(YPColor.textTertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

#Preview {
    NavigationStack {
        ReviewListView(storeId: "mock-store-id")
    }
}
