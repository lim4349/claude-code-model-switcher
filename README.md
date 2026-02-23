# Claude Code Model Switcher

Claude Code CLI에서 다양한 AI 모델을 쉽게 전환해서 사용할 수 있는 도구입니다.

---

## 설치

### 전제 조건

```bash
npm install -g @anthropic-ai/claude-code
```

### 설치

**Linux / macOS:**

```bash
git clone https://github.com/lim4349/claude-code-model-switcher.git
cd claude-code-model-switcher
./install.sh
```

**Windows (PowerShell):**

```powershell
git clone https://github.com/lim4349/claude-code-model-switcher.git
cd claude-code-model-switcher
powershell -ExecutionPolicy Bypass -File install.ps1
```

### 설치 후

**Linux / macOS:**

```bash
source ~/.bashrc   # 또는 source ~/.zshrc
```

**Windows:**

설치 완료 후 안내되는 명령어를 실행하세요:

```powershell
$env:Path = "C:\Users\사용자명\.local\bin;$env:Path"
```

새 PowerShell 창을 열면 자동으로 적용됩니다.

---

## 사용법

### 1. API 키 설정

```bash
claude-model setup
```

GLM, Kimi 중 원하는 모델의 API 키를 입력하세요.

### 2. 모델 실행

| 명령어 | 모델 | 제공업체 |
|--------|------|----------|
| `claude` | Claude Sonnet 4.5 | Anthropic |
| `claude-glm` | GLM 4.7 / 5 | Z.AI |
| `claude-kimi` | Kimi 2.5 | Moonshot AI |

**참고**: GLM 사용 시 Claude Code 낸부에서 `/model glm-4.7` 또는 `/model glm-5` 명령으로 모델을 전환할 수 있습니다.

```bash
claude          # Claude
claude-glm      # GLM
claude-kimi     # Kimi
```

### 3. 관리 명령어

```bash
claude-model setup      # API 키 설정 (반복 가능)
claude-model config     # 개별 모델 설정
claude-model current    # 현재 모델 확인
claude-model list       # 사용 가능한 모델 목록
```

---

## API 키 발급

| 제공업체 | 링크 |
|----------|------|
| **Claude** | https://console.anthropic.com/ |
| **GLM** | https://open.bigmodel.cn/ |
| **Kimi** | https://platform.moonshot.ai/ |

---

## 삭제

**Linux / macOS:**

```bash
cd claude-code-model-switcher
./uninstall.sh
```

**Windows:**

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\.local\bin\claude*"
Remove-Item "$env:USERPROFILE\.claude\claude*.sh"
Remove-Item "$env:USERPROFILE\.claude\*_settings.json"
```

API 키 설정 파일은 삭제되지 않습니다. 수동으로 삭제하려면:

```bash
rm ~/.claude/zai_settings.json    # GLM 설정
rm ~/.claude/kimi_settings.json   # Kimi 설정
```

---

## 라이선스

MIT
