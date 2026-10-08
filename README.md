# CyanPro

EDOPro(Project Ignis)의 수정판입니다. 오리카 전용 시스템
(액세스 · 하이잭 · 페어링 · 기프트 · 키)을 엔진 차원에서 지원하도록
2026년에 수정되었습니다.

이 소프트웨어는 AGPL-3.0-or-later 로 배포됩니다.

## 빌드

upstream 빌드 의존성(irrlicht, libgit2, freetype, openssl 등)은
[EDOPro 빌드 가이드](https://github.com/edo9300/edopro/wiki)를 참조하세요.

### 요구사항

- Visual Studio 2022 (v143 toolset)
- vcpkg (`x86-windows-static` triplet)

### 프로젝트 생성

```
.\premake5.exe vs2022 --sound=miniaudio --no-direct3d
```

### 빌드

```
msbuild.exe -m -p:Configuration=Release -p:Platform=Win32 .\build\ygo.sln -t:ygoprodll
```

출력: `bin\release\cyanpro.exe`

### 참고

| 설정 | 위치 | 설명 |
|------|------|------|
| `--sound=miniaudio` | premake 옵션 | miniaudio 오디오 백엔드 활성화 |
| `--no-direct3d` | premake 옵션 | DirectX SDK가 없는 환경용. DXSDK_DIR이 설정되어 있으면 생략 가능 |
| LTO/LTCG | `premake5.lua:291-297` | 주석 처리로 비활성화됨. vcpkg 라이브러리가 다른 컴파일러 버전으로 빌드되어 LTCG 비호환 |
| `targetname "cyanpro"` | `gframe/premake5.lua:281` | 출력 파일명 |
| `cppdialect "C++17"` | `gframe/premake5.lua:3` | irrlicht 호환 |

## 원저작권

- Copyright (c) 2010-2015, Argon Sun (Fluorohydride)
- Copyright (c) 2017-2025, Edoardo Lolletti (edo9300)

## 수정

- Copyright (c) 2026, 시안

## 관련 리포지토리

- [CyanCore](https://github.com/pendulums58/CyanCore) — 오리카 시스템을 지원하는 코어 엔진

## 원본

- [EDOPro](https://github.com/edo9300/edopro)
- [ygopro-core](https://github.com/edo9300/ygopro-core)
- [YGOPro](https://github.com/Fluorohydride/ygopro)

## License

CyanPro is free/libre and open source software licensed under the GNU Affero General Public License, version 3 or later.
Please see [COPYING](COPYING) and [LICENSE](LICENSE) for more details.

Yu-Gi-Oh! is a trademark of Shueisha and Konami. This project is not affiliated with or endorsed by Shueisha or Konami.
