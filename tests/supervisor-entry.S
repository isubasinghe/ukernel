# QEMU/OpenSBI chooses the lowest ELF load address, not its e_entry.
# Put a jump there when testing the explicitly selected S-mode entry.
#ifdef KNOWN_SUPERVISOR_ENTRY
.option norvc
.section .text.init, "ax", @progbits
    j _start_s
#endif
