# DisplayLink (evdi): NoSupportedRendererFormat — DVI-I-1 stays disabled on AMD+NVIDIA system

## Follow-up to previous discussion

niri detects the evdi device and connector correctly, but fails to create a DRM compositor for it.

## System

- Laptop: ASUS ROG Zephyrus G14 GA403WM
- Kernel: 6.19.6-arch1-3-g14
- niri: 25.11 (b35bcae)
- GPU 1: AMD Radeon 890M — iGPU (card1, renderD128)
- GPU 2: NVIDIA RTX 5060 Max-Q — dGPU (card0, renderD129)
- DisplayLink chip: 0x17e9:0x6000 (i-tec Thunderbolt dock)
- evdi: 1.14.15, displaylink: 6.1-1

## DRM devices

```
card0 → nvidia (dGPU, primary)
card1 → amdgpu (iGPU)
card2 → evdi (DisplayLink, platform device)
renderD128 → amdgpu
renderD129 → nvidia
```

## What happens

niri starts, selects renderD129 (nvidia) as primary render node. Later, when the dock is connected, card2 (evdi) is added. niri tries to initialize a renderer for it, fails, and the connector stays disabled.

## Relevant journal output

```
niri::backend::tty: using as the render node: "/dev/dri/renderD129"
niri::backend::tty: adding device: "/dev/dri/card0"
niri::backend::tty: this is the primary node
niri::backend::tty: got render node: renderD129
niri::backend::tty: initializing the primary renderer
niri::backend::tty: adding device: "/dev/dri/card1"
niri::backend::tty: got render node: renderD128
niri::backend::tty: new connector: eDP-1
niri::backend::tty: new connector: DP-2
niri::backend::tty: connecting connector: DP-2   ← works fine (Thunderbolt)
niri::backend::tty: connecting connector: eDP-1  ← works fine (built-in)

--- dock connected later ---

niri::backend::tty: adding device: "/dev/dri/card2"
niri::backend::tty: failed to initialize renderer, falling back to primary gpu: software EGL renderers are skipped
niri::backend::tty: new connector: DVI-I-1
niri::backend::tty: connecting connector: DVI-I-1
niri::backend::tty: couldn't reset HDR properties: couldn't find property: "HDR_OUTPUT_METADATA"
niri::backend::tty: couldn't get gamma properties: missing GAMMA_LUT property
niri::backend::tty: couldn't reset gamma: setting gamma is not supported
WARN niri::backend::tty: error creating DRM compositor, will try with invalid modifier: NoSupportedRendererFormat
WARN niri::backend::tty: error connecting connector: error creating DRM compositor
```

niri retries with invalid modifier — same result, connector stays disabled.

## dmesg (evdi side)

```
evdi: [I] (card2) Opened by Task 1210 (niri) of process 1210 (niri)
evdi: [I] (card2) Closed by Task 1210 (niri) of process 1210 (niri)
evdi: [I] (card2) Connector state: connected
evdi: [I] (card2) Edid property set
evdi: [I] (card2) Notifying display power state: off
```

## Root cause (my understanding)

niri uses nvidia (renderD129) as primary render node. evdi is a software renderer and does not support the pixel formats that the nvidia renderer expects — hence `NoSupportedRendererFormat`. If niri used AMD (renderD128) as primary render node, evdi would likely work, as AMD supports the necessary formats.

## Tried

- `NIRI_DRM_DEVICES=/dev/dri/card1:/dev/dri/card2`
- `NIRI_RENDER_NODE=/dev/dri/renderD128`
- `DRI_PRIME=pci-0000_65_00_0`
- `debug { render-drm-device "/dev/dri/card2" }` in config.kdl

None of these changed the primary render node — niri still picks renderD129 (nvidia).

## Question

Is there a way to force niri to use renderD128 (AMD iGPU) as the primary render node on a system with both AMD and NVIDIA GPUs? Or is this a case that needs to be handled differently on the niri/Smithay side?
