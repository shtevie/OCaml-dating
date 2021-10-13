import asyncio
import socket
import struct
from typing import *

HOST = '127.0.0.1'  # The server's hostname or IP address
PORT = 12345  # The port used by the server


class MClient:
    def __init__(self):
        self._reader: Optional[asyncio.StreamReader] = None
        self._writer: Optional[asyncio.StreamWriter] = None

    async def connect(self):
        # sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._reader, self._writer = await asyncio.open_connection(HOST, PORT, family=socket.AF_INET)

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        await self.close()

    async def close(self):
        self._writer.close()
        await self._writer.wait_closed()

    async def send_auth(self, sessid):
        fmt = "!B32s"
        msg = struct.pack(fmt, 0, bytes(sessid, "utf-8"))
        print(msg.hex(), flush=True)
        self._writer.write(msg)
        await self._writer.drain()

    async def send_data(self, data):
        data_bytes = bytes(data, "utf-8")
        fmt = "!BI"
        msg = struct.pack(fmt, 1, len(data_bytes)) + data_bytes
        print(msg.hex(), flush=True)
        self._writer.write(msg)
        await self._writer.drain()

    async def read_data(self):
        t = await self._reader.readexactly(1)
        t = int.from_bytes(t, "big", signed=False)
        assert t == 1
        ln = await self._reader.readexactly(4)
        ln = int.from_bytes(ln, "big", signed=False)
        data = await self._reader.readexactly(ln)
        return data.decode("utf-8")

    async def read_loop(self, f):
        self._reader.exception()
        while True:
            try:
                data = await self.read_data()
            except asyncio.IncompleteReadError:
                break
            f(data)


if __name__ == '__main__':
    async def run():
        async with MClient() as c:
            await c.connect()

            async def f():
                await c.send_auth("GOjfKB7YbeSIzNUXDOEKi6tgojduZx5l")
                await c.send_data('{"message": "hello"}')

            await asyncio.gather(c.read_loop(lambda x: print(repr(x))), f())


    asyncio.run(run())
