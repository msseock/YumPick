import SwiftUI

struct StoreDetailView: View {
    @State private var viewModel: StoreDetailViewModel
    @State private var bannerPage = 0
    @State private var isSearchExpanded = false
    @State private var selectedCategory: String? = nil

    init(storeId: String) {
        _viewModel = State(initialValue: StoreDetailViewModel(storeId: storeId))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.isLoading && viewModel.detail == nil {
                skeletonContent
            } else {
                mainContent
            }
            bottomBar
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                YPLikeButton(isLiked: viewModel.isLiked) {
                    Task { await viewModel.toggleLike() }
                }
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    bannerSection
                        .id("__top__")
                    metadataSection
                    directionsButton
                    Section {
                        menuListSection(proxy: proxy)
                    } header: {
                        stickyHeader(proxy: proxy)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 80)
            }
        }
    }

    // MARK: - Banner

    private var bannerSection: some View {
        Group {
            if let detail = viewModel.detail, !detail.store_image_urls.isEmpty {
                TabView(selection: $bannerPage) {
                    ForEach(Array(detail.store_image_urls.enumerated()), id: \.offset) { index, url in
                        CachedImage(path: url)
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 280)
            } else {
                Color(YPColor.backgroundSecondary)
                    .frame(maxWidth: .infinity, minHeight: 280)
            }
        }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            nameRow
            statsRow
            infoBox
            pickupTimePill
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }

    private var nameRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(viewModel.detail?.name ?? "")
                .font(YPFont.title1)
                .foregroundStyle(YPColor.textPrimary)
            if viewModel.detail?.is_picchelin == true {
                YPPickchelinTag()
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            Label("\(viewModel.pickCount)개", systemImage: "heart.fill")
                .font(YPFont.body3)
                .foregroundStyle(YPColor.textSecondary)
            Button {
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(YPColor.brandBrightForsythia)
                    Text(String(format: "%.1f", viewModel.detail?.total_rating ?? 0.0))
                        .font(YPFont.body3Bold)
                        .foregroundStyle(YPColor.textPrimary)
                    Text("(\(viewModel.detail?.total_review_count ?? 0))")
                        .font(YPFont.body3)
                        .foregroundStyle(YPColor.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(YPColor.textTertiary)
                }
            }
            Spacer()
            Text("누적 주문 \(viewModel.detail?.total_order_count ?? 0)회")
                .font(YPFont.body3)
                .foregroundStyle(YPColor.textTertiary)
        }
    }

    private var infoBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let address = viewModel.detail?.address {
                infoRow(icon: "mappin.and.ellipse", label: "가게주소", value: address)
            }
            if let open = viewModel.detail?.open, let close = viewModel.detail?.close {
                infoRow(icon: "clock", label: "영업시간", value: "매일 \(open) ~ \(close)")
            }
            if let parking = viewModel.detail?.parking_guide {
                infoRow(icon: "parkingsign.circle", label: "주차여부", value: parking)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(YPColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16)
                .font(.system(size: 13))
                .foregroundStyle(YPColor.textSecondary)
            Text(label)
                .font(YPFont.body3)
                .foregroundStyle(YPColor.textSecondary)
                .frame(width: 52, alignment: .leading)
            Text(value)
                .font(YPFont.body3)
                .foregroundStyle(YPColor.textPrimary)
        }
    }

    private var pickupTimePill: some View {
        HStack(spacing: 6) {
            Image(systemName: "figure.walk")
                .font(.system(size: 13))
            if let minutes = viewModel.detail?.estimated_pickup_time {
                if let dist = viewModel.distanceMeter {
                    Text("예상 소요시간 \(minutes)분 (\(Int(dist))m)")
                } else {
                    Text("예상 소요시간 \(minutes)분")
                }
            }
        }
        .font(YPFont.body3)
        .foregroundStyle(YPColor.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(YPColor.backgroundSecondary)
        .clipShape(Capsule())
    }

    // MARK: - Directions Button

    private var directionsButton: some View {
        Button {
        } label: {
            Text("길찾기")
                .font(YPFont.body1Bold)
                .foregroundStyle(YPColor.backgroundPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(YPColor.brandDeepSprout)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Sticky Header

    private func stickyHeader(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearchExpanded.toggle()
                        if !isSearchExpanded { viewModel.searchQuery = "" }
                    }
                } label: {
                    Image(systemName: isSearchExpanded ? "xmark" : "magnifyingglass")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(YPColor.brandDeepSprout)
                        .clipShape(Circle())
                        .foregroundStyle(YPColor.gray0)
                }

                if isSearchExpanded {
                    TextField("메뉴 검색", text: $viewModel.searchQuery)
                        .font(YPFont.body2)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(YPColor.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    categoryTokens(proxy: proxy)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)

            YPDivider()
        }
    }

    private func categoryTokens(proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !viewModel.searchQuery.isEmpty {
                    categoryToken(title: "검색한 메뉴", proxy: proxy)
                }
                ForEach(viewModel.menuSections, id: \.category) { section in
                    categoryToken(title: section.category, proxy: proxy)
                }
            }
            .padding(2)
        }
    }

    private func categoryToken(title: String, proxy: ScrollViewProxy) -> some View {
        let isSelected = selectedCategory == title

        return Button {
            selectedCategory = title
            withAnimation { proxy.scrollTo(title, anchor: .top) }
        } label: {
            Text(title)
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

    // MARK: - Menu List

    private func menuListSection(proxy: ScrollViewProxy) -> some View {
        ForEach(viewModel.filteredMenuSections, id: \.category) { section in
            VStack(alignment: .leading, spacing: 0) {
                Text(section.category)
                    .font(YPFont.body1Bold)
                    .foregroundStyle(YPColor.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                    .id(section.category)

                ForEach(section.menus) { menu in
                    menuCell(menu: menu)
                    YPDivider()
                        .padding(.leading, 16)
                }
            }
        }
    }

    private func menuCell(menu: StoreMenu) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let tag = menu.tags.first {
                    Text(tag)
                        .font(YPFont.caption1)
                        .foregroundStyle(YPColor.brandBlackSprout)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(YPColor.brandBrightSprout)
                        )
                }
                Text(menu.name ?? "")
                    .font(YPFont.body1Bold)
                    .foregroundStyle(menu.is_sold_out ? YPColor.textTertiary : YPColor.textPrimary)
                if let desc = menu.description {
                    Text(desc)
                        .font(YPFont.body3)
                        .foregroundStyle(YPColor.textSecondary)
                        .lineLimit(2)
                }
                Text("\(menu.price ?? 0)원")
                    .font(YPFont.body1Bold)
                    .foregroundStyle(menu.is_sold_out ? YPColor.textTertiary : YPColor.textPrimary)
                    .padding(.top, 2)

                if viewModel.quantity(for: menu.menu_id) > 0 {
                    quantityControl(menu: menu)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            menuImage(menu: menu)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            if !menu.is_sold_out && viewModel.quantity(for: menu.menu_id) == 0 {
                viewModel.increase(menuId: menu.menu_id)
            }
        }
    }

    private func menuImage(menu: StoreMenu) -> some View {
        ZStack(alignment: .center) {
            if let imagePath = menu.menu_image_url {
                CachedImage(path: imagePath)
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(YPColor.backgroundSecondary)
                    .frame(width: 80, height: 80)
            }
            if menu.is_sold_out {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 80, height: 80)
                Text("품절")
                    .font(YPFont.body3Bold)
                    .foregroundStyle(.white)
            }
        }
    }

    private func quantityControl(menu: StoreMenu) -> some View {
        HStack(spacing: 16) {
            Button {
                viewModel.decrease(menuId: menu.menu_id)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 28, height: 28)
                    .background(YPColor.backgroundSecondary)
                    .clipShape(Circle())
                    .foregroundStyle(YPColor.textPrimary)
            }
            Text("\(viewModel.quantity(for: menu.menu_id))")
                .font(YPFont.body2Bold)
                .foregroundStyle(YPColor.textPrimary)
                .frame(minWidth: 20, alignment: .center)
            Button {
                viewModel.increase(menuId: menu.menu_id)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 28, height: 28)
                    .background(YPColor.brandDeepSprout)
                    .clipShape(Circle())
                    .foregroundStyle(.white)
            }
        }
        .font(.system(size: 14, weight: .medium))
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Text("\(viewModel.totalPrice.formatted())원")
                .font(YPFont.title1)
                .foregroundStyle(YPColor.textPrimary)
            Spacer()
            // TODO: coordinator 패턴 도입 시 path 직접 push로 전환
            NavigationLink(value: viewModel.makeCheckoutSelection().map { HomePath.orderConfirm(selection: $0) }) {
                HStack(spacing: 8) {
                    if viewModel.totalQuantity > 0 {
                        Text("\(viewModel.totalQuantity)")
                            .font(YPFont.caption1)
                            .foregroundStyle(YPColor.brandBlackSprout)
                            .frame(width: 22, height: 22)
                            .background(YPColor.gray0)
                            .clipShape(Circle())
                    }
                    Text("결제하기")
                        .font(YPFont.body1Bold)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .frame(height: 48)
                .background(viewModel.totalQuantity > 0 ? YPColor.brandBlackSprout : YPColor.textTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(viewModel.totalQuantity == 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Skeleton

    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            skeletonBox(width: nil, height: 280, cornerRadius: 0)
            VStack(alignment: .leading, spacing: 12) {
                skeletonBox(width: 180, height: 24)
                skeletonBox(width: 240, height: 16)
                skeletonBox(width: nil, height: 96)
                skeletonBox(width: 160, height: 32, cornerRadius: 16)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            skeletonBox(width: nil, height: 48, cornerRadius: 10)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            ForEach(0..<4, id: \.self) { _ in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        skeletonBox(width: 160, height: 16)
                        skeletonBox(width: 200, height: 14)
                        skeletonBox(width: 120, height: 14)
                        skeletonBox(width: 60, height: 18)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    skeletonBox(width: 80, height: 80, cornerRadius: 12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                YPDivider()
                    .padding(.leading, 16)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 80)
        }
    }

    private func skeletonBox(width: CGFloat?, height: CGFloat, cornerRadius: CGFloat = 8) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(YPColor.backgroundSecondary)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        StoreDetailView(storeId: "mock-store-id")
            .onAppear {}
    }
}
