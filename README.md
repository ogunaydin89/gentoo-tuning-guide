# Tuning Guide

Step-by-step tuning guides for my PCs. Every step has a **Do**, a **Why** and a **Verify**, and everything is checked on the real machine before it is written as fact.

| Machine | Hardware | OS | Guide |
|---|---|---|---|
| Workstation PC | Ryzen 7 5700X, Radeon RX 6650 XT, 16 GB, A520 | Gentoo (OpenRC, KDE Plasma on Wayland) | [`gentoo/`](gentoo/README.md) |
| Gaming PC | Ryzen 7 5800X3D, Radeon RX 9070 XT, 32 GB, B550 | Arch Linux (KDE Plasma on Wayland) | [`arch/`](arch/README.md) |

The school PC (Windows 11) is not covered.

```bash
git clone https://github.com/ogunaydin89/tuning-guide.git
```

## Layout

```text
tuning-guide/
├── gentoo/     guide and reference files for the workstation PC
├── arch/       guide and reference files for the gaming PC
└── common/     files shared by both guides (shell setup)
```

## Notes for AI assistants

- Read the guide for the machine you are working on, then the reference files next to it. Detect the hardware first; never copy hardware-specific values (sensor chip, undervolt, kernel suffix) from one machine to another.
- Steps marked **[unverified]** have been written from documentation but not run on the machine. Run them, report the result, and only then remove the mark.
- Ask the user before any system change, and before committing or pushing to this repository.
- Never write passwords, tokens, API keys or seed words into this repository.

## License

[CC BY 4.0](LICENSE) © Ogün Aydın: free to use, share and adapt, with credit.
