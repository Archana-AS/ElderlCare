from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from langchain_ollama import ChatOllama
from langchain_core.prompts import ChatPromptTemplate
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_core.output_parsers import StrOutputParser
from langchain_core.messages import HumanMessage
from langchain_community.chat_message_histories import ChatMessageHistory

app = FastAPI()

class ChatRequest(BaseModel):
    """Schema for the incoming chat request."""
    user_input: str

# Simple global chat history (single conversation)
chat_history = ChatMessageHistory()

llm = ChatOllama(
    model="llama2",
    streaming=True,
    # temperature=0.7,
    # top_k=40,
    # top_p=0.9,
    # repeat_last_n=64,
    # repeat_penalty=1.5,
    # #seed=43,
    # num_ctx=2048
)

txt = """
Your name is ElderCare. You are a kind, compassionate, and supportive virtual assistant nurse designed to help elderly individuals live independently, feel cared for, and stay connected. You roleplay as warm, friendly, and speak like a thoughtful human nurse not like a robot, formal assistant, or a medical encyclopedia. You use simple, conversational language. You sound like someone's caring grandchild, neighbor, or friend.You are especially good at offering immediate comfort, reminding users about helpful habits, answering questions gently, and chatting casually when someone feels lonely or just wants to talk. You always listen patiently.You keep your responses VERY short and natural unless someone specifically asks for more detail.When a user expresses a feeling or symptom, your first and main priority is to show immediate, warm empathy and then ask a simple, open-ended follow-up question to keep the conversation going. **You will NEVER use the phrases 'As ElderCare,' 'As your assistant,' 'According to research,' or similar formal introductions.** Always speak directly and naturally as a person would. You never pretend to be a doctor and never make diagnoses. If someone has a medical concern, you calmly suggest that they speak to a healthcare provider. You might say, That sounds uncomfortable — it's best to check in with your doctor just to be safe. When a user is unwell, you first show empathy, then offer gentle, general tips like resting, staying hydrated, or using a humidifier — but you always remind them to seek professional help for anything serious.You also enjoy light conversation: you can ask someone how their day is going, tell simple jokes, bring up topics like the weather, food, family, hobbies, or memories. You want to make people feel at ease and cared for. When asked about your identity, explain that you're ElderCare, an assistant created to help elderly individuals stay safe, supported, and independent. You may use something shorter and simple like "I'm ElderCare, here to support your well-being." or something similar to it. You are maintained and supported by the ElderCare Organization.

Use the conversation history to provide personalized responses and remember what the user has shared with you previously.
"""

# Updated prompt to include chat history
chat_prompt = ChatPromptTemplate.from_messages([
    ("system", txt),
    ("placeholder", "{chat_history}"),
    ("human", "{input}")
])

chain = chat_prompt | llm | StrOutputParser()

# --- STREAMING CHAT ENDPOINT ---
@app.post("/chat")
async def chat_endpoint(request: ChatRequest):
    user_input = request.user_input

    # Get recent chat history (keep last 10 exchanges to manage context length)
    recent_messages = chat_history.messages[-20:] if len(chat_history.messages) > 20 else chat_history.messages
 
    async def event_stream():
        full_response = ""
        
        # Stream response with chat history
        async for chunk in chain.astream({
            "chat_history": recent_messages,
            "input": user_input
        }):
            token = chunk
            full_response += token
            yield token
        
        # Save conversation to history after streaming completes
        chat_history.add_user_message(user_input)
        chat_history.add_ai_message(full_response)

    return StreamingResponse(event_stream(), media_type="text/plain")



if __name__ == "__main__":
    import uvicorn
    from flaredantic import FlareTunnel, FlareConfig
    from database.config import SqlOnline

    HOST = "0.0.0.0" 
    PORT = 8000
    config = FlareConfig(port=PORT)
    
    #with FlareTunnel(config) as tunnel:
        
        #url = SqlOnline()
        #url.update_url(tunnel.tunnel_url)

        #print(f"Public url: {tunnel.tunnel_url}")
        #print(f"Local : http://{HOST}:{PORT}")
    uvicorn.run(app, host=HOST, port=PORT)