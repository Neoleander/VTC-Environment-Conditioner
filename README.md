# VTC-Environment-Conditioner
This is a self extracting script which intelligently extracts the environment files (functions/variables) for a given OS.  The functions are useful for working with Dispersive VTC software.

- In order to build the package, pull down the newest revision from Github.
- Type the following command in the base folder of the project (where VTC-Deploy.bash is).
	- ./VTC-Deploy.bash BUILD
- The VTC-Deploy.bash screen will ensure all files required are present, then serialize (TAR/GZ) and consume (appeand to itself) the environment files.
- If successful, the VTC-Deploy.bash file can be moved (BINARY MODE) to a compatible VTC OS and...
	- If VEC is already present, it will automatically trigger an upgrade of files.
	- If VEC is NOT present, the user will have to (as root) run: ./VTC-Deploy.bash
