#/bin/bash

set -euxo pipefail

SRC_DIR=$(cd $(dirname $0) && pwd)

zig build
zig build vm-setup

cargo nextest r --manifest-path "$SRC_DIR/../cosmwasm/packages/vm/Cargo.toml" zig_test --no-capture