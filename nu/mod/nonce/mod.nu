# A launch's capture nonce: its caller's, else minted for a probing launch
export def mint [given: int, probed: bool]: nothing -> int {
    if $given != 0 or not $probed { return $given }
    random int 1..
}

# A capture nonce as sixteen lowercase hex digits, as the shim logs it
export def hex [nonce: int]: nothing -> string {
    $nonce | into binary --endian big | encode hex | str lowercase
}
