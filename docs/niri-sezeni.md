# sezeni – ukládání a obnova sezení oken v niri

**Čeština** | [English](niri-sezeni.en.md)

Skript uloží otevřená okna (příkaz, pracovní adresář, výstup, workspace,
plovoucí/dlaždicový režim, velikost a pozici) do souboru a umí je znovu spustit
a rozmístit. Ukládají se jen okna kitty, zen a poznámek (`cz.poznamka.view`);
ostatní (noctalia, kando, kitty-float slovníky…) se ignorují.

## Rychlé použití

```sh
sezeni -a            # zeptá se na název a uloží aktuální sezení
sezeni -n            # obnoví výchozí sezení (naposledy uložené)
sezeni -n prace      # obnoví sezení „prace“
sezeni -l            # seznam sezení (* = výchozí)
sezeni -v prace      # nastaví „prace“ jako výchozí
```

Při startu niri se výchozí sezení obnoví samo – v `~/.config/niri/config.kdl`:

```kdl
spawn-sh-at-startup "~/.local/bin/sezeni -n"
```

(Dříve tam byly přímé spouštěče kitty, zen-browser a poznámek; ty se teď

## Soubory

- Skript: `dotfiles/sezeni/.local/bin/sezeni` → `~/.local/bin/sezeni` (stow)
- Sezení: `~/.config/niri/sezeni/<nazev>.json`
- Výchozí sezení: symlink `~/.config/niri/sezeni/vychozi.json` – po každém
  `sezeni -a` ukazuje na právě uložené sezení, změna přes `sezeni -v`.

## Volby / konfigurace (na začátku skriptu)

- `POVOLENE_APP_ID` – regex app-id oken, která se ukládají
  (`^(kitty|zen|cz\.poznamka\.view)$`). Další aplikaci přidáš sem.
- `UKLADANE_PROMENNE` – whitelist proměnných prostředí, které se uloží, pokud
  se liší od prostředí niri (např. `POZNAMKA_ZOOM=1.5`). Celé prostředí se
  záměrně neukládá, protože obsahuje tajné klíče a tokeny.
- `TIMEOUT_OKNA` (30 s) – jak dlouho se čeká na otevření okna.
- `TIMEOUT_DALSIHO` (5 s) – čekání na další okno téhož procesu.

`sezeni -a` v terminálu se ptá přes `input()`; bez terminálu (např. z klávesové
zkratky) použije `fuzzel --dmenu`. Zkratku lze přidat do `binds`:
`Mod+Shift+S { spawn-sh "~/.local/bin/sezeni -a"; }`

## Jak to funguje

**Uložení:** `niri msg --json windows/workspaces` → pro každé okno se z
`/proc/<pid>/cmdline` vezme příkaz a z `/proc/<pid>/cwd` adresář. Zvláštnosti:
- `kitty` – uloží se adresář shellu uvnitř terminálu (`kitty --directory …`);
  běžící program (např. Claude Code) se neobnoví, jen shell v tom adresáři.
- `zen-bin` – nahrazeno příkazem `zen-browser` (karty obnovuje Zen sám).

**Obnova:** nejdřív dlaždicová okna po sloupcích, pak plovoucí. Pro každé okno:
zaměří výstup a workspace, spustí příkaz, počká na nové okno se stejným app-id,
přesune ho na správný výstup/workspace, další dlaždice téhož sloupce přidá
`consume-or-expel-window-left`, nastaví šířku/výšku (`set-window-width/height`)
a plovoucím oknům pozici (`move-floating-window`). Nakonec zaměří okno, které
bylo zaměřené při uložení. Pokud výstup (monitor) není připojený, okno se
otevře na aktuálním výstupu.

## Závislosti

`niri` (testováno 26.04), `python3`, `fuzzel` (dotaz na název bez terminálu),
volitelně `notify-send`.

## Řešení problémů

- Výpis obnovy při startu: `journalctl --user -b | grep -i sezeni` (stderr
  skriptu), případně spusťte ručně `sezeni -n` v terminálu.
- Okno se neobjeví do 30 s → přeskočí se; zvyšte `TIMEOUT_OKNA`.
- Aplikace s jedním procesem a více okny (prohlížeč) může otevřít okna sama ze
  své relace; skript nejdřív 5 s čeká, jestli se další okno objeví, a teprve
  pak spustí příkaz znovu.
- Pořadí workspaců se ukládá jako index na výstupu; pojmenované workspace se
  obnovují podle jména.
