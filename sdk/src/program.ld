ENTRY(_start)

PHDRS
{
    code PT_LOAD FLAGS(5);
    data PT_LOAD FLAGS(6);
}

SECTIONS
{
    . = 0x80a00000;

    .jab.header : { KEEP(*(.jab.header)) } :code
    ASSERT(. == 0x80a00000 + 64, "the image's header is 64 bytes: the jump, then the header's fields")
    .jab.decl 0x80a00000 + 64 : { KEEP(*(.jab.decl)) } :code
    ASSERT(. <= 0x80a00000 + 4096, "the declaration ends inside the image's first page")
    . = MAX(., 0x80a00000 + 4096);
    __jab_code = .;
    .text : { *(.text .text.*) } :code
    .rodata : { *(.rodata .rodata.*) } :code
    .data : { *(.data .data.*) } :data
    .bss : { *(.bss .bss.*) *(COMMON) } :data
    ASSERT(__jab_code == 0x80a00000 + 4096, "the code begins at the image's second page")
}
