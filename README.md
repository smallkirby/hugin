# Hugin

![Zig](https://shields.io/badge/Zig-v0%2E15%2E1-blue?logo=zig&color=F7A41D&style=for-the-badge)

![Lint](https://github.com/smallkirby/hugin/actions/workflows/lint.yml/badge.svg)
![Unit Tests](https://github.com/smallkirby/hugin/actions/workflows/unittest.yml/badge.svg)
![Runtime Tests](https://github.com/smallkirby/hugin/actions/workflows/rtt.yml/badge.svg)

## Development

```bash
# Run on QEMU
zig build run --summary all -Dlog_level=debug -Doptimize=Debug
# Unit Test
zig build test --summary all
```

## Options

| Option | Type | Description | Default |
|---|---|---|---|
| `log_level` | String: `debug`, `info`, `warn`, `error` | Logging level. Output under the logging level is suppressed. | `info` |
| `optimize` | String: `Debug`, `ReleaseFast`, `ReleaseSmall` | Optimization level. | `Debug` |
| `runtime_test` | Flag | Enable runtime tests. | `false` |
| `uboot` | String | Path to U-Boot install directory. | `"$HOME/u-boot"` |
| `qemu` | String | Path to QEMU aarch64 install directory. | `"$HOME/qemu-aarch64"` |
| `vfat` | Flag | Use QEMU Virtual FAT filesystem. | `false` |
| `wait_qemu` | Flag | Make QEMU wait for being attached by GDB. | `false` |

## License

See [LICENSE](LICENSE).

This project is a port of the book "[作って理解する仮想化技術─⁠─ ハイパーバイザを実装しながら仕組みを学ぶ（技術評論社,2025）](https://gihyo.jp/book/2025/978-4-297-15012-9)" to the Zig language with original improvements. Refer to the author's [GitHub repository](https://github.com/PG-MANA/MiniVisor) for the original Rust implementation.

```LICENSE
Copyright 2023 Manami Mori

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
