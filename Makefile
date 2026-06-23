# ── macOS ──────────────────────────────────────────────────────────────────
# Fork users: replace "galadriel" with your hostname (must match flake.nix).
darwin:
	nix build .#darwinConfigurations.galadriel.system \
	  --extra-experimental-features 'nix-command flakes'
	sudo ./result/sw/bin/darwin-rebuild switch --flake .#galadriel

# ── Linux (standalone home-manager) ────────────────────────────────────────
# Fork users: replace "dimitristsironis" with your username (must match flake.nix).
linux:
	home-manager switch --flake .#dimitristsironis

# ── Maintenance ─────────────────────────────────────────────────────────────
update:
	nix flake update

fmt:
	nix fmt
