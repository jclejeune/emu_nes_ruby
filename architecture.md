nes_emulator/
├── Gemfile
├── Gemfile.lock
├── README.md
├── Rakefile
├── main.rb                          # Point d'entrée
│
├── lib/
│   ├── nes.rb                       # Classe principale NES (orchestrateur)
│   │
│   ├── bus/
│   │   └── bus.rb                   # Bus principal (CPU bus)
│   │
│   ├── cpu/
│   │   ├── cpu.rb                   # CPU 6502 (registres, cycle, step)
│   │   ├── instructions.rb          # Décodage + exécution des 151 opcodes
│   │   ├── addressing_modes.rb      # Les 13 modes d'adressage
│   │   ├── interrupts.rb            # NMI, IRQ, RESET
│   │   └── opcodes_table.rb         # Table de lookup [opcode] → {instruction, mode, cycles}
│   │
│   ├── ppu/
│   │   ├── ppu.rb                   # PPU 2C02 (logique principale)
│   │   ├── registers.rb             # $2000-$2007 (PPUCTRL, PPUMASK, etc.)
│   │   ├── renderer.rb              # Rendu des scanlines / pixels
│   │   ├── palette.rb               # Palette de couleurs NES (64 couleurs)
│   │   ├── oam.rb                   # Object Attribute Memory (sprites)
│   │   ├── nametable.rb             # Nametables / backgrounds
│   │   └── ppu_bus.rb               # Bus interne PPU (VRAM)
│   │
│   ├── apu/
│   │   ├── apu.rb                   # APU principal (mixer, frame counter)
│   │   ├── pulse_channel.rb         # Canal Pulse (×2)
│   │   ├── triangle_channel.rb      # Canal Triangle
│   │   ├── noise_channel.rb         # Canal Noise
│   │   ├── dmc_channel.rb           # Canal DMC (Delta Modulation)
│   │   ├── envelope.rb              # Envelope unit (partagé pulse/noise)
│   │   ├── sweep.rb                 # Sweep unit (pulse uniquement)
│   │   ├── length_counter.rb        # Length counter (partagé)
│   │   ├── linear_counter.rb        # Linear counter (triangle uniquement)
│   │   └── mixer.rb                 # Mixage audio des 5 canaux
│   │
│   ├── cartridge/
│   │   ├── cartridge.rb             # Chargement ROM + header iNES
│   │   ├── ines_parser.rb           # Parser du format iNES / NES 2.0
│   │   └── mappers/
│   │       ├── mapper.rb            # Classe de base (interface)
│   │       ├── mapper_000.rb        # NROM (mapper 0) - le plus simple
│   │       ├── mapper_001.rb        # MMC1 (SxROM)
│   │       ├── mapper_002.rb        # UxROM
│   │       ├── mapper_003.rb        # CNROM
│   │       └── mapper_004.rb        # MMC3 (TxROM)
│   │
│   ├── input/
│   │   ├── joypad.rb                # Contrôleur NES (8 boutons)
│   │   └── input_handler.rb         # Mapping clavier → joypad
│   │
│   └── display/
│       ├── screen.rb                # Interface d'affichage (abstraction)
│       ├── sdl_renderer.rb          # Rendu via ruby2d ou SDL2
│       └── frame_buffer.rb          # Buffer 256×240 pixels
│
├── roms/
│   ├── .gitkeep
│   └── nestest.nes                  # ROM de test CPU (ne pas commit)
│
├── test/
│   ├── test_helper.rb
│   ├── cpu/
│   │   ├── test_cpu.rb              # Tests unitaires CPU
│   │   ├── test_addressing_modes.rb # Tests modes d'adressage
│   │   ├── test_instructions.rb     # Tests par instruction
│   │   ├── test_interrupts.rb       # Tests NMI/IRQ
│   │   └── test_nestest.rb          # Validation contre nestest.log
│   ├── ppu/
│   │   ├── test_ppu.rb
│   │   └── test_registers.rb
│   ├── apu/
│   │   ├── test_apu.rb
│   │   ├── test_pulse.rb
│   │   └── test_triangle.rb
│   ├── bus/
│   │   └── test_bus.rb
│   ├── cartridge/
│   │   ├── test_ines_parser.rb
│   │   └── test_mapper_000.rb
│   └── integration/
│       └── test_full_system.rb      # Tests bout en bout
│
├── tools/
│   ├── disassembler.rb              # Désassembleur 6502 (debug)
│   ├── debugger.rb                  # Debugger interactif (step, breakpoints)
│   └── log_comparator.rb           # Compare les logs avec nestest.log
│
├── data/
│   ├── nes_palette.dat              # Palette couleurs NES (192 bytes)
│   ├── nestest.log                  # Log de référence nestest
│   └── opcodes.json                 # Table des opcodes (optionnel)
│
└── docs/
    ├── memory_map.md                # Documentation memory map
    ├── cpu_reference.md             # Référence instructions 6502
    ├── ppu_timing.md                # Timing PPU / scanlines
    └── apu_reference.md             # Référence APU (basé sur la doc 2A03)