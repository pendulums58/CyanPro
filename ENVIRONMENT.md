# OricaAI EDOPro — 로컬 환경 요구사항

git에 포함되지 않는 로컬 설정 4건. 빌드·실행에 모두 필요.

---

## 1. `has_core: false` (TestBuild)

**파일**: `D:\ProjectIgnis-TestBuild\config\configs.json`

delta-bagooska 리포 항목에서 `"has_core": false`로 설정.

```json
{
    "url": "https://github.com/ProjectIgnis/DeltaBagooska",
    "has_core": false,
    "should_update": true
}
```

**이유**: `has_core: true`이면 리포의 바닐라 `ocgcore.dll`이 정적 링크된 코어를 런타임에 교체한다. `should_update: true`와 결합되면 DLL을 삭제해도 실행 시 git pull로 복원된다.

---

## 2. LTO 비활성 (빌드)

```
/p:WholeProgramOptimization=false
```

**이유**: LTO 활성 시 링커가 힙 메모리를 초과하여 빌드 실패. `/m:1`과 병용 권장.

---

## 3. DXSDK_DIR 환경변수 (premake)

premake5 실행 전 설정 필요:

```powershell
$env:DXSDK_DIR = "C:\Program Files (x86)\Microsoft DirectX SDK (June 2010)"
```

**이유**: premake5가 DirectX SDK 경로를 참조하여 프로젝트 파일을 생성한다. 미설정 시 premake 실행 실패.

---

## 4. OCG 버전 가드 (코어 + 클라이언트)

**파일**:
- `ocgcore/ocgapi_types.h`: `OCG_VERSION_MINOR 1`
- `gframe/ocgapi_types.h`: `OCG_VERSION_MINOR 1`

**이유**: 바닐라 DLL(11.0)을 `check_api_version()`에서 거부하기 위해 MINOR를 1로 올림. 두 파일의 값이 반드시 일치해야 한다 — 코어 쪽이 보고하는 버전, 클라이언트 쪽이 기대하는 버전.

---

## 빌드 명령 (전체)

```powershell
$env:DXSDK_DIR = "C:\Program Files (x86)\Microsoft DirectX SDK (June 2010)"
& "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" `
    "build\ygo.sln" `
    /p:Configuration=Release /p:Platform=Win32 `
    /p:WholeProgramOptimization=false /m:1
```

출력: `bin\release\ygopro.exe` (~10.7 MB)
