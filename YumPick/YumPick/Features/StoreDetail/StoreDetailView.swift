import SwiftUI

struct StoreDetailView: View {
    @State private var viewModel: StoreDetailViewModel
    @State private var bannerPage = 0
    @State private var isSearchExpanded = false
    @State private var selectedCategory: String? = nil
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

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
        .background(YP2Color.backgroundPrimary)
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(YP2Color.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(YP2Color.ink)
                }
            }
        }
        .background { SwipeBackEnabler() }
        .task { await viewModel.load() }
        .tapToHideKeyboard()
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    heroSection
                        .id("__top__")
                    metadataSection
                    infoStrip
                    Section {
                        menuListSection(proxy: proxy)
                    } header: {
                        stickyHeader(proxy: proxy)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .background(YP2Color.backgroundPrimary)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 80)
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        let hasImages = viewModel.detail.map { !$0.store_image_urls.isEmpty } ?? false

        return ZStack(alignment: .bottom) {
            if hasImages {
                TabView(selection: $bannerPage) {
                    ForEach(Array((viewModel.detail?.store_image_urls ?? []).enumerated()), id: \.offset) { index, url in
                        CachedImage(path: url)
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.4),
                        .init(color: Color.black.opacity(0.65), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                YP2Color.backgroundSecondary
                    .frame(maxWidth: .infinity)
            }

            if let detail = viewModel.detail {
                VStack(alignment: .leading, spacing: 6) {
                    if detail.is_picchelin == true {
                        YP2PickchelinBadge()
                    }
                    Text(detail.name ?? "새싹 카페")
                        .font(.custom("Pretendard-Bold", size: 27))
                        .foregroundStyle(hasImages ? .white : YP2Color.textPrimary)
                        .lineLimit(2)
                    Text(heroMetaSummary(detail: detail))
                        .font(YPFont.body3Bold)
                        .foregroundStyle(hasImages ? Color.white.opacity(0.9) : YP2Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .frame(height: 270)
    }

    private func heroMetaSummary(detail: StoreDetail) -> String {
        var parts: [String] = []
        parts.append("픽업 \(detail.estimated_pickup_time)분")
        if detail.total_rating > 0 {
            parts.append("★ \(String(format: "%.1f", detail.total_rating))")
        }
        if detail.total_review_count > 0 {
            parts.append("(\(detail.total_review_count)개)")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            statsRow
            infoBox
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            Label("\(viewModel.pickCount)개", systemImage: "heart.fill")
                .font(YPFont.body3)
                .foregroundStyle(YP2Color.textSecondary)
            Button {
                router.homePath.append(.reviewList(storeId: viewModel.storeId))
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(YP2Color.order)
                    Text(String(format: "%.1f", viewModel.detail?.total_rating ?? 0.0))
                        .font(YPFont.body3Bold)
                        .foregroundStyle(YP2Color.textPrimary)
                    Text("(\(viewModel.detail?.total_review_count ?? 0))")
                        .font(YPFont.body3)
                        .foregroundStyle(YP2Color.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(YP2Color.textTertiary)
                }
            }
            Spacer()
            Text("누적 주문 \(viewModel.detail?.total_order_count ?? 0)회")
                .font(YPFont.body3)
                .foregroundStyle(YP2Color.textTertiary)
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
        .background(YP2Color.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16)
                .font(.system(size: 13))
                .foregroundStyle(YP2Color.textSecondary)
            Text(label)
                .font(YPFont.body3)
                .foregroundStyle(YP2Color.textSecondary)
                .frame(width: 52, alignment: .leading)
            Text(value)
                .font(YPFont.body3)
                .foregroundStyle(YP2Color.textPrimary)
        }
    }

    // MARK: - Info Strip

    @ViewBuilder
    private var infoStrip: some View {
        if let minutes = viewModel.detail?.estimated_pickup_time {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("예상 픽업")
                        .font(YPFont.caption1)
                        .foregroundStyle(YP2Color.textMuted)
                    Group {
                        if let dist = viewModel.distanceMeter {
                            Text("\(minutes)분 후 가능 (\(Int(dist))m)")
                        } else {
                            Text("\(minutes)분 후 가능")
                        }
                    }
                    .font(.custom("Pretendard-Bold", size: 18))
                    .foregroundStyle(YP2Color.textPrimary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 62)
            .background(YP2Color.backgroundPrimary)
            .overlay {
                Rectangle()
                    .stroke(YP2Color.ink, lineWidth: 1)
            }
            .padding([.horizontal, .bottom], 16)
        }
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
                        .background(YP2Color.ink)
                        .clipShape(Circle())
                        .foregroundStyle(.white)
                }

                if isSearchExpanded {
                    TextField("메뉴 검색", text: $viewModel.searchQuery)
                        .font(YPFont.body2)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(YP2Color.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    categoryTokens(proxy: proxy)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(YP2Color.backgroundPrimary)

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
                .foregroundStyle(isSelected ? YP2Color.textPrimary : YP2Color.textSecondary)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(YP2Color.backgroundPrimary)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected ? YP2Color.ink : YP2Color.borderDefault,
                            lineWidth: isSelected ? 1.5 : 1
                        )
                }
        }
    }

    // MARK: - Menu List

    private func menuListSection(proxy: ScrollViewProxy) -> some View {
        ForEach(viewModel.filteredMenuSections, id: \.category) { section in
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(section.category)
                        .font(.custom("Pretendard-Bold", size: 22))
                        .foregroundStyle(YP2Color.textPrimary)
                    Spacer()
                    Text("\(section.menus.count)개")
                        .font(YPFont.caption1)
                        .foregroundStyle(YP2Color.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .id(section.category)

                VStack(spacing: 8) {
                    ForEach(section.menus) { menu in
                        menuCard(menu: menu)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private func menuCard(menu: StoreMenu) -> some View {
        HStack(alignment: .top, spacing: 12) {
            menuImage(menu: menu)

            VStack(alignment: .leading, spacing: 5) {
                if let tag = menu.tags.first {
                    Text(tag)
                        .font(YPFont.caption1)
                        .foregroundStyle(YP2Color.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Rectangle()
//                            RoundedRectangle(cornerRadius: 4)
                                .fill(YP2Color.order)
                        )
                }
                Text(menu.name ?? "")
                    .font(.custom("Pretendard-Bold", size: 15))
                    .foregroundStyle(menu.is_sold_out ? YP2Color.textTertiary : YP2Color.textPrimary)
                if let desc = menu.description {
                    Text(desc)
                        .font(YPFont.caption1)
                        .foregroundStyle(YP2Color.textMuted)
                        .lineLimit(2)
                }
                Text("\(menu.price ?? 0)원")
                    .font(.custom("Pretendard-Bold", size: 15))
                    .foregroundStyle(menu.is_sold_out ? YP2Color.textTertiary : YP2Color.textPrimary)

                if viewModel.quantity(for: menu.menu_id) > 0 {
                    quantityControl(menu: menu)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(YP2Color.backgroundPrimary)
        .overlay {
            Rectangle()
                .stroke(YP2Color.borderDefault, lineWidth: 1)
        }
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
                    .clipShape(Rectangle())
            } else {
                Rectangle()
                    .fill(YP2Color.backgroundSecondary)
                    .frame(width: 80, height: 80)
            }
            if menu.is_sold_out {
                Rectangle()
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
                    .background(YP2Color.backgroundSecondary)
                    .clipShape(Circle())
                    .foregroundStyle(YP2Color.textPrimary)
            }
            Text("\(viewModel.quantity(for: menu.menu_id))")
                .font(YPFont.body2Bold)
                .foregroundStyle(YP2Color.textPrimary)
                .frame(minWidth: 20, alignment: .center)
            Button {
                viewModel.increase(menuId: menu.menu_id)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 28, height: 28)
                    .background(YP2Color.ink)
                    .clipShape(Circle())
                    .foregroundStyle(.white)
            }
        }
        .font(.system(size: 14, weight: .medium))
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button {
                Task { await viewModel.toggleLike() }
            } label: {
                Image(viewModel.isLiked ? "Like_Fill" : "Like_Empty")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(YP2Color.ink)
                    .frame(width: 54, height: 54)
                    .overlay {
                        Rectangle()
                            .stroke(YP2Color.ink, lineWidth: 1)
                    }
            }

            NavigationLink(value: viewModel.makeCheckoutSelection().map { HomePath.orderConfirm(selection: $0) }) {
                HStack {
                    if viewModel.totalQuantity > 0 {
                        Text("장바구니 \(viewModel.totalQuantity)개")
                            .font(YPFont.body3Bold)
                            .foregroundStyle(YP2Color.ink)
                    }
                    Spacer()
                    Text(viewModel.totalQuantity > 0 ? "\(viewModel.totalPrice.formatted())원" : "결제하기")
                        .font(YPFont.body1Bold)
                        .foregroundStyle(viewModel.totalQuantity > 0 ? YP2Color.ink : YP2Color.textTertiary)
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(viewModel.totalQuantity > 0 ? YP2Color.order : YP2Color.backgroundSecondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(height: 54)
            .disabled(viewModel.totalQuantity == 0)
        }
        .frame(height: 54)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background {
            YP2Color.backgroundPrimary
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(YP2Color.borderDefault)
                .frame(height: 1)
        }
    }

    // MARK: - Skeleton

    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            skeletonBox(width: nil, height: 270, cornerRadius: 0)
            VStack(alignment: .leading, spacing: 12) {
                skeletonBox(width: 200, height: 24)
                skeletonBox(width: 240, height: 16)
                skeletonBox(width: nil, height: 96)
                skeletonBox(width: nil, height: 62, cornerRadius: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            ForEach(0..<4, id: \.self) { _ in
                HStack(alignment: .center, spacing: 12) {
                    skeletonBox(width: 80, height: 80, cornerRadius: 8)
                    VStack(alignment: .leading, spacing: 8) {
                        skeletonBox(width: 160, height: 15)
                        skeletonBox(width: 200, height: 13)
                        skeletonBox(width: 80, height: 15)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .overlay {
                    Rectangle()
                        .stroke(YP2Color.borderDefault, lineWidth: 1)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 80)
        }
    }

    private func skeletonBox(width: CGFloat?, height: CGFloat, cornerRadius: CGFloat = 8) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(YP2Color.backgroundSecondary)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

// .navigationBarBackButtonHidden(true) 사용 시 소멸되는 스와이프-백 제스처 복원
private struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }
    func updateUIViewController(_ vc: UIViewController, context: Context) {
        Task { @MainActor in
            vc.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            vc.navigationController?.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

#Preview {
    NavigationStack {
        StoreDetailView(storeId: "mock-store-id")
            .onAppear {}
    }
}
