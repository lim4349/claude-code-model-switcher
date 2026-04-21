# Claude Code Model Switcher

Claude Code CLI를 Claude, GLM, Kimi 설정으로 쉽게 전환해 실행할 수 있게 해주는 래퍼 도구입니다.

## 지원 모델 경로

- `claude` -> Anthropic Claude Code 기본 경로
- `claude-glm` -> Z.AI(GLM) 설정 적용
- `claude-kimi` -> Moonshot(Kimi) 설정 적용
- `claude-model` -> 설정/상태 관리 커맨드

GLM 설정은 현재 `glm-4.7`, `glm-5`, `glm-5.1` 3단 구성을 지원합니다.

## 설치

### Linux / macOS

```bash
git clone https://github.com/lim4349/claude-code-model-switcher.git
cd claude-code-model-switcher
./install.sh
```

### Windows PowerShell

```powershell
git clone https://github.com/lim4349/claude-code-model-switcher.git
cd claude-code-model-switcher
powershell -ExecutionPolicy Bypass -File install.ps1
```

## 설치 결과

설치 스크립트는 보통 다음 위치를 사용합니다.

- `~/.local/bin/claude`
- `~/.local/bin/claude-glm`
- `~/.local/bin/claude-kimi`
- `~/.local/bin/claude-model`
- `~/.claude/*_settings.json`

기존 alias 기반 사용자를 위해 `~/.claude/claude*.sh` shim도 같이 설치합니다.

## 사용법

```bash
claude-model setup
claude-model config
claude-model current
claude-model list

claude
claude-glm
claude-kimi
```

## 파일 구조

```text
claude-code-model-switcher/
├── install.sh
├── install.ps1
├── uninstall.sh
├── claude-code-model-switcher.sh
├── test.sh
└── wrappers/
    ├── claude
    ├── claude-glm
    └── claude-kimi
```

## 주의사항

- Claude Code 원본 실행 파일이 먼저 설치되어 있어야 합니다
- 설치 후 shell PATH에 `~/.local/bin`이 포함되어야 합니다
- provider별 토큰은 `~/.claude/*_settings.json`에 저장됩니다
