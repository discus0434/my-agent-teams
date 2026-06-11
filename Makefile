.PHONY: post-change smoke harness-test team-identity team-bootstrap team-start team-stop team-status team-send team-submit inbox claim report review integrate memory-list memory-append

post-change:
	@git diff --check -- .

smoke:
	@echo "Define project smoke during team-bootstrap." >&2
	@exit 1

harness-test:
	@bash -n .agents/scripts/*.sh
	@bash -n .agents/tests/harness/*.sh
	./.agents/tests/harness/team_lifecycle_test.sh

team-identity:
	./.agents/scripts/team_identity.sh

team-bootstrap:
	./.agents/scripts/team_bootstrap.sh

team-start:
	./.agents/scripts/team_start.sh --restart

team-stop:
	./.agents/scripts/team_stop.sh

team-status:
	./.agents/scripts/team_status.sh

team-send:
	@test -n "$(TO)" || { echo "TO is required" >&2; exit 2; }
	@test -n "$(TYPE)" || { echo "TYPE is required" >&2; exit 2; }
	./.agents/scripts/team_send.sh "$(TO)" "$(TYPE)" "$(TASK)" "$(BODY)"

team-submit:
	@test -n "$(AGENT)" || { echo "AGENT is required" >&2; exit 2; }
	./.agents/scripts/team_submit.sh "$(AGENT)"

inbox:
	@test -n "$(AGENT)" || { echo "AGENT is required" >&2; exit 2; }
	@if [ -n "$(MARK)" ]; then \
		./.agents/scripts/team_inbox.sh "$(AGENT)" --mark "$(MARK)"; \
	else \
		./.agents/scripts/team_inbox.sh "$(AGENT)"; \
	fi

claim:
	@test -n "$(TASK)" || { echo "TASK is required" >&2; exit 2; }
	@test -n "$(AGENT)" || { echo "AGENT is required" >&2; exit 2; }
	./.agents/scripts/team_claim.sh "$(TASK)" "$(AGENT)"

report:
	@test -n "$(TASK)" || { echo "TASK is required" >&2; exit 2; }
	@test -n "$(AGENT)" || { echo "AGENT is required" >&2; exit 2; }
	@test -n "$(STATUS)" || { echo "STATUS is required" >&2; exit 2; }
	./.agents/scripts/team_report.sh "$(TASK)" "$(AGENT)" "$(STATUS)"

review:
	@test -n "$(TASK)" || { echo "TASK is required" >&2; exit 2; }
	@test -n "$(AGENT)" || { echo "AGENT is required" >&2; exit 2; }
	./.agents/scripts/team_review.sh "$(TASK)" "$(AGENT)"

integrate:
	@test -n "$(TASK)" || { echo "TASK is required" >&2; exit 2; }
	@test -n "$(AGENT)" || { echo "AGENT is required" >&2; exit 2; }
	./.agents/scripts/team_integrate.sh "$(TASK)" "$(AGENT)"

memory-list:
	./.agents/scripts/team_memory_update.sh list

memory-append:
	@test -n "$(PROPOSAL)" || { echo "PROPOSAL is required" >&2; exit 2; }
	./.agents/scripts/team_memory_update.sh append "$(PROPOSAL)"
