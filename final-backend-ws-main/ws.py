import websockets
import asyncio
import json
import mclient

host = "127.0.0.1"
port = 3007


async def handler(websocket: websockets.WebSocketServerProtocol, path):
    c = mclient.MClient()
    await c.connect()

    async def f():
        try:
            msg = await websocket.recv()
            await c.send_auth(json.loads(msg)["sessid"])
            print(f"< {msg}")

            async for msg in websocket:
                print(f"> {msg}")
                await c.send_data(msg)
        finally:
            await c.close()

    async def write_loop():
        try:
            while True:
                data = await c.read_data()
                print(data)
                await websocket.send(data)
        except asyncio.IncompleteReadError:
            pass
        finally:
            await c.close()

    await asyncio.gather(write_loop(), f())


start_server = websockets.serve(handler, host, port)

asyncio.get_event_loop().run_until_complete(start_server)
asyncio.get_event_loop().run_forever()
