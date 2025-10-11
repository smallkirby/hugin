/// System registers.
pub const SystemReg = enum {
    currentel,
    tpidr_el0,
    tpidr_el1,
    tpidr_el2,
    tpidr_el3,
    tcr_el1,
    tcr_el2,
    tcr_el3,
    elr_el1,
    elr_el2,
    elr_el3,
    ttbr0_el2,
    ttbr1_el2,
    mair_el1,
    mair_el2,
    mair_el3,
    daif,
    spsr_el1,
    spsr_el2,
    spsr_el3,
    hcr_el2,
    cnthctl_el2,
    id_aa64mmfr0_el1,
    vtcr_el2,
    vttbr_el2,
    vbar_el1,
    vbar_el2,
    vbar_el3,
    esr_el1,
    esr_el2,
    esr_el3,
    sctlr_el1,
    sctlr_el2,
    sctlr_el3,
    far_el1,
    far_el2,
    far_el3,
    hpfar_el2,
    sp_el0,
    sp_el1,
    sp_el2,
    sp_el3,
    midr_el1,
    vpidr_el2,
    mpidr_el1,
    vmpidr_el2,
    cntvoff_el2,

    icc_ctlr_el1,
    icc_sre_el1,
    icc_sre_el2,
    icc_sre_el3,
    icc_pmr_el1,
    icc_bpr0_el1,
    icc_bpr1_el1,
    icc_igrpen1_el1,
    icc_iar1_el1,
    icc_dir_el1,
    icc_eoir1_el1,
    icc_sgi1r_el1,
    ich_lr0_el2,
    ich_lr1_el2,
    ich_lr2_el2,
    ich_lr3_el2,
    ich_lr4_el2,
    ich_lr5_el2,
    ich_lr6_el2,
    ich_lr7_el2,
    ich_lr8_el2,
    ich_lr9_el2,
    ich_lr10_el2,
    ich_lr11_el2,
    ich_lr12_el2,
    ich_lr13_el2,
    ich_lr14_el2,
    ich_lr15_el2,
    ich_vtr_el2,
    ich_eisr_el2,
    ich_hcr_el2,

    /// Get the string representation of the system register.
    pub fn str(comptime self: SystemReg) []const u8 {
        return @tagName(self);
    }

    /// Get the type of the system register.
    pub fn Type(comptime self: SystemReg) type {
        return switch (self) {
            .currentel => CurrentEl,
            .tpidr_el0, .tpidr_el1, .tpidr_el2, .tpidr_el3 => Tpidr,
            .elr_el1, .elr_el2, .elr_el3 => Elr,
            .ttbr0_el2 => Ttbr0,
            .ttbr1_el2 => Ttbr1,
            .mair_el1, .mair_el2, .mair_el3 => Mair,
            .tcr_el1, .tcr_el2, .tcr_el3 => Tcr,
            .daif => Daif,
            .spsr_el1, .spsr_el2, .spsr_el3 => Spsr,
            .hcr_el2 => HcrEl2,
            .cnthctl_el2 => Cnthctl,
            .id_aa64mmfr0_el1 => IdAa64Mmfr0,
            .vtcr_el2 => VtcrEl2,
            .vttbr_el2 => VttbrEl2,
            .vbar_el1, .vbar_el2, .vbar_el3 => Vbar,
            .esr_el1, .esr_el2, .esr_el3 => Esr,
            .sctlr_el1, .sctlr_el2, .sctlr_el3 => Sctlr,
            .far_el1, .far_el2, .far_el3 => Far,
            .hpfar_el2 => Hpfar,
            .sp_el0, .sp_el1, .sp_el2, .sp_el3 => Sp,
            .midr_el1 => Midr,
            .vpidr_el2 => Vpidr,
            .mpidr_el1 => Mpidr,
            .vmpidr_el2 => Vmpidr,
            .cntvoff_el2 => Cntvoff,
            .icc_ctlr_el1 => IccCtlr,
            .icc_sre_el1, .icc_sre_el2, .icc_sre_el3 => IccSre,
            .icc_pmr_el1 => IccPmr,
            .icc_bpr0_el1, .icc_bpr1_el1 => IccBpr,
            .icc_igrpen1_el1 => IccIgrpen1El1,
            .icc_iar1_el1 => IccIar1El1,
            .icc_dir_el1 => IccDirEl1,
            .icc_eoir1_el1 => IccEoir1El1,
            .icc_sgi1r_el1 => IccSgi1r,
            .ich_lr0_el2, .ich_lr1_el2, .ich_lr2_el2, .ich_lr3_el2, .ich_lr4_el2, .ich_lr5_el2, .ich_lr6_el2, .ich_lr7_el2, .ich_lr8_el2, .ich_lr9_el2, .ich_lr10_el2, .ich_lr11_el2, .ich_lr12_el2, .ich_lr13_el2, .ich_lr14_el2, .ich_lr15_el2 => IchLr,
            .ich_vtr_el2 => IchVtr,
            .ich_eisr_el2 => IchEisr,
            .ich_hcr_el2 => IchHcr,
        };
    }
};

/// Register context.
pub const Context = extern struct {
    x0: u64,
    x1: u64,
    x2: u64,
    x3: u64,
    x4: u64,
    x5: u64,
    x6: u64,
    x7: u64,
    x8: u64,
    x9: u64,
    x10: u64,
    x11: u64,
    x12: u64,
    x13: u64,
    x14: u64,
    x15: u64,
    x16: u64,
    x17: u64,
    x18: u64,
    x19: u64,
    x20: u64,
    x21: u64,
    x22: u64,
    x23: u64,
    x24: u64,
    x25: u64,
    x26: u64,
    x27: u64,
    x28: u64,
    x29: u64,
    x30: u64,
    _pad: u64,
};

/// CurrentEL.
///
/// Current Exception Level Register.
pub const CurrentEl = packed struct(u64) {
    /// Reserved.
    _reserved0: u2 = 0,
    /// Current exception level.
    el: u2,
    /// Reserved.
    _reserved1: u60 = 0,
};

/// TPIDR_ELx.
///
/// Software Thread ID Register.
pub const Tpidr = packed struct(u64) {
    tid: u64,
};

/// SPSR_ELx.
///
/// Saved Program Status Register.
pub const Spsr = packed struct(u64) {
    /// Aarch64 Exception level and selected Stack Pointer.
    ///
    /// - 0b0000: EL0
    /// - 0b0100: EL1 using SP_EL0 (ELt)
    /// - 0b0101: EL1 using SP_EL1 (EL1h)
    /// - 0b1000: EL2 using SP_EL0 (EL2t)
    /// - 0b1001: EL2 using SP_EL1 (EL2h)
    m_elsp: u4,
    /// Execution state.
    m_es: u1,
    /// Reserved.
    _reserved0: u1 = 0,
    /// FIQ interrupt mask.
    f: bool,
    /// IRQ interrupt mask.
    i: bool,
    /// SError exception mask.
    a: bool,
    /// Debug exception mask.
    d: bool,
    /// When FEAT_BTI is implemented, Branch Type Indicator.
    btype: u2,
    /// When FEAT_SSBS is implemented, Speculative Store Bypass.
    ssbs: bool,
    /// When FEAT_NMI is implemented, All IRQ or FIQ interrupts mask.
    allint: bool,
    /// Reserved.
    _reserved1: u6 = 0,
    /// Illegal Execution state.
    il: bool,
    /// Software Step.
    ss: bool,
    /// When FEAT_PAN is implemented, Privileged Access Never.
    pan: bool,
    /// When FEAT_UAO is implemented, User Access Override.
    uao: bool,
    /// When FEAT_DIT is implemented, Data Independent Timing.
    dit: bool,
    /// When FEAT_MTE is implemented, Tag Check Override.
    tco: bool,
    /// Reserved.
    _reserved2: u2 = 0,
    /// Overflow Condition flag.
    v: bool,
    /// Carry Condition flag.
    c: bool,
    /// Zero Condition flag.
    z: bool,
    /// Negative Condition flag.
    n: bool,
    /// When FEAT_EBEP is implemented PMU exception mask bit.
    pm: bool,
    /// When FEAT_SEBEP is implemented, PMU exception pending bit.
    ppend: bool,
    /// When FEAT_GCS is implemented, Exception return state lock.
    exlock: bool,
    /// Reserved.
    _reserved3: u29 = 0,
};

/// ELR_ELx.
///
/// Exception Link Register.
pub const Elr = packed struct(u64) {
    /// Return address.
    addr: u64,
};

/// TTBR0_EL2.
pub const Ttbr0 = packed struct(u64) {
    /// Common not Private.
    cnp: bool,
    /// Translation table base address.
    baddr: u47,
    /// ASIS for the translation table base address.
    asid: u16,

    pub fn from(base: u64) Ttbr0 {
        return .{
            .cnp = false,
            .baddr = @intCast(base >> 1),
            .asid = 0,
        };
    }

    pub fn addr(self: Ttbr0) usize {
        return @as(usize, self.baddr) << 1;
    }
};

/// TTBR1_EL2.
pub const Ttbr1 = packed struct(u64) {
    /// Common not Private.
    cnp: bool,
    /// Translation table base address.
    baddr: u47,
    /// ASIS for the translation table base address.
    asid: u16,

    pub fn from(base: u64) Ttbr1 {
        return .{
            .cnp = false,
            .baddr = @intCast(base >> 1),
            .asid = 0,
        };
    }

    pub fn addr(self: Ttbr1) usize {
        return @as(usize, self.baddr) << 1;
    }
};

/// MAIR_ELx.
///
/// Memory Attribute Indirection Register.
pub const Mair = packed struct(u64) {
    attr0: u8,
    attr1: u8,
    attr2: u8,
    attr3: u8,
    attr4: u8,
    attr5: u8,
    attr6: u8,
    attr7: u8,
};

/// TCR_ELx.
///
/// Translation Control Register.
pub const Tcr = packed struct(u64) {
    /// The size offset parameter of the memory region addressed by VTTBR_EL2.
    t0sz: u6,
    /// Starting level of Stage 2 translation table walk.
    sl0: u2,
    /// Inner cacheability attribute for memory associated with translation table walks using VTTBR_EL2.
    irgn0: Cacheability,
    /// Outer cacheability attribute for memory associated with translation table walks using VTTBR_EL2.
    orgn0: Cacheability,
    /// Shareability attribute for memory associated with translation table walks using VTTBR_EL2.
    sh0: Shareability,
    /// Granule size for the VTTBR_EL2.
    tg0: Tg0,
    /// Physical address Size for the Stage 2 translation.
    ps: u3,
    ///
    vs: u1,
    /// Reserved.
    _reserved0: u1 = 0,
    ///
    ha: u1,
    ///
    hd: u1,
    /// Reserved.
    _reserved1: u2 = 0,
    ///
    hwu59: u1,
    ///
    hwu60: u1,
    ///
    hwu61: u1,
    ///
    hwu62: u1,
    ///
    nsw: u1,
    ///
    nsa: u1,
    /// Reserved.
    _reserved2: u1 = 0,
    ds: u1,
    ///
    sl2: u1,
    ///
    ao: u1,
    ///
    tlt: u1,
    ///
    s2pie: u1,
    ///
    s2poe: u1,
    ///
    d128: u1,
    /// Reserved.
    _reserved3: u1 = 0,
    ///
    gcsh: u1,
    ///
    tl0: u1,
    /// Reserved.
    _reserved: u2 = 0,
    ///
    haft: u1,
    /// Reserved.
    _reserved4: u19 = 0,

    const Tg0 = enum(u2) {
        /// 4KiB
        size_4kib = 0b00,
        /// 64KiB
        size_64kib = 0b01,
        /// 16KiB
        size_16kib = 0b10,
    };

    const Cacheability = enum(u2) {
        /// Normal memory, Non-cacheable.
        nc = 0b00,
        /// Normal memory, Write-Back Read-Allocate Write-Allocate Cacheable.
        wbrawac = 0b01,
        /// Normal memory, Write-Through Read-Allocate Write-Allocate Cacheable.
        wtranwac = 0b10,
        /// Normal memory, Write-Back Read-Allocate Write-Allocate Non-Cacheable.
        wbranwac = 0b11,
    };

    const Shareability = enum(u2) {
        /// Non-shareable.
        non = 0b00,
        /// Reserved.
        _reserved = 0b01,
        /// Outer Sharable.
        outer = 0b10,
        /// Inner Sharable.
        inner = 0b11,
    };
};

/// DAIF.
///
/// Interrupt Mask Bits.
pub const Daif = packed struct(u64) {
    /// Reserved.
    _reserved0: u6 = 0,
    /// FIQ mask bit.
    f: bool,
    /// IRQ mask bit.
    i: bool,
    /// SError exception mask bit.
    a: bool,
    /// Watchpoint, Breakpoint, and Software Step exceptions mask bit.
    d: bool,
    /// Reserved.
    _reserved1: u54 = 0,
};

/// HCR_EL2.
///
/// Hypervisor Configuration Register. Provides controls for virtualization.
pub const HcrEl2 = packed struct(u64) {
    /// Virtualization enable.
    vm: bool,
    /// Set/Way Invalidation Override.
    swio: bool,
    /// Protected Table Walk.
    ptw: bool,
    /// Physical FIQ Routing.
    fmo: bool,
    /// Physical IRQ Routing.
    imo: bool,
    /// Physical SError exception routing.
    amo: bool,
    /// Virtual FIQ Interrupt.
    vf: bool,
    /// Virtual IRQ Interrupt.
    vi: bool,

    /// Virtual SError exception.
    vse: bool,
    /// Force broadcast.
    fb: bool,
    /// Barried Shareability upgrade.
    bsu: u2,
    /// Default Cacheability.
    dc: bool,
    /// Traps EL0 and EL1 execution of WFI instructions to EL2, when EL2 is enabled in the current Security state.
    twi: bool,
    /// Traps EL0 and EL1 execution of WFE instruction to EL2, when EL2 is enabled in the current Security state.
    twe: bool,
    /// Reserved when Aarch32 is not supported.
    tid0: bool,

    /// Trap ID group 1.
    tid1: bool,
    /// Trap ID group 2.
    tid2: bool,
    /// Trap ID group 3.
    tid3: bool,
    /// Trap SMC instruction.
    tsc: bool,
    /// Trap IMPLEMENTATION DEFINED functionality.
    tidcp: bool,
    /// Trap Auciliary Control Registers.
    tacr: bool,
    /// Trap data or unified cache maintenance instructions that operate by Set/Way.
    tsw: bool,
    /// When FEAT_DPB is implemented, TPCP. Trap data or unified cache maintenance instructions that operate to the Point of Coherency or Persistence.
    /// Otherwise, TPC. Trap data or unified cache maintenance instructions that operate to the Point of Coherency.
    tpcp_tpc: bool,

    /// Trap cache maintenance instructions that operate to the Point of Unification.
    tpu: bool,
    /// Trap TLB maintenance instructions.
    ttlb: bool,
    /// Trap Virtual Memory controls.
    tvm: bool,
    /// Trap General Exceptions from EL0.
    tge: bool,
    /// Trap DC ZVA instructions.
    tdz: bool,
    /// Reserved when EL3 is implemented.
    hcd: bool,
    /// Trap Reads of Virtual Memory controls.
    trvm: bool,
    /// When EL1 is capable of using Aarch32, execution state control for lower Exception levels.
    /// When set, the Execution state for EL1 is Aarch64.
    rw: bool,

    /// Stage 2 Data access cacheability disable.
    cd: bool,
    /// Stage 2 Instruction access cacheability disable.
    id: bool,
    /// When FEAT_VHE is implemented, EL2 Host. Enables a configuration where a Host OS is running in EL2, and the Host OS's applications are running in EL0.
    /// Otherwise, reservd.
    e2h: bool,
    /// When FEAT_LOR is implemented, Trap LOR registers.
    /// Otherwise, reserved.
    tlor: bool,
    /// When FEAT_RAS is implemented, Trap accesses of Error Record registers.
    /// Otherwise, reserved.
    terr: bool,
    /// When FEAT_RAS is implemented, Route synchronous External abort exceptions to EL2.
    /// Otherwise, reserved.
    tea: bool,
    /// Mismatched Inner/Outer Cacheable Non-Coherency Enable for the EL1&0 translation regimes.
    miocnce: bool,
    /// When FEAT_TME is implemented, Enables access to the TSTART, TCOMMIT, TTEST, and TCANCEL instructions at EL0 and EL1.
    /// Otherwise, reserved.
    tme: bool,

    /// When FEAT_PAuth is implemented, Trap registers holding "key" values for PAuth.
    /// Otherwise, reserved.
    apk: bool,
    /// When FEAT_PAuth is implemented, Controls the use of instructions related to PAuth.
    /// Otherwise, reserved.
    api: bool,
    /// When FEAT_NV2 or FEAT_NV is implemented, Nested Virtualization.
    /// Otherwise, reserved.
    nv: bool,
    /// When FEAT_NV2 or FEAT_NV is implemented, Nested Virtualization.
    /// Otherwise, reserved.
    nv1: bool,
    /// When FEAT_NV is implemented, Address Translation.
    /// Otherwise, reserved.
    at: bool,
    /// When FEAT_NV2 is implemented, Nested Virtualization.
    /// Otherwise, reserved.
    nv2: bool,
    /// When FEAT_S2FWB is implemented, Forced Write-Back.
    /// Otherwise, reserved.
    fwb: bool,
    /// When FEAT_RASv1p1 is implemented, Fault Injection Enable.
    /// Otherwise, reserved.
    fien: bool,

    /// When FEAT_RME is implemented, Controls the reporting of Granule protection faults at EL0 and EL1.
    /// Otherwise, reserved.
    gpf: bool,
    /// When FEAT_EVT is implemented, Trap ID group 4.
    /// Otherwise, reserved.
    tid4: bool,
    /// When FEAT_EVT is implemented, Trap ICIALLUIS/IC IALLUIS cache maintenance instructions.
    /// Otherwise, reserved.
    ticab: bool,
    /// When FEAT_AMUv1p1 is implemented, Active Monitors Virtual Offsets Enable.
    /// Otherwise, reserved.
    amvoffen: bool,
    /// When FEAT_EVT is implemented, Trap cache maintenance instructions that operate to the Point of Unification.
    /// Otherwise, reserved.
    tocu: bool,
    /// When FEAT_CSV2_2 is implemented, Enable Access to the SCXTNUM_EL1 and SCXTNUM_EL0 registers.
    /// Otherwise, reserved.
    enscxt: bool,
    /// When FEAT_EVT is implemented, Trap TLB maintenance instructions that operate on the Inner Shareable domain.
    /// Otherwise, reserved.
    ttlbis: bool,
    /// When FEAT_EVT is implemented, Trap TLB maintenance instructions that operate on the Outer Shareable domain.
    /// Otherwise, reserved.
    ttlbos: bool,

    /// When FEAT_MTE2 is implemented, Allocation Tag Access.
    /// Otherwise, reserved.
    ata: bool,
    /// When FEAT_MTE2 is implemented, Default Cacheability Tagging.
    /// Otherwise, reserved.
    dct: bool,
    /// When FEAT_MTE2 is implemented, Trap ID group 5.
    /// Otherwise, reserved.
    tid5: bool,
    /// When FEAT_TWED is implemented, TWE Delay Enable.
    /// Otherwise, reserved.
    tweden: bool,
    /// When FEAT_TWED is implemented TWE Delay.
    /// Otherwise, reserved.
    twedel: u4,
};

/// CNTHCTL_EL2.
///
/// Counter-timer Hypervisor Control Register.
pub const Cnthctl = packed struct(u64) {
    /// Traps EL0 accesses to the frequency register and physical counter registers to EL2.
    el0pcten: bool,
    /// Traps EL0 accesses to the frequency register and virtual counter registers to EL2.
    el0vcten: bool,
    /// Enables the generation of an event stream from CNTPCT_EL0 as seen from EL2.
    evnten: bool,
    /// Controls which transition of the CNTPCT_EL0 trigger bit.
    evntdir: bool,
    /// Selects which bit of CNTPCT_EL0 is the trigger for the event stream generated from that counter when that stream is enabled.
    evnti: u4,
    /// Traps EL0 accesses to the virtual timer registers to EL2.
    el0vten: bool,
    /// Traps EL0 accesses to the physical timer registers to EL2.
    el0pten: bool,
    /// Traps EL0 and EL1 accesses to the EL1 physical counter registers to EL2.
    el1pcten: bool,
    /// Traps EL0 and EL1 accesses to the EL1 physical timer registers to EL2.
    el1pten: bool,
    /// Reserved.
    ecv: bool,
    /// Reserved.
    el1tvt: bool,
    /// Reserved.
    el1tvct: bool,
    /// Reserved.
    el1nvpct: bool,
    /// Reserved.
    el1nvvct: bool,
    /// Reserved.
    evntis: bool,
    /// Reserved.
    cntvmask: bool,
    /// Reserved.
    cntpmask: bool,
    /// Reserved.
    _reserved: u44 = 0,
};

/// ID_AA64MMFR0_ELn.
///
/// Aarch64 Memory Model Feature Register 0.
/// Provides information about the implemented memory model and memory management support.
pub const IdAa64Mmfr0 = packed struct(u64) {
    /// Physical Address range supported.
    parange: PaRange,
    /// Number of ASID bits.
    asidbits: u4,
    /// BigEnd.
    bigend: u4,
    /// SNSMem.
    snsmem: u4,
    /// BigEndEL0.
    bigendel0: u4,
    /// TGran16.
    tgran16: u4,
    /// TGran64.
    tgran64: u4,
    /// TGran4.
    tgran4: u4,
    /// TGran16_2
    tgran16_2: u4,
    /// TGran64_2
    tgran64_2: u4,
    /// TGran4_2
    tgran4_2: u4,
    /// ExS.
    exs: u4,
    /// Reserved.
    _reserved0: u8 = 0,
    /// FGT.
    fgt: u4,
    /// ECV.
    ecv: u4,

    /// Physical Address range.
    const PaRange = enum(u4) {
        /// 32 bits, 4GB
        bits_32 = 0b0000,
        /// 36 bits, 64GB
        bits_36 = 0b0001,
        /// 40 bits, 1TB
        bits_40 = 0b0010,
        /// 42 bits, 4TB
        bits_42 = 0b0011,
        /// 44 bits, 16TB
        bits_44 = 0b0100,
        /// 48 bits, 256TB
        bits_48 = 0b0101,
        /// 52 bits, 1PB
        bits_52 = 0b0110,
        /// 56 bits, 64PB
        bits_56 = 0b1111,
    };
};

/// VTCR_EL2.
///
/// Virtualization Translation Control Register.
pub const VtcrEl2 = packed struct(u64) {
    /// The size offset parameter of the memory region addressed by VTTBR_EL2.
    t0sz: u6,
    /// Starting level of Stage 2 translation table walk.
    sl0: u2,
    /// Inner cacheability attribute for memory associated with translation table walks using VTTBR_EL2.
    irgn0: Cacheability,
    /// Outer cacheability attribute for memory associated with translation table walks using VTTBR_EL2.
    orgn0: Cacheability,
    /// Shareability attribute for memory associated with translation table walks using VTTBR_EL2.
    sh0: Shareability,
    /// Granule size for the VTTBR_EL2.
    tg0: Tg0,
    /// Physical address Size for the Stage 2 translation.
    ps: u3,
    ///
    vs: u1,
    /// Reserved.
    _reserved0: u1 = 0,
    ///
    ha: u1,
    ///
    hd: u1,
    /// Reserved.
    _reserved1: u2 = 0,
    ///
    hwu59: u1,
    ///
    hwu60: u1,
    ///
    hwu61: u1,
    ///
    hwu62: u1,
    ///
    nsw: u1,
    ///
    nsa: u1,
    /// Reserved.
    _reserved2: u1 = 0,
    ds: u1,
    ///
    sl2: u1,
    ///
    ao: u1,
    ///
    tlt: u1,
    ///
    s2pie: u1,
    ///
    s2poe: u1,
    ///
    d128: u1,
    /// Reserved.
    _reserved3: u1 = 0,
    ///
    gcsh: u1,
    ///
    tl0: u1,
    /// Reserved.
    _reserved: u2 = 0,
    ///
    haft: u1,
    /// Reserved.
    _reserved4: u19 = 0,

    const Tg0 = enum(u2) {
        /// 4KiB
        size_4kib = 0b00,
        /// 64KiB
        size_64kib = 0b01,
        /// 16KiB
        size_16kib = 0b10,
    };

    const Cacheability = enum(u2) {
        /// Normal memory, Non-cacheable.
        nc = 0b00,
        /// Normal memory, Write-Back Read-Allocate Write-Allocate Cacheable.
        wbrawac = 0b01,
        /// Normal memory, Write-Through Read-Allocate Write-Allocate Cacheable.
        wtranwac = 0b10,
        /// Normal memory, Write-Back Read-Allocate Write-Allocate Non-Cacheable.
        wbranwac = 0b11,
    };

    const Shareability = enum(u2) {
        /// Non-shareable.
        non = 0b00,
        /// Reserved.
        _reserved = 0b01,
        /// Outer Sharable.
        outer = 0b10,
        /// Inner Sharable.
        inner = 0b11,
    };
};

/// VTTBR_EL2.
///
/// Virtualization Translation Table Base Register.
pub const VttbrEl2 = packed struct(u64) {
    /// Translation table base address.
    baddr: u48,
    /// VMID for the translation table.
    vmid: u16,
};

/// VBAR_ELx.
///
/// Vector Base Address Register.
/// Holds the vector base address for any exception that is taken to ELx.
pub const Vbar = packed struct(u64) {
    /// Vector base address.
    addr: u64,
};

/// ESR_ELx.
///
/// Exception Syndrome Register.
/// Holds syndrome information for an exception taken to ELx.
pub const Esr = packed struct(u64) {
    /// Instruction Specific Syndrome.
    iss: u25,
    /// Instruction Length for synchronous exceptions.
    il: Length,
    /// Exception class.
    ec: Class,
    /// Instruction Specific Syndrome.
    iss2: u24,
    /// Reserved.
    _reserved: u8 = 0,

    pub const Class = enum(u6) {
        unknown = 0b000000,
        bti = 0b001011,
        illegal_exec_state = 0b001110,
        svc_a32 = 0b010001,
        hvc_a32 = 0b010010,
        smc_a32 = 0b010011,
        svc_a64 = 0b010101,
        hvc_a64 = 0b010110,
        smc_a64 = 0b010111,
        iabort_lower = 0b100000,
        iabort_cur = 0b100001,
        pc_align = 0b100010,
        dabort_lower = 0b100100,
        dabort_cur = 0b100101,
        sp_align = 0b100110,

        _,
    };

    pub const Length = enum(u1) {
        len16 = 0,
        len32 = 1,
    };

    /// Instruction Fault Status Code.
    ///
    /// ISS[5:0] when EC is `.iabort_lower` or `iabort_cur`.
    pub const Ifsc = enum(u6) {
        addr_size_lvl0 = 0b000000,
        addr_size_lvl1 = 0b000001,
        addr_size_lvl2 = 0b000010,
        addr_size_lvl3 = 0b000011,

        trans_lv0 = 0b000100,
        trans_lv1 = 0b000101,
        trans_lv2 = 0b000110,
        trans_lv3 = 0b000111,

        af_lv1 = 0b001001,
        af_lv2 = 0b001010,
        af_lv3 = 0b001011,
        af_lv0 = 0b001000,

        perm_lv0 = 0b001100,
        perm_lv1 = 0b001101,
        perm_lv2 = 0b001110,
        perm_lv3 = 0b001111,

        _,
    };

    /// ISS encoding for Data Abort.
    pub const IssDabort = packed struct(u25) {
        /// Data Fault Status Code.
        dfsc: Dfsc,
        /// Write not Read,
        ///
        /// Indicates whether a synchronous abort was caused by an instruction writing to a memory location,
        /// or by an instruction reading from a memory location.
        wnr: enum(u1) {
            read = 0,
            write = 1,
        },
        /// Stage 1 Page Table Walk.
        ///
        /// For a stage 2 fault, indicates whether the fault was a stage 2 fault on an access made for a stage 1 translation table walk.
        /// Otherwise, reserved.
        s1ptw: u1,
        /// Cache maintenance.
        cm: u1,
        /// External abort type.
        /// Otherwise, fixed to 0.
        ea: u1,
        /// FAR not Valid when a synchronous Externnal abort.
        fnv: bool,
        ///
        lst_set: u2,
        ///
        vncr: u1,
        ///
        ar_pfv: u1,
        /// When ISV is set, Sixty Four bit general-purpose register transfer.
        /// Width of the register accessed by the instruction is 64-bit.
        sf_fnp: bool,
        /// If ISV is set, Syndrome Register Transfer.
        /// The register number of the Wt/Xt/Rt operand of the faulting instruction.
        srt_wu: u5,
        ///
        sse_toplevel: u1,
        /// When ISV is set, Syndrome Access Size.
        ///
        /// Indicates the size of the access attempted by the faulting operation.
        sas: enum(u2) {
            byte = 0b00,
            halfword = 0b01,
            word = 0b10,
            doubleword = 0b11,
        },
        /// Instruction Syndrome Valid.
        ///
        /// Indicates whether the syndrome information in ISS[23:14] is valid.
        isv: bool,
    };

    /// Data Abort Fault Status Code.
    pub const Dfsc = enum(u6) {
        addr_size_lvl0 = 0b000000,
        addr_size_lvl1 = 0b000001,
        addr_size_lvl2 = 0b000010,
        addr_size_lvl3 = 0b000011,

        trans_lvl0 = 0b000100,
        trans_lvl1 = 0b000101,
        trans_lvl2 = 0b000110,
        trans_lvl3 = 0b000111,

        af_lvl0 = 0b001000,
        af_lvl1 = 0b001001,
        af_lvl2 = 0b001010,
        af_lvl3 = 0b001011,

        perm_lvl0 = 0b001100,
        perm_lvl1 = 0b001101,
        perm_lvl2 = 0b001110,
        perm_lvl3 = 0b001111,

        _,
    };
};

/// SCTLR_ELx.
///
/// System Control Register.
pub const Sctlr = packed struct(u64) {
    /// MMU enable for EL1&0 stage 1 address translation.
    m: bool,
    /// Alignment check enable.
    a: bool,
    /// Data cache enable.
    c: bool,
    /// Stack Alignment Check Enable.
    sa: bool,
    /// Stack Alignment Check Enable for EL0.
    sa0: bool,
    /// Reserved.
    cp15ben: u1,
    /// Reserved.
    naa: u1,
    /// Reserved.
    itd: u1,
    /// Reserved.
    sed: u1,
    /// User Mask Access.
    uma: bool,
    /// Reserved.
    enrctx: u1,
    /// Reserved.
    eos: u1,
    /// Stage 1 instruction access Cacheability control.
    i: u1,
    /// Reserved.
    endb: u1,
    /// Traps EL0 execution of DC ZVA instruction to EL1 or EL2.
    dze: bool,
    /// Traps EL0 accesses to the CTR_EL0 to EL1 or EL2.
    uct: bool,
    /// Traps EL0 execution of WFI instruction to EL1 or EL2.
    ntwi: bool,
    /// Reserved.
    _reserved0: u1 = 0,
    /// Traps EL0 execution of WFE instruction to EL1 or EL2.
    ntwe: bool,
    /// Write permission implies XN.
    wxn: bool,
    /// Reserved.
    tscxt: u1,
    /// Reserved.
    iesb: u1,
    /// Reserved.
    eis: u1,
    /// Reserved.
    span: u1,
    /// Endianness of data access at EL0.
    e0e: u1,
    /// Endianness of data access at EL1.
    ee: u1,
    /// Traps EL0 execution of cache maintenance instructions to EL1 or EL2.
    uci: bool,
    /// Reserved.
    enda: u1,
    /// Reserved.
    ntlsmd: u1,
    /// Reserved.
    lsmaoe: u1,
    /// Reserved.
    enib: u1,
    /// Reserved.
    enia: u1,
    /// Reserved.
    cmow: u1,
    /// Reserved.
    mscen: u1,
    /// Reserved.
    _reserved1: u1 = 0,
    /// Reserved.
    bt0: u1,
    /// Reserved.
    bt: u1,
    /// Reserved.
    itfsb: u1,
    /// Reserved.
    tcf0: u2,
    /// Reserved.
    tcf: u2,
    /// Reserved.
    ata0: u1,
    // Reserved.
    ata: u1,
    // Reserved.
    dssbs: u1,
    // Reserved.
    tweden: u1,
    // Reserved.
    twedel: u4,
    /// Reserved.
    tmt0: u1,
    /// Reserved.
    tmt: u1,
    /// Reserved.
    tme0: u1,
    /// Reserved.
    tme: u1,
    /// Reserved.
    enasr: u1,
    /// Reserved.
    enas0: u1,
    /// Reserved.
    enals: u1,
    /// Reserved.
    epan: u1,
    /// Reserved.
    tsco0: u1,
    /// Reserved.
    tsco: u1,
    /// Reserved.
    entp2: u1,
    /// Reserved.
    nmi: u1,
    /// Reserved.
    spintmask: u1,
    /// Reserved.
    tidcp: u1,
};

/// FAT_ELx.
///
/// Fault Address Register.
pub const Far = packed struct(u64) {
    /// Fault address.
    addr: u64,
};

/// HPFAR_EL2.
///
/// Hypervisor IPA Fault Address Register.
pub const Hpfar = packed struct(u64) {
    /// Reserved.
    _reserved0: u4 = 0,
    /// Faulting IPA.
    fipa: u44,
    /// Reserved.
    _reserved: u15 = 0,
    /// Faulting IPA address space secure.
    ns: bool,

    pub fn ipa(self: Hpfar) u64 {
        return @as(u64, self.fipa << hugin.mem.page_shift_4kib);
    }
};

/// SP_ELx.
pub const Sp = packed struct(u64) {
    /// Stack pointer.
    addr: u64,
};

/// MIDR_EL1.
///
/// Main ID Register.
pub const Midr = packed struct(u64) {
    /// Revision number of the device.
    revision: u4,
    /// Primary Part Number of the device.
    partnum: u12,
    /// Architecture version.
    architecture: u4,
    /// Variant number.
    variant: u4,
    /// The Implementer code.
    implementer: u8,
    /// Reserved.
    _reserved: u32 = 0,
};

/// VPIDR_EL2.
///
/// Virtualization Processor ID Register.
/// This value is returned by EL1 reads of MIDR_EL1.
pub const Vpidr = Midr;

/// MPIDR_EL1.
///
/// Multiprocessor Affinity Register.
pub const Mpidr = packed struct(u64) {
    /// Affinity level 0.
    aff0: u8,
    /// Affinity level 1.
    aff1: u8,
    /// Affinity level 2.
    aff2: u8,
    /// Indicates whether the lowest level of affinity consists of logical PEs that are implemented using an interdependent approach.
    mt: u1,
    /// Reserved.
    _reserved0: u5 = 0,
    /// Indicates a Uniprocessor system.
    u: bool,
    /// Reserved.
    _reserved1: u1 = 0,
    /// Affinity level 3.
    aff3: u8,
    /// Reserved.
    _reserved2: u24 = 0,

    /// Get the affinity value masking all other bits.
    pub fn affinity(self: Mpidr) u64 {
        const value = @as(u64, @bitCast(self));
        return value & 0x0000_00FF_00FF_FFFF;
    }

    /// Get the packed affinity value as a u32.
    pub fn packedAffinity(self: Mpidr) u32 {
        return hugin.bits.concatMany(u32, .{
            self.aff3,
            self.aff2,
            self.aff1,
            self.aff0,
        });
    }
};

/// MPIDR_EL2.
///
/// Virtualization Multiprocessor ID Register.
/// This value is returned by EL1 reads of MPIDR_EL1.
pub const Vmpidr = Mpidr;

/// CNTVOFF_EL2.
///
/// Counter-timer Virtual Offset Register.
pub const Cntvoff = packed struct(u64) {
    /// Offset value.
    offset: u64,
};

/// ICC_CTLR_EL1.
///
/// Interrupt Controller Control Register.
pub const IccCtlr = packed struct(u64) {
    /// Common Binary Point Register.
    cbpr: u1,
    /// EOI mode for the current Security state.
    ///
    /// Controls whether a write to an EOI register also deactivates the interrupt.
    eoimode: EoiMode,
    /// Reserved.
    _reserved0: u4 = 0,
    /// Priority Mask Hint Enable.
    pmhe: bool,
    /// Reserved.
    _reserved1: u1 = 0,
    /// Priority bits.
    pribits: u3,
    /// Identifier bits.
    idbits: u3,
    /// SEI Support.
    seis: bool,
    /// Affinity 3 Valid.
    a3v: bool,
    /// Reserved.
    _reserved2: u2 = 0,
    /// Range Selector Support.
    rss: u1,
    /// Extended INTID range.
    extrange: u1,
    /// Reserved.
    _reserved3: u44 = 0,

    const EoiMode = enum(u1) {
        /// Write to an EOI register both drop priority and deactivate the interrupt.
        deactivates = 0,
        /// Write to an EOI register only drops priority. ICC_DIR_EL1 provides a way to deactivate the interrupt.
        no_deactivate = 1,
    };
};

/// ICC_SRE_ELx.
///
/// Interrupt Controller System Register Enable Register.
pub const IccSre = packed struct(u64) {
    /// System Register Enable.
    sre: bool,
    /// Disable FIQ bypass.
    dfb: bool,
    /// Disable IRQ bypass.
    dib: bool,
    /// Enables lower Exception level access to ICC_SRE_ELx.
    enable: bool,
    /// Reserved.
    _reserved: u60 = 0,
};

/// ICC_PMR_EL1.
///
/// Interrupt Controller Interrupt Priority Mask Register.
pub const IccPmr = packed struct(u64) {
    /// Priority mask.
    priority: u8,
    /// Reserved.
    _reserved: u56 = 0,
};

/// ICC_BPRn_EL1. (n = 0,1)
///
/// Interrupt Controller Binary Point Register n.
pub const IccBpr = packed struct(u64) {
    /// Binary point.
    bpr: u3,
    /// Reserved.
    _reserved: u61 = 0,
};

/// ICC_IGRPEN1_EL1.
///
/// Interrupt Controller Interrupt Group 1 Enable Register.
pub const IccIgrpen1El1 = packed struct(u64) {
    /// Enable Group 0 interrupts.
    enable: bool,
    /// Reserved.
    _reserved: u63 = 0,
};

/// ICC_IAR1_EL1
///
/// The PE reads this register to obtain the INTID of the signaled Group 1 interrupt.
/// This read acts as an acknowledge for the interrupt.
pub const IccIar1El1 = packed struct(u64) {
    /// The INTID of the signaled interrupt.
    intid: u24,
    /// Reserved.
    _reserved: u40 = 0,
};

/// ICC_DIR1_EL1.
///
/// Interrupt Controller Deactivate Interrupt Register.
///
/// When interrupt priority drop is separated from interrupt deactivation,
/// a write to this register deactivates the specified interrupt.
pub const IccDirEl1 = packed struct(u64) {
    /// The INTID of the interrupt to deactivate.
    intid: u24,
    /// Reserved.
    _reserved: u40 = 0,
};

/// ICC_EOIR1_EL1.
///
/// A PE writes to this register to inform the CPU interface that it has completed the processing of the interrupt.
pub const IccEoir1El1 = packed struct(u64) {
    /// The INTID from the corresponding IAR.
    intid: u24,
    /// Reserved.
    _reserved: u40 = 0,
};

/// ICC_SGI1R_EL1.
///
/// Interrupt Controller Software Generated Interrupt Group 1 Register.
pub const IccSgi1r = packed struct(u64) {
    /// Target List. Set of PEs for which SGI interrupts will be generated.
    ///
    /// Each bit corresponds to the PE within a cluster with an Affinity 0 value equal to the bit number.
    target_list: u16,
    /// Affinity level 1.
    aff1: u8,
    /// Interrupt ID.
    intid: u4,
    /// Reserved.
    _reserved0: u4 = 0,
    /// Affinity level 2.
    aff2: u8,
    /// Interrupt Routing Mode.
    irm: Irm,
    /// Reserved.
    _reserved1: u3 = 0,
    /// Range selector.
    rs: u4 = 0,
    /// Affinity level 3.
    aff3: u8,
    /// Reserved.
    _reserved2: u8 = 0,

    const Irm = enum(u1) {
        /// Routed to the PEs specified Aff3.Aff2.Aff1.<target_list>
        specified = 0,
        /// Routed to all PEs in the system excluding self.
        all = 1,
    };

    pub fn from(affi: u32, intid: u4) IccSgi1r {
        return .{
            .target_list = @as(u16, 1) << @as(u4, @truncate((affi >> 0) & 0xFF)),
            .aff1 = @truncate((affi >> 8) & 0xFF),
            .aff2 = @truncate((affi >> 16) & 0xFF),
            .aff3 = @truncate((affi >> 24) & 0xFF),
            .intid = intid,
            .irm = .specified,
        };
    }
};

/// ICH_LR<n>_EL2.
///
/// Interrupt Controller List Registers, n = 0-15.
/// Provides interrupt context information for the virtual CPU interface.
pub const IchLr = packed struct(u64) {
    /// Virtual INTID of the interrupt.
    vintid: u32,
    /// Physical INTID, for hardware interrupts.
    pintid: u13,
    /// Reserved.
    _reserved0: u3 = 0,
    /// The priority of the interrupt.
    prio: u8,
    /// Reserved.
    _reserved1: u3 = 0,
    /// Indicates whether the virtual priority has the non-maskable property.
    nmi: bool,
    /// Indicates the group for this virtual interrupt.
    group: u1,
    /// Indicates whether this virtual interrupt maps directly to a hardware interrupt.
    ///
    /// Deactivation of the virtual interrupt also causes the deactivation of the physical interrupt with the pINTID.
    hw: bool,
    /// The state of the interrupt.
    state: State,

    const State = enum(u2) {
        /// Inactive.
        inactive = 0b00,
        /// Pending.
        pending = 0b01,
        /// Active.
        active = 0b10,
        /// Pending and Active.
        pending_active = 0b11,
    };
};

/// ICH_VTR_EL2.
///
/// Interrupt Controller VGIC Type Register.
/// Reports supported GIC virtualization features.
pub const IchVtr = packed struct(u64) {
    /// List Registers.
    ///
    /// Indicates the number of List registers implemented, minus one.
    list_regs: u5,
    /// Reserved.
    _reserved0: u13 = 0,
    /// Masking of directly-injected virtual interrupts.
    dvim: bool,
    /// Separate trapping of EL1 writes to ICV_DIR_EL1 supported.
    tds: bool,
    /// Direct injection of virtual interrupts not supported.
    nv4: bool,
    /// Affinity 3 Valid.
    a3v: bool,
    /// SEI Support.
    seis: bool,
    /// The number of virtual interrupt identifier bits supported.
    idbits: u3,
    /// Preemption bits.
    prebits: u3,
    /// Priority bits.
    pribits: u3,
    /// Reserved.
    _reserved1: u32 = 0,
};

/// ICH_EISR_EL2.
///
/// Interrupt Controller End of Interrupt Status Register.
/// Indicates which List registers have outstanding EOI maintenance interrupts.
pub const IchEisr = packed struct(u64) {
    /// EOI maintenance interrupt status bit for List register <n>.
    status: u16,
    /// Reserved.
    _reserved: u48 = 0,
};

/// ICH_HCR.
///
/// Interrupt Controller Hypervisor Control Register.
pub const IchHcr = packed struct(u32) {
    /// Enable.
    en: bool,
    /// Underflow Interrupt Enable.
    uie: bool,
    /// List Register Entry Not Present Interrupt Enable.
    lrenpie: bool,
    /// No Pending Interrupt Enable.
    npie: bool,
    /// VM Group 0 Enabled Interrupt Enable.
    vgrp0eie: bool,
    /// VM Group 0 Disabled Interrupt Enable.
    vgrp0die: bool,
    /// VM Group 1 Enabled Interrupt Enable.
    vgrp1eie: bool,
    /// VM Group 1 Disabled Interrupt Enable.
    vgrp1die: bool,
    /// Reserved.
    vsgieoic: bool,
    /// Reserved.
    _reserved0: u1 = 0,
    /// Trap all Non-secure EL1 accesses to System registers that are common to Group 0 and Group 1 to EL2.
    tc: bool,
    /// Trap all Non-secure EL1 accesses to ICC_* and ICV_* system registers for Group0 interrupts to EL2.
    tall0: bool,
    /// Trap all Non-secure EL1 accesses to ICC_* and ICV_* system registers for Group1 interrupts to EL2.
    tall1: bool,
    /// Trap all locally generated SEIs.
    tsei: bool,
    /// Trap Non-secure EL1 writes to ICC_DIR and ICV_DIR.
    tdir: bool,
    /// Reserved.
    _reserved1: u12 = 0,
    /// This field is incremented whenever a successful write to a virtual EOIR or DIR register would have resulted in a virtual interrupt deactivation.
    eoic: u5,
};

// =============================================================
// Imports
// =============================================================

const hugin = @import("hugin");
