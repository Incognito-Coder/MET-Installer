# Matrix Server Installer

This script automates the installation and configuration of a Matrix Synapse server, an Element Web client, and a Coturn TURN server on a Debian-based system.

## Usage

To use the script, you can run it with the following command:

```bash
./install.sh [MATRIX_DOMAIN] [ELEMENT_DOMAIN] [TURN_DOMAIN] [EMAIL]
```

### Parameters

-   `MATRIX_DOMAIN`: (Optional) The domain for the Matrix Synapse server. Defaults to `matrix.mrscript.ir`.
-   `ELEMENT_DOMAIN`: (Optional) The domain for the Element Web client. Defaults to `element.mrscript.ir`.
-   `TURN_DOMAIN`: (Optional) The domain for the Coturn TURN server. Defaults to `turn.mrscript.ir`.
-   `EMAIL`: (Optional) The email address to use for SSL certificate registration with Let's Encrypt. Defaults to `alireza.ahmand@yahoo.com`.

If you run the script without any parameters, it will use the default values.

**Example:**

```bash
./install.sh matrix.example.com element.example.com turn.example.com user@example.com
```

## What it does

The script performs the following actions:

1.  **System Update:** Updates the package list and upgrades the installed packages.
2.  **Package Installation:** Installs necessary packages including `nginx`, `postgresql`, `certbot`, `coturn`, and `matrix-synapse-py3`.
3.  **Database Setup:** Creates a PostgreSQL user and database for Synapse.
4.  **Synapse Configuration:** Configures the Matrix Synapse server to use the PostgreSQL database and sets up TURN server integration.
5.  **Element Web Setup:** Installs the Element Web client and configures it to connect to the new Synapse server.
6.  **Nginx Configuration:** Sets up Nginx as a reverse proxy for both Synapse and Element.
7.  **SSL Certificates:** Obtains SSL certificates from Let's Encrypt for the specified domains.
8.  **TURN Server Setup:** Configures and starts the Coturn TURN server.
9.  **Firewall Configuration:** Configures `ufw` to allow traffic on the necessary ports (22, 80, 443, 3478, 5349, and 49152-65535/udp).
10. **Completion:** Prints the final URLs for your new Matrix and Element services.

## Prerequisites

-   A Debian-based Linux distribution (e.g., Debian, Ubuntu).
-   Root or sudo privileges.
-   DNS records for the domains pointing to the server's IP address.

## FAQ
> What's MET?
- it is short form of Matrix Element Turn
> Which clients supported?
- Element Classic [Play Store](https://play.google.com/store/apps/details?id=im.vector.app&hl=en) | [AppStore](https://apps.apple.com/us/app/element-classic/id1083446067)
- Element X [Play Store](https://play.google.com/store/apps/details?id=io.element.android.x&hl=en) | [AppStore](https://apps.apple.com/us/app/element-x-secure-chat-call/id1631335820)
- Element Pro [MacOS](https://apps.apple.com/us/app/element-pro-for-work/id6502951615)