# BIND Named server with easy setup bind config.

You can start a bind named server with easy setup bind config.

## Build

```bash
docker build -t minanon/named-easy .
```

## Run

Please setup a `generator.conf` under /generator/configs when start the container.

```bash
docker run -d -v /path/to/configs:/generator/configs minanon/named-easy
```

## Setting

For `generator.conf`.

### [global] section

`[global]` section configs are used on option and all config.

|Item      |Value                      |
|:---      |:---                       |
|email     |Email address on SOA record|
|servername|dns server name            |
|forwarders|DNS forwarders             |

#### Example

```
[global]
email      your.email.address
servername mydns.local
forwarders 8.8.8.8; 208.67.222.123
```

### [zone] section

`[zone]` section configs are used for generating a zone config. One line is one zone config.
One line config is separated by space.

|Index|Description                                                                       |
|:--- |:---                                                                              |
|1    |Base domain                                                                       |
|2    |Base IP address                                                                   |
|3    |Subdomain setting. Please read Subdomain section. you should surround with quotes.|
|4    |TTL for zone. optional: default 7200                                              |
|5    |Refresh for SOA. optional: default 28800                                          |
|6    |Refresh for Retry. optional: default 1800                                         |
|7    |Refresh for Expire. optional: default 604800                                      |
|8    |Refresh for Minimum. optional: default 86400                                      |

#### Subdomain

Subdomain config is needed subdomain name and record type and IP address. All this settings should be surround with quotes.
And multiple configs are separated by comma.

#### Example

```
[zone]
# Domain BaseIP "Subdomain Type [IP=BaseIP]"(e.g. @ A, mail MX 127.0.0.2, * A) [TTL=7200] [Refresh=28800] [Retry=1800] [Expire=604800] [Minimum=86400]
localhost 127.0.0.1 "@ A" 1D 3H 15M 1W 1D
example.com 93.184.216.34 "@ A, mail A 127.0.0.1, mail MX 10 mail.example.com., * A"
```

## Edit template

`/generator` has `configs` and `templates`. You can edit templates.

```bash
docker run -d -v /path/to/generator:/generator minanon/named-easy
```
