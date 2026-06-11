.PHONY: post-change smoke team-start team-stop team-status team-send team-submit inbox claim report review integrate

post-change:
	@bash -n scripts/*.sh
	@git diff --check -- .

smoke:
	./scripts/team_smoke_test.sh

team-start:
	./scripts/team_start.sh --restart

team-stop:
	./scripts/team_stop.sh

team-status:
	./scripts/team_status.sh

team-send:
	@test -n "$(TO)" || { echo "TO is required" >&2; exit 2; }
	@test -n "$(TYPE)" || { echo "TYPE is required" >&2; exit 2; }
	./scripts/team_send.sh "$(TO)" "$(TYPE)" "$(TASK)" "$(BODY)"

team-submit:
	@test -n "$(AGENT)" || { echo "AGENT is required" >&2; exit 2; }
	./scripts/team_submit.sh "$(AGENT)"

inbox:
	@test -n "$(AGENT)" || { echo "AGENT is required" >&2; exit 2; }
	@if [ -n "$(MARK)" ]; then \
		./scripts/team_inbox.sh "$(AGENT)" --mark "$(MARK)"; \
	else \
		./scripts/team_inbox.sh "$(AGENT)"; \
	fi

claim:
	@test -n "$(TASK)" || { echo "TASK is required" >&2; exit 2; }
	@test -n "$(AGENT)" || { echo "AGENT is required" >&2; exit 2; }
	./scripts/team_claim.sh "$(TASK)" "$(AGENT)"

report:
	@test -n "$(TASK)" || { echo "TASK is required" >&2; exit 2; }
	@test -n "$(AGENT)" || { echo "AGENT is required" >&2; exit 2; }
	@test -n "$(STATUS)" || { echo "STATUS is required" >&2; exit 2; }
	./scripts/team_report.sh "$(TASK)" "$(AGENT)" "$(STATUS)"

review:
	@test -n "$(TASK)" || { echo "TASK is required" >&2; exit 2; }
	@test -n "$(AGENT)" || { echo "AGENT is required" >&2; exit 2; }
	./scripts/team_review.sh "$(TASK)" "$(AGENT)"

integrate:
	@test -n "$(TASK)" || { echo "TASK is required" >&2; exit 2; }
	@test -n "$(AGENT)" || { echo "AGENT is required" >&2; exit 2; }
	./scripts/team_integrate.sh "$(TASK)" "$(AGENT)"
