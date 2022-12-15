# OracleNIO

## Prerequirements

OracleNIO uses ODPI-C internally which depends on the Oracle Instant Client Library. It needs to be installed on your machine in order for oracle-nio to work. You can download OIC from the [official website](https://www.oracle.com/database/technologies/instant-client.html). More information about where OIC should be located on your system is available [here](https://oracle.github.io/odpi/doc/installation.html#clientlibloading). It is also possible to provide the path to your OIC with other configuration options.

> Please be aware that OIC is not yet natively available for Apple Silicon (arm64), you'll need to run your project (and tests) with Rosetta e.g. `arch -x86_64 swift run` until a native build from Oracle is available.
