

# NabuNet - Server component

## The actual server

The NabuNet project is the actual server component. It contains all components needed to run the webspace and API for the NabuNet Modem.

### deployment rules

the /wwwroot/theming folder is empty inside the project by default and design. This folder should be populated with any assets (picutres, css,...) that a themed instance of the server needs. Note: these assets need specific names to work, so be sure to read up on the theming topic before committing to effort! It is a folder to make it easy to map it to an external folder in a docker container.

### theming

TBD...

## The test project

The NabuNet.Tests project is a unit test project (NUnit3) that does a bit of basic housekeeping and validation.

## Docker...

The container created by the `make-docker.sh` script is configured to use two mounted volumes and exposes port #5000 for TLS.

To run the container, use the following docker command:

`docker run --name <containername> -v <key-path>:/var/nabunet.keys:ro -v <storage-root>:/var/nabunet -p 127.0.0.1:443:5000 nabunet:<versiontag>`

