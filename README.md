# woffu-client
woffu CLI tool

It (will) allow to connect and perform actions on woffu, via CLI commands.

This is still a draft, but it handle attendance as expected.

# Docker command:
`docker run -it dmartingarcia0/woffu-client:0.1-alpine`

## Using env vars
WOFFU_EMAIL and WOFFU_PASSWORD as environment variables for faster usage.

`docker run -it -e WOFFU_EMAIL=example@example.org -e WOFFU_PASSWORD=supersecret dmartingarcia0/woffu-client:0.1-alpine`

## For ARM/M1 MBP users
Use `docker run --platform linux/amd64 -it dmartingarcia0/woffu-client:0.1-alpine`

## Supporting me 
If you find this useful, you can invite me to a beer or two [here](https://www.buymeacoffee.com/dmartingarcia0), it will improve my focus by +200%

