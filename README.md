# YumPick (냠픽)
> 내 주변 음식을 주문하고 픽업하는 서비스

<img width="1810" height="675" alt="image" src="https://github.com/user-attachments/assets/66fb2e59-b45a-49e9-bdf2-eb3fa7f14527" />




📆 2026. 04 - 2026.05

- **간편 픽업 주문**: 줄 서지 않고 미리 주문·결제 후 픽업만
- **실시간 채팅**: 매장/이웃과 실시간으로 소통하는 주문 커뮤니케이션
- **영상 피드**: HLS 스트리밍으로 보는 숏폼 영상 콘텐츠
- **동네 커뮤니티**: 텍스트·사진·영상으로 맛집 정보와 후기 공유
- **끊김 없는 경험**: 오프라인 상태, 토큰 만료 같은 예외 상황도 자연스럽게 처리

</br>

# 🎆 Screenshots

| 내 주변 매장탐색 | 픽업 주문 & 결제 | 실시간 채팅 |
| --- | --- | --- |
| <img width="527" height="636" alt="image" src="https://github.com/user-attachments/assets/b1d60728-de03-4240-9d6c-a6f7ef19e8a2" /> | <img width="526" height="635" alt="image" src="https://github.com/user-attachments/assets/e7a5cfc0-9ff5-4bbc-8bff-5e1f6e35c552" /> | <img width="316" height="636" alt="image" src="https://github.com/user-attachments/assets/ec9c460d-c974-409c-8942-06159b09b62e" /> | 

| 커뮤니티 | 비디오 스트리밍 | 리뷰 |
| --- | --- | --- |
| <img width="502" height="606" alt="image" src="https://github.com/user-attachments/assets/536b70c0-e46e-4f60-a960-15c3a761d4e3" /> | <img width="502" height="606" alt="image" src="https://github.com/user-attachments/assets/fc8d9a63-812c-4f73-b7f6-7d5d7ccec618" /> | <img width="502" height="606" alt="image" src="https://github.com/user-attachments/assets/aa6caca7-3b4b-4081-ac6f-745f88906607" /> | 





</br>

# 📌 Features

### 🛵 픽업 주문 & 결제

- **주문 흐름**: 매장 선택 → 메뉴 담기 → 주문 확정까지 이어지는 단순한 픽업 주문 플로우
- **PG 결제 연동**: 아임포트(PortOne) SDK로 실제 결제 → 결제 완료 → 영수증 조회까지 전체 흐름 구현
- **주문/결제 책임 분리**: 주문 확정은 `Checkout`, 영수증 조회는 `Payment`로 모듈 분리

### 💬 실시간 채팅

- **Socket.IO 실시간 통신**: 매장/이웃과 실시간 메시지 송수신
- **로컬 캐싱**: Realm으로 대화 내역을 로컬에 저장해 오프라인 진입 시에도 최근 대화 노출
- **계층 분리**: `ChatSocketManager`(통신) / `ChatRealmRepository`(영속성)로 역할 분리

### 🎬 영상 피드

- **HLS 스트리밍 플레이어**: AVFoundation 기반 커스텀 플레이어 구현 (`HLSPlayerView`)
- **자막 자체 파싱**: WebVTT 포맷을 파싱하는 `WebVTTParser` 구현 (서드파티 자막 라이브러리 미사용)

### 👥 동네 커뮤니티

- **게시판**: 텍스트/사진/영상 첨부가 가능한 맛집 정보·후기 게시글
- **상호작용**: 댓글, 좋아요, 매장 태그가 포함된 게시글 작성

### 🔐 인증 & 세션 관리

- **소셜 로그인**: Apple 로그인 → 자체 액세스·리프레시 토큰 발급
- **자동 토큰 갱신**: `Interceptor`가 토큰 만료 응답을 감지해 리프레시 토큰으로 재발급 후 요청 재시도
- **안전한 저장**: 토큰은 UserDefaults가 아닌 Keychain에만 저장

### 📡 끊김 없는 네트워크 경험

- **커스텀 네트워크 레이어**: URLSession을 래핑한 `NetworkManager`로 모든 통신 일원화
- **오프라인 감지**: `NetworkConnectivityMonitor`로 연결 상태를 감지해 전용 오프라인 화면(`NetworkUnavailableView`) 노출
- **프로토콜 기반 설계**: 모든 API는 `{Feature}ClientProtocol` 뒤에 숨겨 ViewModel이 구체 구현체에 의존하지 않도록 분리
- **핵심 로직 단위 테스트**: 토큰 만료 감지·재시도, 상태 코드별 에러 매핑 등 `NetworkManager`/`Interceptor` 동작을 단위 테스트로 검증

</br>

# 🛠 기술 스택

**개발 환경**

- **UI 프레임워크**: SwiftUI
- **최소 iOS 버전**: 18.6+
- **아키텍처**: MVVM + Combine, Coordinator 패턴
- **비동기 처리**: Swift Concurrency
- **의존성 관리**: SPM

**채팅**

- **Socket.IO Client**: 실시간 채팅 송수신
- **Realm**: 채팅 로컬 캐싱 및 오프라인 대응

**영상 스트리밍**

- **AVFoundation**: HLS 스트리밍 플레이어 구현
- **커스텀 WebVTT 파서**: 자막 포맷 자체 파싱

**인증 & 네트워크**

- **URLSession 기반 NetworkManager**: 자체 구현 네트워크 레이어
- **Interceptor**: 419 감지 및 토큰 자동 갱신
- **AuthenticationServices**: 소셜 로그인

**결제**

- **아임포트(PortOne) iOS SDK**: PG 결제 연동

**데이터 관리**

- **Keychain**: 인증 토큰 저장
- **Realm**: 채팅 메시지 로컬 저장
- **UserDefaults**: 사용자 설정 저장

**이미지 & 리소스**

- **Kingfisher**: `CachedImage` 래퍼로만 접근하는 이미지 캐싱
- **커스텀 디자인 시스템**: `YPColor`, `YPFont` 토큰

</br>

# 🌳 Folder

```bash
📱 YumPick
├── 🏗️ App
│   ├── YumPickApp.swift
│   └── AppCoordinator.swift
├── ⚡ Core
│   ├── Network (NetworkManager, Interceptor, ConnectivityMonitor)
│   ├── Keychain
│   ├── Realm (채팅 로컬 캐시)
│   ├── Socket (채팅 소켓 매니저)
│   ├── Session
│   └── Location
├── 🎨 Features
│   ├── Chat
│   ├── Community
│   ├── Video
│   ├── Checkout
│   ├── Payment
│   ├── Home
│   ├── Order
│   ├── Pick
│   ├── Login
│   ├── Join
│   ├── Profile
│   ├── Review
│   └── StoreDetail
├── 💾 Models
├── 🔧 Components
│   └── CachedImage.swift
└── 📦 Resource
    ├── DesignSystem   (YPColor, YPFont)
    ├── Assets.xcassets
    └── Fonts
```
