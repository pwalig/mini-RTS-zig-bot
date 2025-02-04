# mini-RTS-zig-bot
bot client for [mini-RTS-game](https://github.com/pwalig/mini-RTS-server)

# Build with Zig
```
git clone https://github.com/pwalig/mini-RTS-zig-bot.git
cd mini-RTS-zig-bot
zig build -Doptimize=ReleaseSmall
```
Optionally set `-Doptimize=ReleaseFast`.  
`ReleaseSmall` is prefered due to fairly large delay between game ticks, meaning zig-bot does not need to be super performant.

For information about installing zig see: https://ziglang.org/learn/getting-started/

# Running the program
```
./mini-rts-zig-bot.exe <host> <port> [runModeOptions]
./mini-rts-zig-bot.exe [infoOptions]
```

## Arguments:
* `<host>` - IPv4 address of the server
* `<port>` - Port number of the server

## `[runModeOptions]`:
* `--gamesToPlay <number>` - Play `<number>` games then exit (by default zig-bot tries to play unlimited number of games)
* `--dontWin` - Stop digging resource when is only one unit apart from winning

## `[infoOptions]`:
* `-h`, `--help` - Print help and exit
* `-v`, `--version` - Print version number and exit

# Compatibility

zig-bot is compatible with [mini-RTS-server](https://github.com/pwalig/mini-RTS-server)

## Version compatibility chart

| version | 1.x.x | 2.x.x | 3.x.x |
| --- | --- | --- | --- |
| **1.x.x** | :x: | :x: | :heavy_check_mark: |

> [!NOTE]  
> columns: server versions  
> rows: zig-bot versions  
> x stands for any version number

Generally server will be 2 major versions ahead.