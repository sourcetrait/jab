.ifndef DTB_INC
.set DTB_INC, 1

.set DTB_MAGIC, 0xd00dfeed
.set DTB_VERSION, 17
.set DTB_LAST_COMPATIBLE, 16
.set DTB_HEADER, 40
.set DTB_MAX, (1024 * 1024)
.set DTB_DEPTH, 16

.set DTB_HDR_MAGIC, 0
.set DTB_HDR_TOTALSIZE, 4
.set DTB_HDR_OFF_STRUCT, 8
.set DTB_HDR_OFF_STRINGS, 12
.set DTB_HDR_OFF_RSVMAP, 16
.set DTB_HDR_VERSION, 20
.set DTB_HDR_LAST_COMPATIBLE, 24
.set DTB_HDR_SIZE_STRINGS, 32
.set DTB_HDR_SIZE_STRUCT, 36

.set DTB_BEGIN_NODE, 1
.set DTB_END_NODE, 2
.set DTB_PROP, 3
.set DTB_NOP, 4
.set DTB_END, 9

.set DTB_OK, 0
.set DTB_BAD_MAGIC, 1
.set DTB_BAD_VERSION, 2
.set DTB_BAD_SIZE, 3
.set DTB_BAD_BLOCK, 4
.set DTB_CUT, 5
.set DTB_BAD_NAME, 6
.set DTB_BAD_PROP, 7
.set DTB_TOO_DEEP, 8
.set DTB_BAD_TOKEN, 9

.macro dtb_be32 dst, base, offset=0
    lwu \dst, \offset(\base)
    rev8 \dst, \dst
    srli \dst, \dst, 32
.endm

.endif
