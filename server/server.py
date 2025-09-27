from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import asyncio

from langchain_ollama import ChatOllama
from langchain_chroma import Chroma
from langchain_huggingface import HuggingFaceEmbeddings
from langchain.memory import ConversationBufferMemory
from langchain_core.messages import HumanMessage

app = FastAPI()

# --- FastAPI Request Model ---
class ChatRequest(BaseModel):
    """Defines the expected JSON body structure for the /chat endpoint."""
    user_input: str


# --- MODEL ---
# NOTE: Using ChatOllama from the dedicated langchain_ollama package
llm = ChatOllama(
    model="helpingai",    
    streaming=True,
    temperature=0.7
)

# --- MEMORY ---
# ConversationBufferMemory is a standard LangChain memory component
memory = ConversationBufferMemory(memory_key="chat_history", return_messages=True)

# --- VECTOR DB for Long-term memory ---
# NOTE: Using HuggingFaceEmbeddings and Chroma from their dedicated packages
embeddings = HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")
vectorstore = Chroma(collection_name="elderly_memories", embedding_function=embeddings)

# --- SYSTEM PROMPT (elderly-care role) ---
system_prompt = """You are a compassionate medical assistant chatbot.
Your role is to help elderly people:
- Talk warmly, patiently, and simply
- Provide companionship and reassurance
- Help them with reminders (like medicine, appointments, or activities)
- Always explain things in an easy-to-understand way
- Keep responses short and comforting
- Never overwhelm them with too much detail
"""

# --- Helper functions ---
def store_fact(text: str):
    """Store long-term fact in vector DB."""
    # NOTE: Chroma.add_texts returns IDs, which are discarded here for simplicity
    vectorstore.add_texts([text])

def recall(query: str):
    """Retrieve relevant facts from vector DB."""
    docs = vectorstore.similarity_search(query, k=3)
    return "\n".join([d.page_content for d in docs])


# --- STREAMING CHAT ENDPOINT ---
# FIX: Now accepts a ChatRequest object from the JSON body
@app.post("/chat")
async def chat_endpoint(request: ChatRequest):
    user_input = request.user_input

    # 1. Recall long-term facts
    retrieved_facts = recall(user_input)

    # 2. Build full prompt with system role + facts + chat history + user input
    history = short_term_memory.load_memory_variables({}).get("chat_history", [])
    
    # Start the prompt with the system role and retrieved context
    prompt = f"{system_prompt}\n\nRelevant past info:\n{retrieved_facts}\n\n"
    
    # Append short-term conversation history
    for msg in history:
        # Use content and role from the message object
        role = "User" if isinstance(msg, HumanMessage) else "Assistant"
        prompt += f"{role}: {msg.content}\n"
        
    # Append the current user input and prime the model for its response
    prompt += f"User: {user_input}\nAssistant:"

    # 3. Streaming generator
    async def event_stream():
        full_response = ""
        # The .astream method from langchain_core yields chunks
        async for chunk in llm.astream(prompt):
            if chunk.content:
                token = chunk.content
                full_response += token
                yield token

        # Save conversation turn in short-term memory after the stream completes
        short_term_memory.chat_memory.add_user_message(user_input)
        short_term_memory.chat_memory.add_ai_message(full_response)

        # Optionally: store long-term facts
        if "remind me" in user_input.lower() or "my name is" in user_input.lower():
            store_fact(user_input)

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