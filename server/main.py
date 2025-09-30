from flaredantic import FlareTunnel, FlareConfig
from database.config import SqlOnline

HOST = "localhost" 
PORT = 8000
config = FlareConfig(port=PORT)
# with FlareTunnel(config) as tunnel:
    
#     url = SqlOnline()
#     url.update_url(tunnel.tunnel_url)
#     print(f"Public url: {tunnel.tunnel_url}")
#     print(f"Local : http://{HOST}:{PORT}")

url = SqlOnline()
url.update_url("sdds")
print(url.get_url())