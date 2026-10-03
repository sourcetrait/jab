# main.S

hash: XXH3-64. Fills a buffer with a ramp, then hashes prefixes of it
at lengths chosen to reach every one of the algorithm's four paths and
the boundaries between them, writing each as `h <length> <16 hex>`.
The test holds every one against the reference implementation.
