; syscall.s -- implementation of system calls

; External parameters come from here
RISCV_BREAK = $07F4

.include "registers.inc"
.include "kernal.inc"
.include "errno.inc"
.include "reu.inc"

.import _RISCV_ireg_0
.import _RISCV_ireg_1
.import _RISCV_ireg_2
.import _RISCV_ireg_3
.importzp RISCV_fence

.bss

RISCV_break: .res 4

; Address and size for I/O
io_addr: .res 4
io_size: .res 4

; Structure for stat, fstat, lstat, fstatat
; Matches Newlib libgloss/riscv/kernel_stat.h
.struct kernel_stat
    st_dev     .dword 2
    st_ino     .dword 2
    st_mode    .dword
    st_nlink   .dword
    st_uid     .dword
    st_gid     .dword
    st_rdev    .dword 2
    __pad1     .dword 2
    st_size    .dword 2
    st_blksize .dword
    __pad2     .dword
    st_blocks  .dword 2
    st_atim    .dword 4 ; 8 bytes: tv_sec; 4 bytes: tv_nsec; 4 bytes: pad
    st_mtim    .dword 4
    st_ctim    .dword 4
    __pad3     .dword 2
.endstruct
kernel_stat_size = 128

; Transfer area for I/O
xfer_size = 16
io_xfer: .res kernel_stat_size

.segment "ZEROPAGE"
io_count: .res 1
io_index: .res 1
local_addr: .res 2

.code

; Initialize this system
.global _RISCV_syscall_init
.proc _RISCV_syscall_init

    ; Set the break
    lda RISCV_BREAK+0
    sta RISCV_break+0
    lda RISCV_BREAK+1
    sta RISCV_break+1
    lda RISCV_BREAK+2
    sta RISCV_break+2
    lda #1
    sta RISCV_break+3

    rts

.endproc

; SYS_faccessat    = bad_ecall
; SYS_openat       = bad_ecall
; SYS_close        = bad_ecall
; SYS_lseek        = bad_ecall
; SYS_read         = bad_ecall

; Write to the given file handle
; A0 = file handle
; A1 = pointer to data
; A2 = length of data

.global SYS_write
.proc SYS_write

    ; Set up the transfer area
    lda _RISCV_ireg_0+REG_a1
    sta io_addr+0
    lda _RISCV_ireg_1+REG_a1
    sta io_addr+1
    lda _RISCV_ireg_2+REG_a1
    sta io_addr+2
    lda _RISCV_ireg_3+REG_a1
    sta io_addr+3
    lda _RISCV_ireg_0+REG_a2
    sta io_size+0
    lda _RISCV_ireg_1+REG_a2
    sta io_size+1
    lda _RISCV_ireg_2+REG_a2
    sta io_size+2
    lda _RISCV_ireg_3+REG_a2
    sta io_size+3
    jsr check_read
    bcc read_ok
        set_errno EFAULT
        rts
    read_ok:

    ; Check for special file handles 0, 1 and 2
    lda _RISCV_ireg_1+REG_a0
    ora _RISCV_ireg_2+REG_a0
    ora _RISCV_ireg_3+REG_a0
    bne check_file
    lda _RISCV_ireg_0+REG_a0
    bne check_output
        ; Handle 0 (standard input; not valid)
        set_errno EBADF
        rts
    check_output:
    cmp #3
    bcs check_file
        ; Handle 1 (standard output) or 2 (standard error)
        @write_loop:
            jsr read_io_block
            lda io_count
            beq @end_write_loop
            lda #0
            sta io_index
            @write_byte:
                ldx io_index
                ldy io_xfer,x
                lda ascii_to_pet,y
                jsr CHROUT
                inc io_index
            dec io_count
            bne @write_byte
        beq @write_loop
        @end_write_loop:
        rts
        lda _RISCV_ireg_0+REG_a2
        sta _RISCV_ireg_0+REG_a0
        lda _RISCV_ireg_1+REG_a2
        sta _RISCV_ireg_1+REG_a0
        lda _RISCV_ireg_2+REG_a2
        sta _RISCV_ireg_2+REG_a0
        lda _RISCV_ireg_3+REG_a2
        sta _RISCV_ireg_3+REG_a0
        rts
    check_file:

    ; File I/O not yet implemented
    set_errno EBADF
    rts

.endproc

; SYS_fstatat      = bad_ecall

; Return information about an open file handle
; A0 = file handle
; A1 = address of stat structure
;      This is struct kernel_stat in Newlib libgloss/riscv/kernel_stat.h
.global SYS_fstat
.proc SYS_fstat

    ; Set up the transfer area
    lda _RISCV_ireg_0+REG_a1
    sta io_addr+0
    lda _RISCV_ireg_1+REG_a1
    sta io_addr+1
    lda _RISCV_ireg_2+REG_a1
    sta io_addr+2
    lda _RISCV_ireg_3+REG_a1
    sta io_addr+3
    lda #kernel_stat_size
    sta io_size+0
    lda #0
    sta io_size+1
    sta io_size+2
    sta io_size+3
    jsr check_write
    bcc write_ok
        set_errno EFAULT
        rts
    write_ok:

    ; Clear the transfer area
    ldx #kernel_stat_size
    lda #0
    clear:
        sta io_xfer-1,x
    dex
    bne clear

    ; Check for special file handles 0, 1 and 2
    lda _RISCV_ireg_1+REG_a0
    ora _RISCV_ireg_2+REG_a0
    ora _RISCV_ireg_3+REG_a0
    bne check_file
    lda _RISCV_ireg_0+REG_a0
    bne check_output
        ; Handle 0 (standard input)
        lda #<020444            ; Character device, writable
        sta io_xfer+kernel_stat::st_mode+0
        lda #>020444
        sta io_xfer+kernel_stat::st_mode+1
        lda #0
        sta io_xfer+kernel_stat::st_mode+2
        sta io_xfer+kernel_stat::st_mode+3
        sta _RISCV_ireg_0+REG_a0
        sta _RISCV_ireg_1+REG_a0
        sta _RISCV_ireg_2+REG_a0
        sta _RISCV_ireg_3+REG_a0
        jmp write_io_xfer
    check_output:
    cmp #3
    bcs check_file
        ; Handle 1 (standard output) or 2 (standard error)
        lda #<020222            ; Character device, readable
        sta io_xfer+kernel_stat::st_mode+0
        lda #>020222
        sta io_xfer+kernel_stat::st_mode+1
        lda #0
        sta io_xfer+kernel_stat::st_mode+2
        sta io_xfer+kernel_stat::st_mode+3
        sta _RISCV_ireg_0+REG_a0
        sta _RISCV_ireg_1+REG_a0
        sta _RISCV_ireg_2+REG_a0
        sta _RISCV_ireg_3+REG_a0
        jmp write_io_xfer
    check_file:

    ; File I/O not yet implemented
    set_errno EBADF
    rts

.endproc

; SYS_gettimeofday = bad_ecall
; SYS_brk          = bad_ecall
; SYS_open         = bad_ecall
; SYS_link         = bad_ecall
; SYS_unlink       = bad_ecall
; SYS_access       = bad_ecall
; SYS_stat         = bad_ecall
; SYS_lstat        = bad_ecall

; Check the configured address and size for valid write
; Set C if address and size are invalid
; Must be placed immediately before check_read so a branch will reach
.proc check_write

    ; Requirement is the same as check_read, except that the address must also
    ; be above the fence
    lda RISCV_fence
    cmp io_addr+2
    bcc check_read
    rts

.endproc

; Check the configured address and size for valid read
; Set C if address and size are invalid
.proc check_read

    ; I/O is to Space 1 (the REU) only
    ; The checks done here will not allow I/O to the last byte of the REU.
    ; This address is within the area used to build the parameters to main(),
    ; and is unlikely to be used for I/O.

    lda io_addr+3
    cmp #1
    bne bad_read

    ; I/O shall not exceed 16 MB
    lda io_size+3
    bne bad_read

    ; I/O shall not exceed the end of the REU
    clc
    lda io_addr+0
    adc io_addr+0
    lda io_addr+1
    adc io_addr+1
    lda io_addr+2
    adc io_addr+2
    ; C set if the add overflows

    rts

bad_read:
    sec
    rts

.endproc

; Read next block into io_xfer
; Return size in io_count; update io_addr and io_size
.proc read_io_block

    ; Determine the size for this transfer
    lda io_size+1
    ora io_size+2
    beq check_size_0
        lda #xfer_size
        bne got_size
    check_size_0:
        lda io_size+0
        cmp #xfer_size
        bcc got_size
            lda #xfer_size
    got_size:
    sta io_count
    cmp #0
    beq end_read

    ; Space 1: RAM Expansion Unit
    sta reu_xfer_size_0
    set_reu_address io_addr
    set_local_address io_xfer
    lda #0
    sta reu_xfer_size_1
    do_reu_read

    ; Update io_addr and io_size
    clc
    lda io_addr+0
    adc io_count
    sta io_addr+0
    lda io_addr+1
    adc #0
    sta io_addr+1
    lda io_addr+2
    adc #0
    sta io_addr+2
    sec
    lda io_size+0
    sbc io_count
    sta io_size+0
    lda io_size+1
    sbc #0
    sta io_size+1
    lda io_size+2
    sbc #0
    sta io_size+2

end_read:
    rts

.endproc

; Pass the io_xfer area to the RISC-V target
.proc write_io_xfer

    set_reu_address io_addr
    set_xfer_size io_size
    set_local_address io_xfer
    do_reu_write
    rts

.endproc

.segment "PAGEALIGN"
.align 256

ascii_to_pet:
    ; $00 to $40
    .repeat 65,i
        .byte i+0
    .endrep
    ; $41 to $5A
    .repeat 26,i
        .byte i+$C1
    .endrep
    ; $5B to $60
    .repeat 6,i
        .byte i+$5B
    .endrep
    ; $61 to $7A
    .repeat 26,i
        .byte i+$41
    .endrep
    ; $7B to $FF
    .repeat 133,i
        .byte i+$7B
    .endrep
