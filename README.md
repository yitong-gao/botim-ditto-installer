> # ⚠️ DEPRECATED — this installer is no longer needed
>
> The plugin repo [**`yitong-gao/botim-ditto`**](https://github.com/yitong-gao/botim-ditto) is now **public**, so you can clone it directly — no installer, no GitHub invite, no auth:
>
> ```bash
> git clone https://github.com/yitong-gao/botim-ditto.git ~/.claude/plugins/botim-ditto
> ```
>
> Then follow [`ONBOARDING.md`](https://github.com/yitong-gao/botim-ditto/blob/main/skills/botim-ditto/ONBOARDING.md) in that repo. This repo is archived and kept only for reference.
>
> ---

# botim-ditto installer

One-line installer for the **botim-ditto** Claude Code plugin (Figma → Ditto sync, used by the botim design team). The plugin repo itself is private — this public repo exists only so the installer can be fetched without auth:

```bash
curl -fsSL https://raw.githubusercontent.com/yitong-gao/botim-ditto-installer/main/install.sh | bash
```

The script contains no secrets. Cloning the actual plugin still requires a GitHub invite to the private repo — if you're on the botim design team and don't have one, ask the design toolkit maintainers.

> ⚠️ Auto-published from `botim-design-toolkit` by `tools/publish-standalone.sh` — do not edit here; changes will be overwritten.
