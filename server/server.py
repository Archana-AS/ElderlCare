from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import requests
from typing import List, Dict

app = FastAPI()

class Query(BaseModel):
    prompt: str
    model: str = "medchatbot"

@app.post("/chat")
async def chat(query: Query):
    try:
        response = requests.post(
            "http://localhost:11434/api/generate",
            json={"model": query.model, "prompt": query.prompt},
            stream=False
        )
        response.raise_for_status()
        data = response.json()
        return {"reply": data["response"]}
    except requests.RequestException as e:
        raise HTTPException(status_code=500, detail=f"Ollama error: {str(e)}")

    









if __name__ == "__main__":
    import uvicorn
    from flaredantic import FlareTunnel, FlareConfig
    from config import SqlOnline

    HOST = "0.0.0.0" 
    PORT = 8000
    config = FlareConfig(port=PORT)
    
    #with FlareTunnel(config) as tunnel:
        
        #url = SqlOnline()
        #url.update_url(tunnel.tunnel_url)

        #print(f"Public url: {tunnel.tunnel_url}")
        #print(f"Local : http://{HOST}:{PORT}")
    uvicorn.run(app, host=HOST, port=PORT)