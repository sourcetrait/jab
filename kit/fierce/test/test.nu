use ../nu/mod/suite

# The SDK's entry to fierce's test: the suite's main with these arguments
def main [--kernel: path, --image: path, --out: path, --set: string = "", --assets: path = ""] {
    suite --kernel $kernel --image $image --out $out --set $set --assets $assets
}
