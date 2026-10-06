#!/usr/bin/env bash
# .claude/ 의 하네스(스킬, 에이전트)를 평가용 플러그인 디렉터리로 복사한다.
# 이유: claude plugin eval 은 plugin.json 이 있는 플러그인 디렉터리만 평가하고, 플러그인은
# 자기 디렉터리 밖의 파일(심볼릭 링크 포함)을 구성요소로 선언할 수 없다. 그래서 복사본이 필요하다.
# 원본은 항상 .claude/ 이고, 이 복사본은 직접 고치지 않는다. 고치면 다음 sync 때 덮어써진다.
# 사용법: 저장소 루트에서 bash harness-eval/sync.sh
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/harness-eval/mvp-harness"

rm -rf "$DEST/skills" "$DEST/agents"
mkdir -p "$DEST/skills" "$DEST/agents"
cp -R "$ROOT/.claude/skills/mvp-orchestrator" "$DEST/skills/"
cp -R "$ROOT/.claude/skills/mvp-scoping" "$DEST/skills/"
cp -R "$ROOT/.claude/skills/mvp-build-verify" "$DEST/skills/"
cp "$ROOT/.claude/agents/"mvp-*.md "$DEST/agents/"
echo "synced: $(ls "$DEST/skills" | tr '\n' ' ') / $(ls "$DEST/agents" | tr '\n' ' ')"
