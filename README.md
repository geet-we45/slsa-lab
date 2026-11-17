# SLSA Provenance Lab

> **Use this template** to create **your own public** copy, then work from a Linux/EC2 terminal with `gh`.

## Levels

| Level | Guarantee |
|---|---|
| L0 | No provenance |
| L1 | Provenance exists (may be unsigned) |
| L2 | Provenance signed by the build platform |
| L3 | Hardened / isolated builder; signer unreachable by tenant steps |

There is **no Build L4**. A valid signature means **this builder produced it**, not **this code is safe**.

## Layout

```
app/                         Go hello binary (+ harmless build-tag "backdoor")
.github/workflows/           release.yml (l2-clean, l2-pwned, l3, l3-forge)
.github/actions/fancy-lint/  simulated compromised action (training only)
scripts/                     lab exercises, verify, deploy, scoreboard
provision/ec2-setup.sh       install go, git, gh, jq on the lab machine
lab.env                      org / builder settings (already configured)
```