.PHONY: all fmt lint validate test test-routing test-intent test-suricata clean help

all: fmt test validate

help:
	@echo "Available commands:"
	@echo "  make fmt           - Format all Terraform files recursively"
	@echo "  make validate      - Validate all Terraform module schemas"
	@echo "  make test          - Run all test suites (SCP, Routing, Intent, Suricata)"
	@echo "  make test-intent   - Run architecture intent & compliance tests"
	@echo "  make test-routing  - Run Transit Gateway deterministic routing simulator"
	@echo "  make clean         - Clean temporary terraform and python caches"

fmt:
	terraform fmt -recursive

test: test-scp test-routing test-intent test-suricata

test-scp:
	python3 tests/test_scp_policies.py -v

test-routing:
	python3 tests/test_tgw_routing_simulator.py -v

test-intent:
	python3 tests/test_landing_zone_intent.py -v

test-suricata:
	python3 tests/test_suricata_rules.py -v

validate:
	./scripts/validate_landing_zone.sh

clean:
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name ".terraform.lock.hcl" -delete 2>/dev/null || true
