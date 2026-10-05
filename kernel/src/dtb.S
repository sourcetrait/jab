.include "dtb.inc"

.section .text

.global dtb_check
dtb_check:
    li t0, DTB_HEADER
    bltu a1, t0, 93f
    andi t0, a0, 7
    bnez t0, 94f
    dtb_be32 t0, a0, DTB_HDR_MAGIC
    li t1, DTB_MAGIC
    bne t0, t1, 91f
    dtb_be32 t0, a0, DTB_HDR_VERSION
    li t1, DTB_VERSION
    bltu t0, t1, 92f
    dtb_be32 t0, a0, DTB_HDR_LAST_COMPATIBLE
    li t1, DTB_LAST_COMPATIBLE
    bgtu t0, t1, 92f
    dtb_be32 t2, a0, DTB_HDR_TOTALSIZE      # the tree's bytes
    li t0, DTB_HEADER
    bltu t2, t0, 93f
    bgtu t2, a1, 93f
    li t0, DTB_MAX
    bgtu t2, t0, 93f
    dtb_be32 t3, a0, DTB_HDR_OFF_RSVMAP
    andi t0, t3, 7
    bnez t0, 94f
    li t0, DTB_HEADER
    bltu t3, t0, 94f
1:
    addi t0, t3, 16
    bgtu t0, t2, 94f                        # an entry past the tree
    add t1, a0, t3
    ld t4, 0(t1)
    ld t5, 8(t1)
    or t4, t4, t5
    addi t3, t3, 16
    bnez t4, 1b                             # until the empty entry
    dtb_be32 t3, a0, DTB_HDR_OFF_STRINGS
    dtb_be32 t4, a0, DTB_HDR_SIZE_STRINGS
    li t0, DTB_HEADER
    bltu t3, t0, 94f
    add t0, t3, t4
    bgtu t0, t2, 94f
    dtb_be32 t5, a0, DTB_HDR_OFF_STRUCT
    dtb_be32 t6, a0, DTB_HDR_SIZE_STRUCT
    andi t0, t5, 3
    bnez t0, 94f
    li t0, DTB_HEADER
    bltu t5, t0, 94f
    add t0, t5, t6
    bgtu t0, t2, 94f
    add a2, a0, t5                          # the cursor
    add a3, a2, t6                          # the structure's end
    add a4, a0, t3                          # the strings
    add a5, a4, t4                          # their end
    li a6, 0                                # the depth
    li a7, 0                                # bit d: the node open at depth d has closed a child
    li t2, 0                                # 1 once the root has closed
2:
    addi t0, a2, 4
    bgtu t0, a3, 95f
    dtb_be32 t0, a2
    addi a2, a2, 4
    li t1, DTB_BEGIN_NODE
    beq t0, t1, 3f
    li t1, DTB_END_NODE
    beq t0, t1, 5f
    li t1, DTB_PROP
    beq t0, t1, 6f
    li t1, DTB_NOP
    beq t0, t1, 2b
    li t1, DTB_END
    beq t0, t1, 8f
    j 99f
3:
    bnez t2, 99f                            # a second root
4:
    bgeu a2, a3, 96f                        # the name runs past the structure
    lbu t0, 0(a2)
    addi a2, a2, 1
    bnez t0, 4b
    addi a2, a2, 3
    andi a2, a2, -4
    bgtu a2, a3, 95f
    addi a6, a6, 1
    li t1, DTB_DEPTH
    bgtu a6, t1, 98f
    li t1, 1
    sll t1, t1, a6
    not t1, t1
    and a7, a7, t1
    j 2b
5:
    beqz a6, 99f                            # no node open
    addi a6, a6, -1
    li t1, 1
    sll t1, t1, a6
    or a7, a7, t1
    bnez a6, 2b
    li t2, 1
    j 2b
6:
    beqz a6, 99f                            # a property outside every node
    li t1, 1
    sll t1, t1, a6
    and t1, t1, a7
    bnez t1, 99f                            # a property after a child of its node
    addi t0, a2, 8
    bgtu t0, a3, 95f
    dtb_be32 t3, a2                         # the value's bytes
    dtb_be32 t4, a2, 4                      # the name's offset in the strings
    add t0, t0, t3
    bgtu t0, a3, 97f                        # the value past the structure
    add t4, a4, t4
7:
    bgeu t4, a5, 97f                        # the name past the strings
    lbu t1, 0(t4)
    addi t4, t4, 1
    bnez t1, 7b
    addi t0, t0, 3
    andi t0, t0, -4
    bgtu t0, a3, 95f
    mv a2, t0
    j 2b
8:
    bnez a6, 99f                            # the end with a node open
    beqz t2, 99f                            # the end with no root
    li a0, DTB_OK
    ret
91:
    li a0, DTB_BAD_MAGIC
    ret
92:
    li a0, DTB_BAD_VERSION
    ret
93:
    li a0, DTB_BAD_SIZE
    ret
94:
    li a0, DTB_BAD_BLOCK
    ret
95:
    li a0, DTB_CUT
    ret
96:
    li a0, DTB_BAD_NAME
    ret
97:
    li a0, DTB_BAD_PROP
    ret
98:
    li a0, DTB_TOO_DEEP
    ret
99:
    li a0, DTB_BAD_TOKEN
    ret

.global dtb_path
dtb_path:
    lbu t0, 0(a1)
    li t1, '/'
    bne t0, t1, 9f
    dtb_be32 t0, a0, DTB_HDR_OFF_STRUCT
    dtb_be32 t2, a0, DTB_HDR_SIZE_STRUCT
    add t3, a0, t0                          # the cursor
    add t2, t2, t3                          # the structure's end
    li a2, 0                                # the depth
    li a3, 0                                # the depth matched
    addi a1, a1, 1                          # the component to match next
1:
    bgeu t3, t2, 9f
    dtb_be32 t0, t3
    addi t3, t3, 4
    li t1, DTB_BEGIN_NODE
    beq t0, t1, 2f
    li t1, DTB_END_NODE
    beq t0, t1, 6f
    li t1, DTB_PROP
    beq t0, t1, 7f
    li t1, DTB_NOP
    beq t0, t1, 1b
    j 9f
2:
    addi a4, t3, -4                         # the node
    addi a2, a2, 1
    addi t1, a3, 1
    bne a2, t1, 5f                          # not a child of the node matched last
    li t1, 1
    beq a2, t1, 33f                         # the root, its name empty, matches the leading /
    mv t4, t3                               # the node's name
    mv t5, a1                               # the component
3:
    lbu t0, 0(t5)
    lbu t1, 0(t4)
    li t6, '/'
    beq t0, t6, 31f
    beqz t0, 31f
    bne t0, t1, 5f
    addi t4, t4, 1
    addi t5, t5, 1
    j 3b
31:
    beqz t1, 32f                            # the name ends with the component
    li t6, '@'
    bne t1, t6, 5f                          # the name goes on past it, not at a unit address
32:
    mv a1, t5
33:
    addi a3, a3, 1
4:
    lbu t0, 0(a1)
    li t6, '/'
    bne t0, t6, 41f
    addi a1, a1, 1
    j 4b
41:
    beqz t0, 8f                             # the path is whole: this node
5:
    lbu t0, 0(t3)                           # past the node's name
    addi t3, t3, 1
    bnez t0, 5b
    addi t3, t3, 3
    andi t3, t3, -4
    j 1b
6:
    beq a2, a3, 9f                          # the node matched last closes short of the path
    addi a2, a2, -1
    j 1b
7:
    dtb_be32 t0, t3
    addi t3, t3, 8
    add t3, t3, t0
    addi t3, t3, 3
    andi t3, t3, -4
    j 1b
8:
    sub a0, a4, a0
    ret
9:
    li a0, 0
    ret

.global dtb_child
dtb_child:
    dtb_be32 t0, a0, DTB_HDR_OFF_STRUCT
    dtb_be32 t1, a0, DTB_HDR_SIZE_STRUCT
    add t1, t1, t0
    add t1, t1, a0                          # the structure's end
    beqz a2, 5f
    add t3, a0, a2                          # the child before: past its whole subtree
    li t5, 0                                # the depth inside it
1:
    bgeu t3, t1, 9f
    dtb_be32 t4, t3
    addi t3, t3, 4
    li t6, DTB_BEGIN_NODE
    beq t4, t6, 2f
    li t6, DTB_END_NODE
    beq t4, t6, 3f
    li t6, DTB_PROP
    beq t4, t6, 4f
    li t6, DTB_NOP
    beq t4, t6, 1b
    j 9f
2:
    lbu t6, 0(t3)
    addi t3, t3, 1
    bnez t6, 2b
    addi t3, t3, 3
    andi t3, t3, -4
    addi t5, t5, 1
    j 1b
3:
    addi t5, t5, -1
    bnez t5, 1b
    j 7f
4:
    dtb_be32 t6, t3
    addi t3, t3, 8
    add t3, t3, t6
    addi t3, t3, 3
    andi t3, t3, -4
    j 1b
5:
    add t3, a0, a1                          # the node: past its name
    addi t3, t3, 4
6:
    lbu t6, 0(t3)
    addi t3, t3, 1
    bnez t6, 6b
    addi t3, t3, 3
    andi t3, t3, -4
7:
    bgeu t3, t1, 9f
    dtb_be32 t4, t3
    li t6, DTB_BEGIN_NODE
    beq t4, t6, 8f
    addi t3, t3, 4
    li t6, DTB_NOP
    beq t4, t6, 7b
    li t6, DTB_PROP
    bne t4, t6, 9f                          # the node's end
    dtb_be32 t6, t3
    addi t3, t3, 8
    add t3, t3, t6
    addi t3, t3, 3
    andi t3, t3, -4
    j 7b
8:
    sub a0, t3, a0
    ret
9:
    li a0, 0
    ret

.global dtb_prop
dtb_prop:
    dtb_be32 t0, a0, DTB_HDR_OFF_STRUCT
    dtb_be32 t1, a0, DTB_HDR_SIZE_STRUCT
    add t1, t1, t0
    add t1, t1, a0                          # the structure's end
    dtb_be32 t2, a0, DTB_HDR_OFF_STRINGS
    add t2, t2, a0                          # the strings
    add t3, a0, a1
    addi t3, t3, 4
1:
    lbu t4, 0(t3)                           # past the node's name
    addi t3, t3, 1
    bnez t4, 1b
    addi t3, t3, 3
    andi t3, t3, -4
2:
    bgeu t3, t1, 9f
    dtb_be32 t4, t3
    addi t3, t3, 4
    li t5, DTB_NOP
    beq t4, t5, 2b
    li t5, DTB_PROP
    bne t4, t5, 9f                          # a child or the node's end: its properties are past
    dtb_be32 t5, t3                         # the value's bytes
    dtb_be32 t6, t3, 4
    add t6, t6, t2                          # the property's name
    mv a3, a2
3:
    lbu a4, 0(t6)
    lbu a5, 0(a3)
    bne a4, a5, 4f
    beqz a4, 5f
    addi t6, t6, 1
    addi a3, a3, 1
    j 3b
4:
    addi t3, t3, 8
    add t3, t3, t5
    addi t3, t3, 3
    andi t3, t3, -4
    j 2b
5:
    addi a0, t3, 8
    mv a1, t5
    ret
9:
    li a0, 0
    li a1, 0
    ret

.global dtb_phandle
dtb_phandle:
    dtb_be32 t0, a0, DTB_HDR_OFF_STRUCT
    dtb_be32 t1, a0, DTB_HDR_SIZE_STRUCT
    add t3, a0, t0                          # the cursor
    add t1, t1, t3                          # the structure's end
    dtb_be32 t2, a0, DTB_HDR_OFF_STRINGS
    add t2, t2, a0                          # the strings
    li a2, 0                                # the node open last, whose properties these are
1:
    bgeu t3, t1, 9f
    dtb_be32 t4, t3
    addi t3, t3, 4
    li t5, DTB_BEGIN_NODE
    beq t4, t5, 2f
    li t5, DTB_PROP
    beq t4, t5, 3f
    li t5, DTB_END
    beq t4, t5, 9f
    j 1b                                    # an END_NODE or a NOP
2:
    addi a2, t3, -4
21:
    lbu t5, 0(t3)
    addi t3, t3, 1
    bnez t5, 21b
    addi t3, t3, 3
    andi t3, t3, -4
    j 1b
3:
    dtb_be32 t5, t3                         # the value's bytes
    li t6, 4
    bne t5, t6, 5f
    dtb_be32 t6, t3, 8                      # the value
    bne t6, a1, 5f
    dtb_be32 t6, t3, 4
    add t6, t6, t2                          # the property's name
    la a3, dtb_word_phandle
4:
    lbu a4, 0(t6)
    lbu a5, 0(a3)
    bne a4, a5, 5f
    beqz a4, 8f
    addi t6, t6, 1
    addi a3, a3, 1
    j 4b
5:
    addi t3, t3, 8
    add t3, t3, t5
    addi t3, t3, 3
    andi t3, t3, -4
    j 1b
8:
    sub a0, a2, a0
    ret
9:
    li a0, 0
    ret

.global dtb_name
dtb_name:
    add a0, a0, a1
    addi a0, a0, 4
    ret

.global dtb_named
dtb_named:
    add a0, a0, a1
    addi a0, a0, 4
1:
    lbu t0, 0(a0)
    lbu t1, 0(a2)
    bne t0, t1, 9f
    beqz t0, 2f
    addi a0, a0, 1
    addi a2, a2, 1
    j 1b
2:
    li a0, 1
    ret
9:
    li a0, 0
    ret

.global dtb_equals
dtb_equals:
    beqz a1, 9f
    add t0, a0, a1
    addi t0, t0, -1                         # the value's last byte, its terminating NUL
1:
    lbu t1, 0(a0)
    lbu t2, 0(a2)
    bne t1, t2, 9f
    beqz t1, 2f
    addi a0, a0, 1
    addi a2, a2, 1
    j 1b
2:
    bne a0, t0, 9f                          # a NUL before the value's end
    li a0, 1
    ret
9:
    li a0, 0
    ret

.section .rodata
dtb_word_phandle:
    .asciz "phandle"
