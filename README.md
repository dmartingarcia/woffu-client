# woffu-client
woffu CLI tool

It (will) allow to connect and perform actions on woffu, via CLI commands.

This is still a draft, but it handle attendance as expected.

# Scripts options:

> ruby run.rb -h
  Usage: run [options]
    -e, --email EMAIL                Woffu user
    -p, --password PASSWORD          Password
    -f, --fill-empty-presence        enable filling presence gaps
    -s, --sign                       enable sign process

# Docker command:
`docker run -it dmartingarcia0/woffu-client:latest`

## Using the different options

you can pass the option at the end of the docker run command

`docker run -it -e  dmartingarcia0/woffu-client:latest` -s

## Using env vars
WOFFU_EMAIL and WOFFU_PASSWORD as environment variables for faster usage.

`docker run -it -e WOFFU_EMAIL=example@example.org -e WOFFU_PASSWORD=supersecret dmartingarcia0/woffu-client:latest` -h

## Supporting me
If you find this useful, you can invite me to a beer or two [here](https://www.buymeacoffee.com/dmartingarcia0), it will improve my focus by +9999% :beers:
