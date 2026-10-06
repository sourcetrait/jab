# SPEC.md

System specifications for Jab that lock-in system requirements.

Nomenclature: `{resolution}K{components}{compatability}`
- Resolution
  - `1K` 1080p
  - `2k` QHD
  - `4K` 4K
- Components
  - `/[A-Z]/` Ascending; Minimum hardware components and resources
- Compatability
  - `/[0-9]+/` Ascending; Minimum compatability (eg, RVA22 vs RVA23)

## 1KA1
- ISA: RISC-V
- ISA Profile: RVA23
- Cores: 4
- Clock: 2Ghz
- RAM: 4GB
- GPU: None
- VRAM: None
- Display: 1080p (1920x1080, 16:9)
- FPS: 60
### 1KB1
- Cores: 8
## 2KA1
- ISA: RISC-V
- ISA Profile: RVA23
- Cores: 4
- Clock: 2Ghz
- RAM: 8GB
- GPU: Vulkan
- VRAM: 4GB
- Display: 1440p (2560x1440, 16:9)
- FPS: 60
### 2KB1
- Cores: 8
## 4KA1
- ISA: RISC-V
- ISA Profile: RVA23
- Cores: 8
- Clock: 2Ghz
- RAM: 8GB (min)
- GPU: Vulkan
- VRAM: 12GB (min)
- Display: 4K (3840x2160, 16:9) (exact)
- FPS: 60 (exact)
