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

StatusPanel uses [Git Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules), so before doing anything else, you'll need to do:

```bash
git submodule update --init
```

You'll also need to run this command if the submodules change.

## Licensing

StatusPanel is licensed under the MIT License (see [LICENSE](LICENSE)).
