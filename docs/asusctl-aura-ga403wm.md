# Přidání podpory pro ASUS ROG Zephyrus G14 GA403WM do aura_support.ron

**Čeština** | [English](asusctl-aura-ga403wm.en.md)

## Kam poslat
GitLab: https://gitlab.com/asus-linux/asusctl (nebo GitHub fork
OpenGamingCollective/asusctl, podle toho, kde aktuálně žije upstream)

Cesta k souboru v repu: rog-aura/data/aura_support.ron

## Popis problému (pro issue/MR)

GA403WM (ROG Zephyrus G14, 2025, Aura type 19b6) chybí v aura_support.ron.
asusd proto padá na výchozí fallback jen se Static módem:

    [WARN  rog_aura::aura_detection] the aura_support.ron file has no
    entry for this model: GA403WM, 19b6. Using a default

Sourozenecké modely stejné generace (GA403UV, GA403WR, GA403WW) už v
souboru jsou, všechny se stejným layout_name "ga401q" a identickou
sadou basic_modes. GA403WM sdílí stejnou klávesnicovou/LED desku
(ITE Tech. Inc. ITE Device, HID 0B05:19B6) - liší se jen GPU/CPU
konfigurace v označení modelu, ne fyzické Aura ovládání.

Otestováno lokálně přes /etc/asusd/asusd_user_ledmodes.ron override
- se záznamem níže funguje Static, Breathe, RainbowCycle, RainbowWave
i Pulse bez chyb (žádné NotSupported D-Bus erory).

asusctl verze při testování: 6.3.8
Kernel: Arch Linux, aktuální

## Poznámka k fyzické AURA klávese (Fn+F4) - mimo rozsah tohoto MR

Tento MR řeší pouze to, že asusd nezná model GA403WM v aura_support.ron,
takže software (CLI/GUI) může nastavit jen Static efekt. Nesouvisí s tím
ale samostatný problém: fyzická AURA klávesa (Fn+F4) na klávesnici
nedělá nic, ani po opravě výše.

Zjištěno pomocí hid-recorder na /dev/hidraw0 (ITE Tech. Inc. ITE
Device, HID 0B05:19B6): klávesa při stisku posílá vlastní 2bajtový
HID report - Report ID 0x5a (90), hodnota 0xb3 při stisku, 0x00 při
uvolnění, přes samostatnou vendor-specific kolekci (Usage Page
0xff31, Usage 0x76). Kernelový driver hid-asus.c tenhle report ID
vůbec nezpracovává - stará se pouze o Report ID 1 (standardní
klávesnice), kde se řeší i filtrace spurious kódů a nedávno přidaná
podpora Fn+F5 (fan key, viz patch ze stycnia 2026: "HID: asus: Add
Fn+F5 fan control key support").

Zajímavé je, že hodnota 0xb3 přesně odpovídá staršímu ACPI/WMI
keymapu `{ KE_KEY, 0xB3, { KEY_PROG4 } } /* AURA */` z
asus-nb-wmi.c - jen tenhle model posílá stejnou hodnotu jinou
(HID vendor) cestou, kterou asus-nb-wmi.c ani hid-asus.c
nepokrývají.

Dokud tohle nedostane kernel patch (analogicky k Fn+F5), klávesa
zůstane nefunkční pro kohokoli, kdo nenapíše vlastní userspace
workaround čtoucí /dev/hidraw přímo. Pro zájemce mám funkční
Python/systemd řešení (čtení raw HID reportů, spouští
`asusctl aura effect --next-mode` na stisk) - rád ho sdílím
samostatně, pokud bude o něj zájem v diskuzi k tomuto MR nebo
na asus-linux.org.

## Navrhovaný diff pro aura_support.ron

Přidat vedle existujících záznamů GA403UV/GA403WR/GA403WW:

    (
        device_name: "GA403WM",
        product_id: "",
        layout_name: "ga401q",
        basic_modes: [Static, Breathe, RainbowCycle, RainbowWave, Pulse],
        basic_zones: [],
        advanced_type: r#None,
        power_zones: [Keyboard],
    ),

## Postup pro poslání (GitLab web UI, bez nutnosti gitu lokálně)

1. Otevři rog-aura/data/aura_support.ron v repu na gitlab.com
2. Klikni Edit (tužtička) - GitLab automaticky vytvoří fork do tvého
   účtu, pokud nemáš přímý zápis
3. Najdi sekci s GA403UV / GA403WR / GA403WW (řazeno abecedně podle
   device_name, takže GA403WM patří mezi GA403WR a GA403WW, nebo
   klidně hned za GA403UV)
4. Vlož nový záznam z diffu výše
5. Dole zvol "Commit changes" -> "Start a new merge request"
6. Titulek MR: "Add aura support for ASUS ROG Zephyrus G14 GA403WM"
7. Do popisu vlož text z "Popis problému" výše
