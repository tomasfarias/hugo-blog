+++
title = "Ghostty's key tables are pretty cool"
author = ["Tomás Farías Santana"]
date = 2026-03-11T00:00:00+01:00
draft = false
+++

I have used many terminal emulators over the years and eventually settled on [Ghostty](https://ghostty.org) since it became publicly available not too long ago. I can't really recall what drew me to it, maybe I was just curious and wanted to see what the hype was about, or maybe the cute ghost logo drew me in. Regardless, I have stopped terminal emulator hopping for now, and have been enjoying Ghostty.

Naturally, I like to keep up with the latest version of Ghostty and something in the changelog of the latest release ([1.3.0](https://ghostty.org/docs/install/release-notes/1-3-0)) caught my eye: **key tables**.


## What is a key table? {#what-is-a-key-table}

From the release notes:

> Key tables enable tmux-like modal keybinding workflows. A key table is a named set of keybindings that can be activated or deactivated on demand. When a table is active, key presses are looked up within that table first, allowing you to create entirely separate keybinding modes


## Can I have an "Emacs mode"? {#can-i-have-an-emacs-mode}

A bit of background about me: I use [Emacs](https://www.gnu.org/software/emacs/) for most of my development work, mostly in GUI, and very infrequently pulling up the TUI. The reason for this is that I always had one or another issue trying to run Emacs as a TUI; One particularly annoying problem was that some keybind in my terminal emulator would always overlap with an Emacs keybind, and eat my input.

_"But now we have key tables! I can have a conflict-free 'Emacs mode' set of keybinds!"_ I thought immediately upon reading the changelog.

So, I downloaded the latest version, installed it, and pulled up the configuration file. The first challenge was that I needed to bind a key to enter the key table but I also wanted the same key to launch the Emacs TUI. So, I set up a keybind in [fish](https://fishshell.com/) to launch Emacs in the terminal, by including the following line in `~/.config/fish/config.fish`:

```nil
bind super-e execute 'emacsclient -nw'
```

And updated my Ghostty configuration to interpret the same `super+e` key combination as activating the `emacs` key table. Importantly, I also specified the `unconsumed:` prefix so that Ghostty doesn't swallow the input and stops it from getting to fish:

```nil
keybind = unconsumed:super+e=activate_key_table:emacs
```

Analogously, I needed a way to exit Emacs while simultaneously deactivating the key table. I can set the keybind to `ctrl+x>ctrl+c` which matches the default Emacs `save-buffer-kill-terminal` command to exit, and using `unconsumed:` once again we can tell Ghostty not to swallow the input so Emacs can receive it and exit:

```nil
keybind = emacs/unconsumed:ctrl+x>ctrl+c=deactivate_key_table
```

Finally, the last piece of the puzzle was ignoring every other Ghostty keybind so that Emacs can handle them. For this, the Ghostty update also included the `catch_all` special key, which, like you might imagine, _catches all_ not explicitly bound keys, and I combined this with the `unbind` action:

```nil
keybind = emacs/catch_all=unbind
```

And turns out that this ended up working pretty well! I use the same keybinds in Emacs and in Ghostty to split buffers/panels and there are no conflicts: while in "Emacs mode" only Emacs will split buffers, and Ghostty just ignores the input. Not everything was solved though: I do bind `ctrl+TAB` to cycle tabs in Ghostty and in Emacs, and I would have expected Ghostty to unbind this too while in "Emacs-mode". But this was not the case: Ghostty still cycles tabs even while in "Emacs-mode", as long as I have another Ghostty tab to cycle to.

I will continue to run this setup to see if I can iron out the last few annoyances. In the meantime, I am pretty happy with the results.


## In conclusion: Key tables are pretty cool {#in-conclusion-key-tables-are-pretty-cool}

Even though I live in the terminal, I am not an expert on everything that goes on inside a terminal emulator, so I'm not here to convince you Ghostty is the best there is[^fn:1], but I do hope I at least shared my excitement about key tables in Ghostty, because I certainly still am! In between writing this I re-created the Emacs font-size management as a key table in Ghostty:

```nil
## Font size key table
keybind = ctrl+x>ctrl+0=reset_font_size
### Based on Emacs keybinds to manage font size
keybind = font-size/==increase_font_size:1
keybind = font-size/-=decrease_font_size:1
keybind = font-size/0=reset_font_size
### Exit on any other input
keybind = font-size/catch_all=deactivate_key_table

### Increase/decrease and enter font-size mode
keybind = ctrl+x>ctrl+==increase_font_size:1
keybind = chain=activate_key_table:font-size
keybind = ctrl+x>ctrl+-=decrease_font_size:1
keybind = chain=activate_key_table:font-size
```

This uses another new feature, `chain`, to both increase/decrease the font-size once and enter the font-size-mode simultaneously. _Ghostty's `chain` is Pretty cool!_

[^fn:1]: I am terminally online and have seen a lot of discussions about which terminal emulator is better get really heated, and I have no intention to start one here.
