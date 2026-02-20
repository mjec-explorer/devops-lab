# Decisions (Phase 0)

## Environment choice
I chose WSL2 Ubuntu (22.04) as my DevOps lab environment because it gives me a real Linux userland while still being easy to run locally.

## Why this choice
- Closer to production-style Linux troubleshooting than Windows-native tools
- Easy to run Docker/Compose, scripts, and CLI tooling
- Fast iteration without paying for cloud resources

## Tradeoffs / risks
- Networking can be quirky (localhost vs WSL vs Windows ports)
- Performance is worse if files live under /mnt/c (Windows filesystem)

## Rules going forward
- Keep the project inside the Linux filesystem (e.g., ~/devops_lab), not /mnt/c/...
