# Claude Code Model Switcher - 개발 가이드

## 개요

Claude Code 실행 설정을 provider별로 분리하는 wrapper 프로젝트입니다.

## 핵심 파일

- `install.sh`: POSIX 계열 설치 스크립트
- `install.ps1`: Windows 설치 스크립트
- `claude-code-model-switcher.sh`: 관리 커맨드 구현
- `wrappers/claude*`: 실제 실행 래퍼
- `uninstall.sh`: 제거 스크립트

## 지원 provider

- Anthropic Claude
- Z.AI GLM (`glm-4.7`, `glm-5`, `glm-5.1`)
- Moonshot Kimi

## 검증 포인트

```bash
./test.sh
./install.sh
claude-model current
claude-glm --help
```

## 작업 시 유의사항

- wrapper는 직접 Claude 원본 바이너리를 찾는 로직을 포함하므로 PATH 처리 변경에 주의
- Linux/macOS와 Windows 설치 로직은 동등하게 유지해야 함
- README에 적는 모델명과 실제 wrapper 기본값을 맞출 것
