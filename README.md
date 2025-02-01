# mini-RTS-zig-bot
bot client for [mini-RTS-game](https://github.com/pwalig/mini-RTS-server)

# Build with Zig
```
git clone https://github.com/pwalig/mini-RTS-zig-bot.git
cd mini-RTS-zig-bot
zig build
```
For information about installing zig see: https://ziglang.org/learn/getting-started/

# Run
```
./zig-out/bin/mini-rts-zig-bot.exe <host> <port>
```

# Compatibility

zig-bot is compatible with [mini-RTS-server](https://github.com/pwalig/mini-RTS-server)

## Version compatibility chart

| version | 1.x.x | 2.x.x | 3.0.0 |
| --- | --- | --- | --- |
| **1.0.0** | :x: | :x: | :heavy_check_mark: |

> [!NOTE]  
> columns: server versions  
> rows: zig-bot versions  
> x stands for any version number

Generally server will be 2 major versions ahead.