/// System registers.
pub const SystemReg = enum {
    current_el,
    elr_el1,
    elr_el2,
    elr_el3,
    spsr_el1,
    spsr_el2,
    spsr_el3,
    hcr_el2,

    /// Get the string representation of the system register.
    pub fn str(comptime self: SystemReg) []const u8 {
        return switch (self) {
            .current_el => "currentel",
            .elr_el1 => "elr_el1",
            .elr_el2 => "elr_el2",
            .elr_el3 => "elr_el3",
            .spsr_el1 => "spsr_el1",
            .spsr_el2 => "spsr_el2",
            .spsr_el3 => "spsr_el3",
            .hcr_el2 => "hcr_el2",
        };
    }

    /// Get the type of the system register.
    pub fn Type(comptime self: SystemReg) type {
        return switch (self) {
            .current_el => CurrentEl,
            .elr_el1, .elr_el2, .elr_el3 => Elr,
            .spsr_el1, .spsr_el2, .spsr_el3 => Spsr,
            .hcr_el2 => HcrEl2,
        };
    }
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
