# StatusPanel

[![Build](https://github.com/inseven/statuspanel/actions/workflows/build.yaml/badge.svg)](https://github.com/inseven/statuspanel/actions/workflows/build.yaml)

eInk status board for displaying every-day information

## Components

StatusPanel comprises a number of different components:

- [Firmware](nodemcu/README.markdown)
- [PCB](pcb/README.markdown)
- [iOS app](ios/README.markdown)
- [Service](service/README.markdown)

## Development

### Installing Dependencies

1. StatusPanel uses [Git Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules), so before doing anything else, you'll need to do:

   ```bash
   git submodule update --init --recursive
   ```

   N.B. You'll also need to run this command if the submodules change.

2. Once your submodules are up-to-date, you can install the dependencies for all StatusPanel components using the `install-dependencies.sh` script:

   ```bash
   scripts/install-dependencies.sh
   ```
 
   This script installs all dependencies in the `.local` folder within the project root, does not require root, and should not impact your local machine configuration. Scripts that rely on these dependencies source the `scripts/environment.sh` script which configures the path at runtime.

## Licensing

StatusPanel is licensed under the MIT License (see [LICENSE](LICENSE)).
