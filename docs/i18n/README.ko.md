# LaunchOne

**언어**: [English](../../README.md) | [中文](../../README.zh.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Français](README.fr.md) | [Español](README.es.md) | [Deutsch](README.de.md) | [Русский](README.ru.md) | [हिन्दी](README.hi.md) | [Tiếng Việt](README.vi.md)

## 📥 다운로드

**[여기에서 다운로드](https://github.com/mamahuhu-io/LaunchOne/releases/latest)** - 최신 버전 받기

⭐ [LaunchOne](https://github.com/mamahuhu-io/LaunchOne) 및 원 프로젝트 [LaunchNext](https://github.com/RoversX/LaunchNext)에 스타 부탁드립니다!

| | |
|:---:|:---:|
| ![](../assets/main.webp) | ![](../assets/setting-general.webp) |
| ![](../assets/setting-appearance.webp) | ![](../assets/setting-apptitle.webp) |

macOS Tahoe는 Launchpad를 제거했습니다. 새로운 UI는 사용하기 어렵고 Bio GPU를 충분히 활용하지 못합니다. Apple은 최소한 이전으로 돌아갈 수 있는 옵션을 제공해야 합니다. 그 전까지는 LaunchOne을 사용하세요.

*[RoversX](https://github.com/RoversX/LaunchNext) 의 [LaunchNext]를 기반으로 개발되었습니다. 원본 프로젝트에 감사드립니다!*

*LaunchNext는 GPL 3 라이선스를 선택했으며, LaunchOne도 동일한 조건을 따릅니다.*

### LaunchOne 제공 기능
- ✅ **이전 시스템 Launchpad를 원클릭으로 가져오기** — 네이티브 Launchpad SQLite 데이터베이스(` /private$(getconf DARWIN_USER_DIR)com.apple.dock.launchpad/db/db`)를 직접 읽어 기존 폴더, 앱 위치 및 레이아웃을 완벽하게 복원
- ✅ **클래식 Launchpad 경험** — 사랑받아온 원본과 동일한 인터페이스
- ✅ **다국어 지원** — 영어, 중국어, 일본어, 프랑스어, 스페인어 지원
- ✅ **아이콘 라벨 숨기기** — 앱 이름이 필요 없을 때 미니멀 뷰
- ✅ **아이콘 크기 사용자 지정** — 선호에 맞게 아이콘 크기 조정
- ✅ **스마트 폴더 관리** — 예전처럼 폴더 생성 및 정리
- ✅ **즉시 검색 및 키보드 내비게이션** — 빠르게 앱 찾기

### macOS Tahoe에서 잃어버린 것들
- ❌ 앱 사용자 지정 정리 불가
- ❌ 사용자 폴더 생성 불가
- ❌ 드래그 앤 드롭 사용자화 불가
- ❌ 시각적 앱 관리 불가
- ❌ 강제 카테고리 그룹화

## 기능

### 🎯 **즉시 앱 실행**
- 더블 클릭으로 바로 실행
- 완전한 키보드 내비게이션 지원
- 실시간 필터링 초고속 검색

### 📁 **고급 폴더 시스템**
- 앱을 겹쳐 폴더 생성
- 인라인 편집으로 폴더 이름 변경
- 사용자 지정 폴더 아이콘 및 정리
- 원활한 앱 드래그 앤 드롭

### 🔍 **스마트 검색**
- 실시간 퍼지 매칭
- 설치된 모든 앱 검색
- 빠른 접근 키보드 단축키

### 🎨 **모던 인터페이스 디자인**
- **리퀴드 글래스 효과**: regularMaterial + 우아한 그림자
- 전체 화면 및 창 모드
- 부드러운 애니메이션과 전환
- 깔끔한 반응형 레이아웃

### 🔄 **매끄러운 데이터 마이그레이션**
- **원클릭 Launchpad 가져오기** (macOS 네이티브 DB에서)
- 앱 자동 감지 및 스캔
- SwiftData를 통한 레이아웃 영구 저장
- 시스템 업데이트 동안 데이터 손실 없음

### ⚙️ **시스템 통합**
- 네이티브 macOS 앱
- 다중 디스플레이 스마트 배치
- Dock 및 시스템 앱과 연동
- 배경 클릭 감지 (스마트 닫기)

## 기술 아키텍처

### 최신 기술로 구축
- **SwiftUI**: 선언적, 고성능 UI 프레임워크
- **SwiftData**: 강력한 데이터 영속성 레이어
- **AppKit**: 깊은 macOS 통합
- **SQLite3**: Launchpad DB 직접 읽기

### 데이터 저장
앱 데이터는 다음 위치에 안전하게 저장됩니다:
```
~/Library/Application Support/LaunchOne/Data.store
```

### 네이티브 Launchpad 통합
시스템 Launchpad DB에서 직접 읽기:
```bash
/private$(getconf DARWIN_USER_DIR)com.apple.dock.launchpad/db/db
```

## 설치

### 시스템 요구 사항
- macOS 26 (Tahoe) 이상
- Apple Silicon 또는 Intel 프로세서
- Xcode 26 (소스에서 빌드)

### 소스에서 빌드

1. **저장소 클론**
   ```bash
   clone git@github.com:mamahuhu-io/LaunchOne.git
   cd LaunchOne
   ```

2. **Xcode에서 열기**
   ```bash
   open LaunchOne.xcodeproj
   ```

3. **빌드 및 실행**
   - 대상 디바이스 선택
   - `⌘+R`로 빌드 및 실행
   - 또는 `⌘+B`로 빌드만

### 커맨드라인 빌드
```bash
xcodebuild -project LaunchOne.xcodeproj -scheme LaunchOne -configuration Release
```

## 사용 방법

### 빠른 시작
1. **첫 실행**: LaunchOne이 설치된 앱을 자동 스캔
2. **선택**: 클릭으로 선택, 더블 클릭으로 실행
3. **검색**: 입력 즉시 앱 필터링
4. **정리**: 앱 드래그로 폴더 및 레이아웃 구성

### Launchpad 가져오기
1. 설정(기어 아이콘) 열기
2. **"Import Launchpad"** 클릭
3. 기존 레이아웃과 폴더가 자동으로 가져와집니다

### 폴더 관리
- **폴더 생성**: 앱을 다른 앱 위로 드래그
- **폴더 이름 변경**: 폴더 이름 클릭
- **앱 추가**: 폴더로 드래그
- **앱 제거**: 폴더 밖으로 드래그

### 표시 모드
- **창 모드**: 둥근 모서리의 플로팅 창
- **전체 화면**: 최대 가시성
- 설정에서 모드 전환

## 알려진 문제

> **현재 개발 상태**
> - 🔄 **스크롤 동작**: 일부 상황에서 불안정할 수 있음 (빠른 제스처 시)
> - 🎯 **폴더 생성**: 드롭 판정이 가끔 일관되지 않을 수 있음
> - 🛠️ **활발한 개발 진행 중**: 곧 개선 예정

## 문제 해결

### 자주 묻는 질문

**Q: 앱이 실행되지 않나요?**
A: macOS 26+를 확인하고 시스템 권한을 점검하세요.

**Q: 가져오기 버튼이 없나요?**
A: SettingsView.swift에 가져오기 기능이 있는지 확인하세요.

**Q: 검색이 동작하지 않나요?**
A: 앱 재스캔 또는 설정에서 데이터 초기화를 시도하세요.

**Q: 성능 문제가 있나요?**
A: 아이콘 캐시 설정을 확인하고 앱을 재시작하세요.

## 왜 LaunchOne인가요?

### Apple의 "Applications" 인터페이스와 비교
| 기능 | Applications (Tahoe) | LaunchOne |
|---------|---------------------|------------|
| 사용자 지정 정리 | ❌ | ✅ |
| 사용자 폴더 | ❌ | ✅ |
| 드래그 앤 드롭 | ❌ | ✅ |
| 시각적 관리 | ❌ | ✅ |
| 기존 데이터 가져오기 | ❌ | ✅ |
| 성능 | 느림 | 빠름 |

### 다른 Launchpad 대안과 비교
- **네이티브 통합**: Launchpad DB 직접 읽기
- **최신 아키텍처**: SwiftUI/SwiftData
- **의존성 없음**: 순수 Swift, 외부 라이브러리 없음
- **활발한 개발**: 정기 업데이트
- **리퀴드 글래스 디자인**: 고급 시각 효과

## 기여

기여를 환영합니다!

1. 저장소 Fork
2. 기능 브랜치 생성 (`git checkout -b feature/amazing-feature`)
3. 변경 사항 커밋 (`git commit -m 'Add amazing feature'`)
4. 브랜치 푸시 (`git push origin feature/amazing-feature`)
5. Pull Request 생성

### 개발 가이드
- Swift 스타일 규칙 준수
- 복잡한 로직에는 의미 있는 주석 추가
- 다양한 macOS 버전에서 테스트
- 하위 호환성 유지

## 앱 관리의 미래

Apple이 사용자 지정 가능한 인터페이스에서 멀어지는 가운데, LaunchOne은 사용자 제어와 개인화에 대한 커뮤니티의 의지를 나타냅니다. 우리는 사용자가 자신의 디지털 작업 공간을 어떻게 정리할지 스스로 결정해야 한다고 믿습니다.

**LaunchOne**은 단순한 Launchpad 대체가 아니라, 사용자 선택의 중요성을 보여주는 선언입니다.


---

**LaunchOne** — 앱 런처의 주도권을 되찾으세요 🚀

*개인화를 포기하지 않는 macOS 사용자를 위해 제작되었습니다.*

## 개발 도구

이 프로젝트는 다음 도구의 도움을 받아 개발되었습니다:
- Claude Code - AI 개발 어시스턴트
- Cursor
- Cursor Cli - 코드 생성 및 최적화
